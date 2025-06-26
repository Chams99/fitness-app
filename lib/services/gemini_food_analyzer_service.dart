import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'food_api_service.dart';

class GeminiFoodAnalyzerService {
  static const String _geminiApiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';
  static final String _geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  final FoodApiService _foodApiService = FoodApiService();

  // Enhanced timeout and retry configuration
  static const Duration _apiTimeout = Duration(seconds: 30);
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  static const int _maxImageSize = 1024; // Max width/height in pixels
  static const int _maxImageSizeBytes = 4 * 1024 * 1024; // 4MB max

  // Cache for storing recent results
  static final Map<String, Map<String, dynamic>> _resultCache = {};
  static const Duration _cacheDuration = Duration(minutes: 30);

  Future<Map<String, dynamic>> analyzeFoodImage(File imageFile) async {
    try {
      if (_geminiApiKey.isEmpty) {
        return {'success': false, 'error': 'Gemini API key is not configured.'};
      }

      final String cacheKey = await _generateCacheKey(imageFile);
      if (_resultCache.containsKey(cacheKey)) {
        final cachedResult = _resultCache[cacheKey]!;
        if (DateTime.now().difference(cachedResult['timestamp'] as DateTime) <
            _cacheDuration) {
          return Map<String, dynamic>.from(cachedResult)..remove('timestamp');
        }
      }

      // Optimize image before sending to API
      final File optimizedImage = await _optimizeImage(imageFile);

      final Map<String, dynamic> geminiResult =
          await compute(_analyzeImageWithGemini, {
            'imagePath': optimizedImage.path,
            'apiKey': _geminiApiKey,
            'timeout': _apiTimeout.inSeconds,
            'maxRetries': _maxRetries,
            'retryDelay': _retryDelay.inSeconds,
          });

      // Clean up optimized image if it's different from original
      if (optimizedImage.path != imageFile.path) {
        try {
          await optimizedImage.delete();
        } catch (e) {
          // Ignore cleanup errors
        }
      }

      if (!geminiResult['success']) {
        return geminiResult;
      }

      final String? recognizedFood = geminiResult['recognized_food'];
      final double confidence = geminiResult['confidence'];
      final List<String> possibleFoods = geminiResult['possible_foods'];

      if (recognizedFood == null || recognizedFood.toLowerCase() == 'none') {
        return {
          'success': false,
          'error': 'Could not recognize any food item from the image.',
          'confidence': confidence,
        };
      }

      // Try to find food data using multiple approaches with validation
      List<Map<String, dynamic>> productCandidates = [];

      // First, try the primary recognized food with enhanced search terms
      productCandidates = await _searchWithValidation(
        recognizedFood,
        recognizedFood,
      );

      // If no results found, try the possible alternatives
      if (productCandidates.isEmpty && possibleFoods.isNotEmpty) {
        for (String alternative in possibleFoods) {
          productCandidates = await _searchWithValidation(
            alternative,
            recognizedFood,
          );
          if (productCandidates.isNotEmpty) {
            break;
          }
        }
      }

      // If still no results, try with enhanced search terms
      if (productCandidates.isEmpty) {
        final enhancedTerms = _generateEnhancedSearchTerms(recognizedFood);
        for (String term in enhancedTerms) {
          productCandidates = await _searchWithValidation(term, recognizedFood);
          if (productCandidates.isNotEmpty) {
            break;
          }
        }
      }

      if (productCandidates.isEmpty) {
        // Get API status to provide better error information
        final apiStatus = await _foodApiService.getApiStatus();
        final availableApis =
            apiStatus.entries
                .where((entry) => entry.value)
                .map((entry) => entry.key)
                .toList();

        return {
          'success': false,
          'error':
              availableApis.isEmpty
                  ? 'All food databases are currently unavailable. Please try again later.'
                  : 'Could not find "$recognizedFood" in any of the available food databases (${availableApis.join(', ')}). Try taking a clearer photo or searching manually.',
          'recognized_food': recognizedFood,
          'possible_foods': possibleFoods,
          'confidence': confidence,
          'available_databases': availableApis,
        };
      }

      // Use the best match (first result is already the highest scored)
      final bestMatch = productCandidates.first;
      final foodData = _foodApiService.formatProductData(bestMatch);

      final result = {
        'success': true,
        'food_data': foodData,
        'recognized_food': recognizedFood,
        'best_match': foodData['product_name'],
        'possible_foods': possibleFoods,
        'confidence': confidence,
        'search_source': bestMatch['source'] ?? 'Unknown',
        'alternatives_found': productCandidates.length,
        'timestamp': DateTime.now(),
      };

      _resultCache[cacheKey] = result;

      return Map<String, dynamic>.from(result)..remove('timestamp');
    } catch (e) {
      print('Error in Gemini food analysis: $e');
      return {
        'success': false,
        'error': 'Error processing image: $e',
        'confidence': 0.0,
      };
    }
  }

  List<String> _generateSimplifiedSearchTerms(String originalTerm) {
    final terms = <String>[];
    final lowercaseTerm = originalTerm.toLowerCase();

    // Remove common descriptive words
    final descriptiveWords = [
      'fresh',
      'organic',
      'raw',
      'cooked',
      'grilled',
      'fried',
      'baked',
      'steamed',
    ];
    String simplified = lowercaseTerm;
    for (String word in descriptiveWords) {
      simplified = simplified.replaceAll(word, '').trim();
    }

    if (simplified != lowercaseTerm && simplified.isNotEmpty) {
      terms.add(simplified);
    }

    // Try individual words if it's a compound term
    final words = lowercaseTerm.split(' ');
    if (words.length > 1) {
      for (String word in words) {
        if (word.length > 2 && !descriptiveWords.contains(word)) {
          terms.add(word);
        }
      }
    }

    // Try removing 's' from the end
    if (lowercaseTerm.endsWith('s') && lowercaseTerm.length > 3) {
      terms.add(lowercaseTerm.substring(0, lowercaseTerm.length - 1));
    }

    return terms.take(3).toList(); // Limit to 3 alternative terms
  }

  Future<String> _generateCacheKey(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return base64Encode(bytes).substring(0, 32);
  }

  Future<File> _optimizeImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();

      // Check if image is already small enough
      if (bytes.length <= _maxImageSizeBytes) {
        final image = img.decodeImage(bytes);
        if (image != null &&
            image.width <= _maxImageSize &&
            image.height <= _maxImageSize) {
          return imageFile; // No optimization needed
        }
      }

      // Decode and resize image
      final image = img.decodeImage(bytes);
      if (image == null) {
        throw Exception('Could not decode image');
      }

      // Calculate new dimensions while maintaining aspect ratio
      int newWidth = image.width;
      int newHeight = image.height;

      if (image.width > _maxImageSize || image.height > _maxImageSize) {
        final aspectRatio = image.width / image.height;
        if (image.width > image.height) {
          newWidth = _maxImageSize;
          newHeight = (_maxImageSize / aspectRatio).round();
        } else {
          newHeight = _maxImageSize;
          newWidth = (_maxImageSize * aspectRatio).round();
        }
      }

      // Resize image
      final resizedImage = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.average,
      );

      // Encode as JPEG with reduced quality for smaller file size
      final optimizedBytes = img.encodeJpg(resizedImage, quality: 85);

      // Create temporary file
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/optimized_food_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      await tempFile.writeAsBytes(optimizedBytes);
      return tempFile;
    } catch (e) {
      print('Error optimizing image: $e');
      return imageFile; // Return original if optimization fails
    }
  }

  static Future<Map<String, dynamic>> _analyzeImageWithGemini(
    Map<String, dynamic> params,
  ) async {
    final File imageFile = File(params['imagePath']);
    final String? apiKey = params['apiKey'];
    final int timeoutSeconds = params['timeout'] ?? 30;
    final int maxRetries = params['maxRetries'] ?? 3;
    final int retryDelaySeconds = params['retryDelay'] ?? 2;

    if (apiKey == null || apiKey.isEmpty) {
      return {'success': false, 'error': 'Gemini API key is not configured'};
    }

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        print('Gemini API attempt ${attempt + 1}/$maxRetries');

        final bytes = await imageFile.readAsBytes();
        final base64Image = base64Encode(bytes);

        final prompt = '''
Analyze this food image and provide the following information in JSON format:
1. The most likely food item (be specific: "banana", "chicken wing", "couscous", etc.)
2. A confidence score (0.0 to 1.0)
3. A list of 3-5 possible food items if the image is unclear

Focus on:
- Specific food names (not generic terms like "food" or "dish")
- Common food items like fruits, vegetables, meats, grains, etc.
- If the image is unclear or contains multiple items, list the most prominent ones

Respond with ONLY valid JSON in this format:
{
  "recognized_food": "specific food name",
  "confidence": 0.85,
  "possible_foods": ["food1", "food2", "food3"]
}
''';

        final requestBody = {
          'contents': [
            {
              'parts': [
                {'text': prompt},
                {
                  'inline_data': {
                    'mime_type': 'image/jpeg',
                    'data': base64Image,
                  },
                },
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0.1,
            'topK': 1,
            'topP': 0.8,
            'maxOutputTokens': 500,
          },
        };

        final client = http.Client();
        try {
          final response = await client
              .post(
                Uri.parse('$_geminiApiUrl?key=${apiKey!}'),
                headers: {
                  'Content-Type': 'application/json',
                  'Connection': 'keep-alive',
                },
                body: jsonEncode(requestBody),
              )
              .timeout(Duration(seconds: timeoutSeconds));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final candidates = data['candidates'];

            if (candidates != null && candidates.isNotEmpty) {
              final content = candidates[0]['content'];
              final parts = content['parts'];

              if (parts != null && parts.isNotEmpty) {
                final text = parts[0]['text'];

                // Extract JSON from the response
                final jsonMatch = RegExp(
                  r'\{.*\}',
                  dotAll: true,
                ).firstMatch(text);
                if (jsonMatch != null) {
                  final jsonStr = jsonMatch.group(0);
                  final result = jsonDecode(jsonStr!);

                  return {
                    'success': true,
                    'recognized_food': result['recognized_food'],
                    'confidence': (result['confidence'] as num).toDouble(),
                    'possible_foods': List<String>.from(
                      result['possible_foods'],
                    ),
                    'attempts': attempt + 1,
                  };
                }
              }
            }

            return {
              'success': false,
              'error': 'Invalid response format from Gemini API',
              'attempts': attempt + 1,
            };
          } else if (response.statusCode == 429) {
            // Rate limit - wait longer before retry
            print('Rate limited, waiting before retry...');
            if (attempt < maxRetries - 1) {
              await Future.delayed(Duration(seconds: retryDelaySeconds * 2));
              continue;
            }
          } else if (response.statusCode >= 500) {
            // Server error - retry
            print('Server error (${response.statusCode}), retrying...');
            if (attempt < maxRetries - 1) {
              await Future.delayed(Duration(seconds: retryDelaySeconds));
              continue;
            }
          }

          print('Error from Gemini API: ${response.statusCode}');
          print('Response Body: ${response.body}');
          return {
            'success': false,
            'error': 'API request failed with status ${response.statusCode}',
            'attempts': attempt + 1,
          };
        } finally {
          client.close();
        }
      } catch (e) {
        print('Error in Gemini analysis attempt ${attempt + 1}: $e');

        if (e.toString().contains('TimeoutException') &&
            attempt < maxRetries - 1) {
          // Timeout - retry with exponential backoff
          final delaySeconds = retryDelaySeconds * (attempt + 1);
          print('Timeout occurred, retrying in $delaySeconds seconds...');
          await Future.delayed(Duration(seconds: delaySeconds));
          continue;
        }

        if (attempt == maxRetries - 1) {
          // Last attempt failed
          return {
            'success': false,
            'error': 'Error analyzing image after $maxRetries attempts: $e',
            'attempts': attempt + 1,
          };
        }

        // Retry with delay
        await Future.delayed(Duration(seconds: retryDelaySeconds));
      }
    }

    return {
      'success': false,
      'error': 'Failed to analyze image after $maxRetries attempts',
      'attempts': maxRetries,
    };
  }

  // Method to get detailed nutritional analysis
  Future<Map<String, dynamic>> getDetailedNutritionalAnalysis(
    File imageFile,
  ) async {
    final basicResult = await analyzeFoodImage(imageFile);

    if (!basicResult['success']) {
      return basicResult;
    }

    final foodData = basicResult['food_data'] as Map<String, dynamic>;
    final nutriments = foodData['nutriments'] as Map<String, dynamic>;

    // Calculate additional nutritional insights
    final calories = nutriments['energy-kcal_100g'] ?? 0.0;
    final protein = nutriments['proteins_100g'] ?? 0.0;
    final carbs = nutriments['carbohydrates_100g'] ?? 0.0;
    final fat = nutriments['fat_100g'] ?? 0.0;
    final fiber = nutriments['fiber_100g'] ?? 0.0;

    // Calculate macronutrient percentages
    final totalMacros = protein + carbs + fat;
    final proteinPercentage =
        totalMacros > 0 ? (protein / totalMacros) * 100 : 0;
    final carbsPercentage = totalMacros > 0 ? (carbs / totalMacros) * 100 : 0;
    final fatPercentage = totalMacros > 0 ? (fat / totalMacros) * 100 : 0;

    // Determine food category
    String category = 'Other';
    if (protein > 10) {
      category = 'High Protein';
    } else if (carbs > 50) {
      category = 'High Carb';
    } else if (fat > 30) {
      category = 'High Fat';
    } else if (fiber > 5) {
      category = 'High Fiber';
    }

    // Health score calculation (simple algorithm)
    double healthScore = 100.0;
    if (calories > 300) healthScore -= 10;
    if (fat > 20) healthScore -= 15;
    if (fiber < 2) healthScore -= 10;
    if (protein < 5) healthScore -= 5;
    healthScore = healthScore.clamp(0.0, 100.0);

    return {
      ...basicResult,
      'nutritional_analysis': {
        'category': category,
        'health_score': healthScore,
        'macronutrient_breakdown': {
          'protein_percentage': proteinPercentage,
          'carbs_percentage': carbsPercentage,
          'fat_percentage': fatPercentage,
        },
        'daily_value_estimates': {
          'calories_dv': (calories / 2000) * 100, // Based on 2000 cal diet
          'protein_dv': (protein / 50) * 100, // Based on 50g protein
          'carbs_dv': (carbs / 275) * 100, // Based on 275g carbs
          'fat_dv': (fat / 55) * 100, // Based on 55g fat
          'fiber_dv': (fiber / 28) * 100, // Based on 28g fiber
        },
      },
    };
  }

  // Method to clear cache
  void clearCache() {
    _resultCache.clear();
  }

  // Method to get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cache_size': _resultCache.length,
      'cache_duration_minutes': _cacheDuration.inMinutes,
    };
  }

  // Diagnostic method to test API connectivity and key validity
  Future<Map<String, dynamic>> testGeminiConnection() async {
    try {
      if (_geminiApiKey.isEmpty) {
        return {
          'success': false,
          'error': 'Gemini API key is not configured in .env file',
          'details':
              'Please add GEMINI_API_KEY=your_key_here to your .env file',
        };
      }

      print('Testing Gemini API connection...');
      print('API Key present: ${_geminiApiKey.isNotEmpty}');
      print('API Key length: ${_geminiApiKey.length}');
      print('API URL: $_geminiApiUrl');

      // Simple text-only request to test API key and connectivity
      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': 'Hello, can you respond with just the word "working"?'},
            ],
          },
        ],
        'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 10},
      };

      final client = http.Client();
      try {
        print('Sending test request to Gemini API...');
        final response = await client
            .post(
              Uri.parse('$_geminiApiUrl?key=$_geminiApiKey'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(requestBody),
            )
            .timeout(const Duration(seconds: 10));

        print('Received response with status code: ${response.statusCode}');
        print('Response body: ${response.body}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return {
            'success': true,
            'message': 'Gemini API is working correctly',
            'status_code': response.statusCode,
            'response_data': data,
          };
        } else if (response.statusCode == 400) {
          return {
            'success': false,
            'error': 'Invalid API key or request format',
            'status_code': response.statusCode,
            'response_body': response.body,
            'suggestion': 'Check your GEMINI_API_KEY in .env file',
          };
        } else if (response.statusCode == 403) {
          return {
            'success': false,
            'error': 'API key does not have permission to access Gemini API',
            'status_code': response.statusCode,
            'response_body': response.body,
            'suggestion': 'Verify your API key has Gemini API permissions',
          };
        } else if (response.statusCode == 429) {
          return {
            'success': false,
            'error': 'Rate limit exceeded',
            'status_code': response.statusCode,
            'suggestion': 'Wait a few minutes and try again',
          };
        } else {
          return {
            'success': false,
            'error': 'API request failed',
            'status_code': response.statusCode,
            'response_body': response.body,
          };
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print('Error testing Gemini connection: $e');

      if (e.toString().contains('TimeoutException')) {
        return {
          'success': false,
          'error': 'Connection timeout - unable to reach Gemini API',
          'details': e.toString(),
          'suggestions': [
            'Check your internet connection',
            'Verify the API URL is accessible from your network',
            'Try using a VPN if in a restricted region',
          ],
        };
      } else if (e.toString().contains('SocketException')) {
        return {
          'success': false,
          'error': 'Network connection failed',
          'details': e.toString(),
          'suggestions': [
            'Check your internet connection',
            'Ensure the device can access external APIs',
          ],
        };
      } else {
        return {
          'success': false,
          'error': 'Unexpected error during API test',
          'details': e.toString(),
        };
      }
    }
  }

  Future<List<Map<String, dynamic>>> _searchWithValidation(
    String searchTerm,
    String recognizedFood,
  ) async {
    try {
      print('Searching for: "$searchTerm" (recognized as: "$recognizedFood")');

      // Get raw search results
      final rawResults = await _foodApiService.searchFood(searchTerm);

      if (rawResults.isEmpty) {
        return [];
      }

      // Filter results based on food category relevance
      final validatedResults = <Map<String, dynamic>>[];
      final foodCategory = _getFoodCategory(recognizedFood);

      for (final result in rawResults) {
        final productName = (result['product_name'] ?? '').toLowerCase();
        final brands = (result['brands'] ?? '').toLowerCase();
        final combinedText = '$productName $brands';

        // Calculate relevance score
        final relevanceScore = _calculateRelevanceScore(
          combinedText,
          searchTerm.toLowerCase(),
          recognizedFood.toLowerCase(),
          foodCategory,
        );

        // Only include results with reasonable relevance
        if (relevanceScore > 0.3) {
          result['relevance_score'] = relevanceScore;
          validatedResults.add(result);
        }
      }

      // Sort by relevance score
      validatedResults.sort(
        (a, b) => (b['relevance_score'] as double).compareTo(
          a['relevance_score'] as double,
        ),
      );

      print(
        'Found ${validatedResults.length} validated results out of ${rawResults.length} total',
      );

      return validatedResults.take(10).toList();
    } catch (e) {
      print('Error in search validation: $e');
      // Fallback to original search if validation fails
      return await _foodApiService.searchFood(searchTerm);
    }
  }

  String _getFoodCategory(String foodName) {
    final name = foodName.toLowerCase();

    // Coffee and tea category
    if (name.contains('coffee') ||
        name.contains('latte') ||
        name.contains('cappuccino') ||
        name.contains('espresso') ||
        name.contains('americano') ||
        name.contains('tea') ||
        name.contains('chai') ||
        name.contains('mocha')) {
      return 'beverage_hot';
    }

    // Fruits
    if (name.contains('apple') ||
        name.contains('banana') ||
        name.contains('orange') ||
        name.contains('berry') ||
        name.contains('grape') ||
        name.contains('fruit')) {
      return 'fruit';
    }

    // Vegetables
    if (name.contains('vegetable') ||
        name.contains('carrot') ||
        name.contains('broccoli') ||
        name.contains('lettuce') ||
        name.contains('tomato') ||
        name.contains('onion')) {
      return 'vegetable';
    }

    // Dairy
    if (name.contains('milk') ||
        name.contains('cheese') ||
        name.contains('yogurt') ||
        name.contains('cream') ||
        name.contains('butter')) {
      return 'dairy';
    }

    return 'general';
  }

  double _calculateRelevanceScore(
    String productText,
    String searchTerm,
    String recognizedFood,
    String category,
  ) {
    double score = 0.0;

    // Direct match with search term
    if (productText.contains(searchTerm)) {
      score += 0.5;
    }

    // Direct match with recognized food
    if (productText.contains(recognizedFood)) {
      score += 0.4;
    }

    // Category-specific scoring
    switch (category) {
      case 'beverage_hot':
        if (productText.contains('coffee') ||
            productText.contains('tea') ||
            productText.contains('espresso') ||
            productText.contains('latte') ||
            productText.contains('cappuccino')) {
          score += 0.3;
        }
        // Penalize water products heavily for coffee/tea searches
        if (productText.contains('water') ||
            productText.contains('aqua') ||
            productText.contains('h2o') ||
            productText.contains('sidi') ||
            productText.contains('mineral water')) {
          score -= 0.8;
        }
        break;

      case 'fruit':
        if (productText.contains('fruit') || productText.contains('juice')) {
          score += 0.2;
        }
        break;

      case 'dairy':
        if (productText.contains('dairy') ||
            productText.contains('milk') ||
            productText.contains('cream')) {
          score += 0.2;
        }
        break;
    }

    return score.clamp(0.0, 1.0);
  }

  List<String> _generateEnhancedSearchTerms(String originalTerm) {
    final terms = <String>[];
    final lowercaseTerm = originalTerm.toLowerCase();

    // Coffee/beverage specific enhancements
    if (lowercaseTerm.contains('latte') || lowercaseTerm.contains('coffee')) {
      terms.addAll(['coffee', 'espresso', 'cappuccino', 'coffee drink']);
    }

    // Add generic versions
    terms.addAll(_generateSimplifiedSearchTerms(originalTerm));

    return terms.take(5).toList();
  }
}

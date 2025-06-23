import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'food_api_service.dart';

class GeminiFoodAnalyzerService {
  static const String _geminiApiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';
  static final String _geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  final FoodApiService _foodApiService = FoodApiService();

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

      final Map<String, dynamic> geminiResult = await compute(
        _analyzeImageWithGemini,
        {'imagePath': imageFile.path, 'apiKey': _geminiApiKey},
      );

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

      // Try to find food data using multiple approaches
      List<Map<String, dynamic>> productCandidates = [];

      // First, try the primary recognized food
      productCandidates = await _foodApiService.searchFood(recognizedFood);

      // If no results found, try the possible alternatives
      if (productCandidates.isEmpty && possibleFoods.isNotEmpty) {
        for (String alternative in possibleFoods) {
          productCandidates = await _foodApiService.searchFood(alternative);
          if (productCandidates.isNotEmpty) {
            break;
          }
        }
      }

      // If still no results, try with simplified terms
      if (productCandidates.isEmpty) {
        final simplifiedTerms = _generateSimplifiedSearchTerms(recognizedFood);
        for (String term in simplifiedTerms) {
          productCandidates = await _foodApiService.searchFood(term);
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

  static Future<Map<String, dynamic>> _analyzeImageWithGemini(
    Map<String, dynamic> params,
  ) async {
    try {
      final File imageFile = File(params['imagePath']);
      final String? apiKey = params['apiKey'];

      if (apiKey == null || apiKey.isEmpty) {
        return {'success': false, 'error': 'Gemini API key is not configured'};
      }

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
                'inline_data': {'mime_type': 'image/jpeg', 'data': base64Image},
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

      final response = await http
          .post(
            Uri.parse('$_geminiApiUrl?key=${apiKey!}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data['candidates'];

        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'];
          final parts = content['parts'];

          if (parts != null && parts.isNotEmpty) {
            final text = parts[0]['text'];

            // Extract JSON from the response
            final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(text);
            if (jsonMatch != null) {
              final jsonStr = jsonMatch.group(0);
              final result = jsonDecode(jsonStr!);

              return {
                'success': true,
                'recognized_food': result['recognized_food'],
                'confidence': (result['confidence'] as num).toDouble(),
                'possible_foods': List<String>.from(result['possible_foods']),
              };
            }
          }
        }

        return {
          'success': false,
          'error': 'Invalid response format from Gemini API',
        };
      } else {
        print('Error from Gemini API: ${response.statusCode}');
        print('Response Body: ${response.body}');
        return {
          'success': false,
          'error': 'API request failed with status ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error in Gemini analysis: $e');
      return {'success': false, 'error': 'Error analyzing image: $e'};
    }
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
}

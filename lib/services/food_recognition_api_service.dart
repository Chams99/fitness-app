import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'food_api_service.dart';

class FoodRecognitionApiService {
  static const String _aiApiUrl =
      'https://api-inference.huggingface.co/models/nateraw/food';
  static final String _aiApiKey = dotenv.env['HUGGING_FACE_API_KEY']!;
  final FoodApiService _foodApiService = FoodApiService();

  // Cache for storing recent results
  static final Map<String, Map<String, dynamic>> _resultCache = {};
  static const Duration _cacheDuration = Duration(minutes: 30);

  Future<Map<String, dynamic>> recognizeFoodFromImage(File imageFile) async {
    try {
      // Check cache first
      final String cacheKey = await _generateCacheKey(imageFile);
      if (_resultCache.containsKey(cacheKey)) {
        final cachedResult = _resultCache[cacheKey]!;
        if (DateTime.now().difference(cachedResult['timestamp'] as DateTime) <
            _cacheDuration) {
          return Map<String, dynamic>.from(cachedResult)..remove('timestamp');
        }
      }

      // Step 1: Get image recognition results using isolate
      final Map<String, dynamic> aiResult = await compute(
        _processImageInIsolate,
        {'imagePath': imageFile.path, 'apiUrl': _aiApiUrl, 'apiKey': _aiApiKey},
      );
      final String? topLabel = aiResult['top_label'];
      final double? topScore = aiResult['top_score'];
      final List<dynamic> rawLabels = aiResult['raw_labels'] ?? [];

      if (topLabel == null) {
        return {
          'success': false,
          'error': 'No food items detected in the image',
          'confidence': 0.0,
          'raw_labels': rawLabels,
        };
      }

      // Step 2: Get the best food match
      final String? bestMatch = await compute(_getBestFoodMatchInIsolate, [
        topLabel,
      ]);
      if (bestMatch == null) {
        return {
          'success': false,
          'error': 'Could not identify a specific food item',
          'confidence': 0.0,
          'raw_labels': rawLabels,
        };
      }

      // Step 3: Get nutritional information
      final foodData = await _foodApiService.searchFood(bestMatch);
      if (foodData == null) {
        return {
          'success': false,
          'error': 'Could not find nutritional information for $bestMatch',
          'confidence': 0.0,
          'raw_labels': rawLabels,
        };
      }

      // Step 4: Prepare and cache the result
      final result = {
        'success': true,
        'food_data': foodData,
        'recognized_labels': [topLabel],
        'best_match': bestMatch,
        'confidence': topScore ?? 0.0,
        'raw_labels': rawLabels,
        'timestamp': DateTime.now(),
      };

      _resultCache[cacheKey] = result;

      return Map<String, dynamic>.from(result)..remove('timestamp');
    } catch (e) {
      print('Error in food recognition: $e');
      return {
        'success': false,
        'error': 'Error processing image: $e',
        'confidence': 0.0,
      };
    }
  }

  Future<String> _generateCacheKey(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return base64Encode(bytes).substring(0, 32); // Use first 32 chars as key
  }

  static Future<Map<String, dynamic>> _processImageInIsolate(
    Map<String, dynamic> params,
  ) async {
    try {
      final File imageFile = File(params['imagePath']);
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Add retry logic for API calls
      int retryCount = 0;
      const maxRetries = 3;
      const retryDelay = Duration(seconds: 1);

      while (retryCount < maxRetries) {
        try {
          final response = await http
              .post(
                Uri.parse(params['apiUrl']),
                headers: {
                  'Authorization': 'Bearer ${params['apiKey']}',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({'inputs': base64Image}),
              )
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            print('Raw AI Model Response: ${response.body}');
            final List<dynamic> results = jsonDecode(response.body);
            if (results.isEmpty) {
              return {'top_label': null, 'top_score': null, 'raw_labels': []};
            }
            final top = results.first;
            return {
              'top_label': top['label'].toString().toLowerCase(),
              'top_score': top['score'],
              'raw_labels':
                  results
                      .map((r) => {'label': r['label'], 'score': r['score']})
                      .toList(),
            };
          } else if (response.statusCode == 503) {
            // Model is loading, wait and retry
            await Future.delayed(retryDelay);
            retryCount++;
            continue;
          } else {
            print('Error from AI API: ${response.statusCode}');
            print('Response Body: ${response.body}');
            return {'top_label': null, 'top_score': null, 'raw_labels': []};
          }
        } catch (e) {
          if (retryCount < maxRetries - 1) {
            await Future.delayed(retryDelay);
            retryCount++;
            continue;
          }
          rethrow;
        }
      }
      return {'top_label': null, 'top_score': null, 'raw_labels': []};
    } catch (e) {
      print('Error in image recognition isolate: $e');
      return {'top_label': null, 'top_score': null, 'raw_labels': []};
    }
  }

  static String? _getBestFoodMatchInIsolate(List<String> labels) {
    if (labels.isEmpty) return null;

    // Define food-related keywords to prioritize
    final List<String> foodKeywords = [
      'fruit',
      'vegetable',
      'meat',
      'chicken',
      'beef',
      'pork',
      'fish',
      'bread',
      'pasta',
      'rice',
      'cereal',
      'milk',
      'cheese',
      'yogurt',
      'egg',
      'butter',
      'oil',
      'soup',
      'salad',
      'pizza',
      'sandwich',
      'burger',
      'fries',
      'dessert',
      'cake',
      'cookie',
      'ice cream',
      'chocolate',
      'candy',
      'juice',
      'coffee',
      'tea',
      'water',
      'drink',
      'beverage',
      'nuts',
      'seeds',
      'beans',
      'lentils',
      'spice',
      'herb',
      'sauce',
      'condiment',
      'snack',
      'cracker',
      'chip',
      'pastry',
      'donut',
      'muffin',
      'pie',
      'tart',
      'stew',
      'curry',
      'roast',
      'grilled',
      'fried',
      'baked',
      'boiled',
      'steamed',
      'raw',
      'smoothie',
      'shake',
      'yogurt',
      'cereal bar',
      'granola',
      'oatmeal',
      'pancake',
      'waffle',
      'syrup',
      'honey',
      'jam',
      'jelly',
      'preserve',
      'peanut butter',
      'nutella',
      'sandwich spread',
      'hummus',
      'guacamole',
      'salsa',
      'ketchup',
      'mustard',
      'mayonnaise',
      'dressing',
      'vinegar',
      'salt',
      'pepper',
      'sugar',
      'flour',
      'dough',
      'batter',
      'gluten',
      'dairy',
      'vegan',
      'vegetarian',
      'organic',
      'processed',
      'natural',
      'fresh',
      'canned',
      'frozen',
      'dried',
      'powder',
      'liquid',
      'solid',
      'portion',
      'serving',
      'meal',
    ];

    // Clean and format labels
    final cleanedLabels =
        labels
            .map(
              (label) =>
                  label
                      .replaceAll(
                        RegExp(
                          r'\b(food|dish|meal|product|item|object|plant|animal|eating|drinking|serving|cuisine|ingredient|natural|fresh|organic)\b',
                        ),
                        '',
                      )
                      .replaceAll(RegExp(r'\s*\(.*?\)\s*'), '')
                      .replaceAll(RegExp(r'\s*,\s*'), ' ')
                      .replaceAll(RegExp(r'\s+'), ' ')
                      .trim(),
            )
            .where((label) => label.isNotEmpty)
            .toList();

    if (cleanedLabels.isEmpty) return null;

    // Find the best match
    for (String keyword in foodKeywords) {
      for (String label in cleanedLabels) {
        if (label.contains(keyword)) {
          return label;
        }
      }
    }

    return cleanedLabels.first;
  }

  double _calculateConfidence(List<String> labels) {
    if (labels.isEmpty) return 0.0;
    // Simple confidence calculation based on number of matches
    return labels.length > 1 ? 0.8 : 0.6;
  }
}

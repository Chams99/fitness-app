import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class AIRecognitionService {
  static const String _apiUrl =
      'https://api-inference.huggingface.co/models/nateraw/food';
  static final String _apiKey = dotenv.env['HUGGING_FACE_API_KEY']!;

  // Cache for storing recent results
  static final Map<String, List<String>> _resultCache = {};
  static const Duration _cacheDuration = Duration(minutes: 30);

  Future<List<String>> recognizeFood(File imageFile) async {
    try {
      // Check cache first
      final String cacheKey = await _generateCacheKey(imageFile);
      if (_resultCache.containsKey(cacheKey)) {
        final cachedResult = _resultCache[cacheKey]!;
        return cachedResult;
      }

      // Process image in isolate
      final List<String> labels = await compute(_processImageInIsolate, {
        'imagePath': imageFile.path,
        'apiUrl': _apiUrl,
        'apiKey': _apiKey,
      });

      // Cache the result
      _resultCache[cacheKey] = labels;

      return labels;
    } catch (e) {
      print('Error in AI recognition: $e');
      return [];
    }
  }

  Future<String> _generateCacheKey(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return base64Encode(bytes).substring(0, 32); // Use first 32 chars as key
  }

  static Future<List<String>> _processImageInIsolate(
    Map<String, dynamic> params,
  ) async {
    try {
      final File imageFile = File(params['imagePath']);
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse(params['apiUrl']),
        headers: {
          'Authorization': 'Bearer ${params['apiKey']}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'inputs': base64Image}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = jsonDecode(response.body);
        return results
            .where((result) => result['score'] > 0.5)
            .map((result) => result['label'].toString().toLowerCase())
            .toList();
      } else {
        print('Error from Hugging Face API: ${response.statusCode}');
        print('Response Body: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error in AI recognition isolate: $e');
      return [];
    }
  }

  Future<String?> getBestFoodMatch(List<String> labels) async {
    if (labels.isEmpty) {
      print('No labels provided to getBestFoodMatch');
      return null;
    }

    // Process in isolate
    return compute(_getBestFoodMatchInIsolate, labels);
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
}

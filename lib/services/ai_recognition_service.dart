import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIRecognitionService {
  static const String _apiUrl =
      'https://api-inference.huggingface.co/models/google/vit-base-patch16-224';
  static final String _apiKey = dotenv.env['HUGGING_FACE_API_KEY']!;

  Future<List<String>> recognizeFood(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'inputs': base64Image}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = jsonDecode(response.body);
        return results
            .where(
              (result) => result['score'] > 0.1,
            ) // Filter low confidence results
            .map((result) => result['label'].toString().toLowerCase())
            .toList();
      } else {
        print('Error from Hugging Face API: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error in AI recognition: $e');
      return [];
    }
  }

  Future<String?> getBestFoodMatch(List<String> labels) async {
    if (labels.isEmpty) return null;

    // Define a list of common food-related keywords to prioritize
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

    // Clean and format labels for better matching
    final cleanedLabels =
        labels
            .map((label) {
              // Remove generic non-food terms and actions
              return label
                  .replaceAll(
                    RegExp(
                      r'\b(food|dish|meal|product|item|object|plant|animal|eating|drinking|serving|cuisine|ingredient|natural|fresh|organic)\b',
                    ),
                    '',
                  )
                  .replaceAll(
                    RegExp(r'\s*\(.*?\)\s*'),
                    '',
                  ) // Remove text in parentheses
                  .replaceAll(
                    RegExp(r'\s*,\s*'),
                    ' ',
                  ) // Replace commas with spaces
                  .replaceAll(
                    RegExp(r'\s+'),
                    ' ',
                  ) // Replace multiple spaces with single space
                  .trim();
            })
            .where((label) => label.isNotEmpty)
            .toList();

    if (cleanedLabels.isEmpty) return null;

    // Prioritize labels that contain known food keywords
    for (String keyword in foodKeywords) {
      for (String label in cleanedLabels) {
        if (label.contains(keyword)) {
          return label;
        }
      }
    }

    // If no specific food keywords found, try to return the most relevant non-generic label
    // This logic can be further refined based on common non-food items returned by the AI
    final nonGenericLabels =
        cleanedLabels.where((label) {
          return ![
            'container',
            'bottle',
            'packaging',
            'liquid',
            'text',
            'label',
            'material',
          ].contains(label);
        }).toList();

    if (nonGenericLabels.isNotEmpty) {
      return nonGenericLabels.first;
    }

    // Fallback to the first cleaned label if no better match is found
    return cleanedLabels.first;
  }
}

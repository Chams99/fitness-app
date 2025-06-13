import 'dart:convert';
import 'package:http/http.dart' as http;

class FoodApiService {
  static const String baseUrl = 'https://world.openfoodfacts.org/api/v2';

  Future<Map<String, dynamic>?> searchFood(String query) async {
    try {
      // Clean and format the query
      final cleanQuery = query.toLowerCase().trim();

      // First try exact match
      final response = await http.get(
        Uri.parse(
          '$baseUrl/search?search_terms=$cleanQuery&search_simple=1&action=process&json=1&page_size=1&sort_by=popularity_key',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['products'] != null && data['products'].isNotEmpty) {
          final product = data['products'][0];

          // Validate the product has required nutritional information
          if (_hasValidNutritionalInfo(product)) {
            return _formatProductData(product);
          }
        }
      }

      // If no exact match or invalid data, try fuzzy search
      final fuzzyResponse = await http.get(
        Uri.parse(
          '$baseUrl/search?search_terms=$cleanQuery&search_simple=1&action=process&json=1&page_size=5&sort_by=popularity_key',
        ),
      );

      if (fuzzyResponse.statusCode == 200) {
        final data = json.decode(fuzzyResponse.body);
        if (data['products'] != null && data['products'].isNotEmpty) {
          // Find the first product with valid nutritional info
          for (var product in data['products']) {
            if (_hasValidNutritionalInfo(product)) {
              return _formatProductData(product);
            }
          }
        }
      }

      return null;
    } catch (e) {
      print('Error searching food: $e');
      return null;
    }
  }

  bool _hasValidNutritionalInfo(Map<String, dynamic> product) {
    final nutriments = product['nutriments'];
    if (nutriments == null) return false;

    // Check if we have at least calories and one other nutrient
    return nutriments['energy-kcal_100g'] != null &&
        (nutriments['proteins_100g'] != null ||
            nutriments['carbohydrates_100g'] != null ||
            nutriments['fat_100g'] != null);
  }

  Map<String, dynamic> _formatProductData(Map<String, dynamic> product) {
    final nutriments = product['nutriments'] ?? {};

    return {
      'product_name': product['product_name'] ?? 'Unknown Food',
      'brands': product['brands'] ?? 'Unknown Brand',
      'nutriments': {
        'energy-kcal_100g': _formatNutrient(nutriments['energy-kcal_100g']),
        'proteins_100g': _formatNutrient(nutriments['proteins_100g']),
        'carbohydrates_100g': _formatNutrient(nutriments['carbohydrates_100g']),
        'fat_100g': _formatNutrient(nutriments['fat_100g']),
        'fiber_100g': _formatNutrient(nutriments['fiber_100g']),
        'sodium_100g': _formatNutrient(nutriments['sodium_100g']),
      },
      'image_url': product['image_url'],
      'nutriscore_grade': product['nutriscore_grade']?.toUpperCase(),
    };
  }

  double? _formatNutrient(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> getFoodByBarcode(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/product/$barcode.json'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['product'] != null) {
          final product = data['product'];
          if (_hasValidNutritionalInfo(product)) {
            return _formatProductData(product);
          }
        }
      }
      return null;
    } catch (e) {
      print('Error getting food by barcode: $e');
      return null;
    }
  }
}

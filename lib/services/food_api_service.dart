import 'dart:convert';
import 'package:http/http.dart' as http;

class FoodApiService {
  static const String baseUrl = 'https://world.openfoodfacts.org/api/v2';

  Future<List<Map<String, dynamic>>> searchFood(String query) async {
    try {
      final cleanQuery = query.toLowerCase().trim().replaceAll(
        RegExp(r's$'),
        '',
      );

      final uri = Uri.parse(
        '$baseUrl/search?search_terms=$cleanQuery&search_simple=1&action=process&json=1&page_size=20&sort_by=popularity_key',
      );

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['products'] != null && data['products'].isNotEmpty) {
          final products =
              (data['products'] as List<dynamic>)
                  .cast<Map<String, dynamic>>()
                  .where(
                    (p) =>
                        _hasValidNutritionalInfo(p) && p['image_url'] != null,
                  )
                  .toList();

          // Score and sort products by relevance
          final scoredProducts =
              products.map((product) {
                final score = _calculateMatchScore(product, cleanQuery);
                return {'product': product, 'score': score};
              }).toList();

          // Sort by score (highest first) and return only the products
          scoredProducts.sort(
            (a, b) => (b['score'] as double).compareTo(a['score'] as double),
          );

          return scoredProducts
              .take(10) // Take top 10 matches
              .map((item) => item['product'] as Map<String, dynamic>)
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error searching food: $e');
      return [];
    }
  }

  double _calculateMatchScore(Map<String, dynamic> product, String query) {
    final productName = (product['product_name'] ?? '').toLowerCase();
    final brands = (product['brands'] ?? '').toLowerCase();
    final categories = (product['categories_tags'] ?? []).cast<String>();

    double score = 0;

    // Exact match gets highest score
    if (productName == query) {
      score += 100;
    }
    // Product name contains the query
    else if (productName.contains(query)) {
      score += 50;

      // Bonus if it's at the beginning
      if (productName.startsWith(query)) {
        score += 20;
      }
    }

    // Check if query appears in categories
    for (String category in categories) {
      if (category.toLowerCase().contains(query)) {
        score += 30;
        break;
      }
    }

    // Penalize branded products (we prefer generic foods)
    if (brands.isNotEmpty && brands != 'unknown' && brands != 'none') {
      score -= 15;
    } else {
      score += 10; // Boost score for generic items
    }

    // Boost if the product name is simple (one or two words)
    final wordCount = productName.split(' ').length;
    if (wordCount <= 2) {
      score += 15;
    } else if (wordCount <= 4) {
      score += 5;
    }

    // Penalize very long product names
    if (productName.length > query.length + 20) {
      score -= 10;
    }

    // Bonus for common food categories
    final commonFoods = [
      'fruit',
      'vegetable',
      'meat',
      'fish',
      'grain',
      'dairy',
    ];
    for (String foodType in commonFoods) {
      if (productName.contains(foodType) ||
          categories.any((c) => c.toLowerCase().contains(foodType))) {
        score += 5;
        break;
      }
    }

    return score;
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

  Map<String, dynamic> formatProductData(Map<String, dynamic> product) {
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
            return formatProductData(product);
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

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FoodApiService {
  // API URLs and keys
  static const String openFoodFactsBaseUrl =
      'https://world.openfoodfacts.org/api/v2';
  static const String usdaFoodDataBaseUrl = 'https://api.nal.usda.gov/fdc/v1';
  static const String edamamBaseUrl =
      'https://api.edamam.com/api/food-database/v2';

  static final String _usdaApiKey = dotenv.env['USDA_API_KEY'] ?? '';
  static final String _edamamAppId = dotenv.env['EDAMAM_APP_ID'] ?? '';
  static final String _edamamAppKey = dotenv.env['EDAMAM_APP_KEY'] ?? '';

  Future<List<Map<String, dynamic>>> searchFood(String query) async {
    try {
      final cleanQuery = query.toLowerCase().trim().replaceAll(
        RegExp(r's$'),
        '',
      );

      // Search all APIs in parallel
      final List<Future<List<Map<String, dynamic>>>> searchFutures = [
        _searchOpenFoodFacts(cleanQuery),
        _searchUSDAFoodData(cleanQuery),
        _searchEdamam(cleanQuery),
      ];

      final List<List<Map<String, dynamic>>> results = await Future.wait(
        searchFutures,
      );

      // Combine all results
      List<Map<String, dynamic>> allResults = [];
      for (var result in results) {
        allResults.addAll(result);
      }

      if (allResults.isEmpty) {
        return [];
      }

      // Score and deduplicate results
      final Map<String, Map<String, dynamic>> uniqueResults = {};

      for (var product in allResults) {
        final productName = (product['product_name'] ?? '').toLowerCase();
        final score = _calculateMatchScore(product, cleanQuery);

        // Use the highest scoring duplicate
        if (!uniqueResults.containsKey(productName) ||
            uniqueResults[productName]!['score'] < score) {
          uniqueResults[productName] = {...product, 'score': score};
        }
      }

      // Sort by score and return top results
      final sortedResults = uniqueResults.values.toList();
      sortedResults.sort(
        (a, b) => (b['score'] as double).compareTo(a['score'] as double),
      );

      return sortedResults.take(10).map((item) {
        final result = Map<String, dynamic>.from(item);
        result.remove('score');
        return result;
      }).toList();
    } catch (e) {
      print('Error searching food: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchOpenFoodFacts(String query) async {
    try {
      final uri = Uri.parse(
        '$openFoodFactsBaseUrl/search?search_terms=$query&search_simple=1&action=process&json=1&page_size=20&sort_by=popularity_key',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['products'] != null) {
          final products = data['products'] as List;
          return products
              .where(
                (p) =>
                    p is Map<String, dynamic> &&
                    _hasValidNutritionalInfo(p) &&
                    p['image_url'] != null,
              )
              .map(
                (product) => _formatOpenFoodFactsProduct(
                  product as Map<String, dynamic>,
                ),
              )
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error searching Open Food Facts: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchUSDAFoodData(String query) async {
    try {
      if (_usdaApiKey.isEmpty) {
        return [];
      }

      final uri = Uri.parse(
        '$usdaFoodDataBaseUrl/foods/search?query=$query&dataType=Foundation,SR%20Legacy&pageSize=25&api_key=$_usdaApiKey',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['foods'] != null) {
          final foods = data['foods'] as List;
          return foods
              .where((f) => f is Map<String, dynamic>)
              .map((food) => _formatUSDAProduct(food as Map<String, dynamic>))
              .where((product) => product != null)
              .cast<Map<String, dynamic>>()
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error searching USDA Food Data: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchEdamam(String query) async {
    try {
      if (_edamamAppId.isEmpty || _edamamAppKey.isEmpty) {
        return [];
      }

      final uri = Uri.parse(
        '$edamamBaseUrl/parser?app_id=$_edamamAppId&app_key=$_edamamAppKey&ingr=$query&nutrition-type=cooking',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['hints'] != null) {
          final hints = data['hints'] as List;
          return hints
              .where((h) => h is Map<String, dynamic> && h['food'] != null)
              .map(
                (hint) =>
                    _formatEdamamProduct(hint['food'] as Map<String, dynamic>),
              )
              .where((product) => product != null)
              .cast<Map<String, dynamic>>()
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error searching Edamam: $e');
      return [];
    }
  }

  Map<String, dynamic> _formatOpenFoodFactsProduct(
    Map<String, dynamic> product,
  ) {
    final nutriments = product['nutriments'] ?? {};
    return {
      'product_name': product['product_name'] ?? 'Unknown Food',
      'brands': product['brands'] ?? 'Unknown Brand',
      'source': 'Open Food Facts',
      'nutriments': {
        'energy-kcal_100g': _formatNutrient(nutriments['energy-kcal_100g']),
        'proteins_100g': _formatNutrient(nutriments['proteins_100g']),
        'carbohydrates_100g': _formatNutrient(nutriments['carbohydrates_100g']),
        'fat_100g': _formatNutrient(nutriments['fat_100g']),
        'fiber_100g': _formatNutrient(nutriments['fiber_100g']),
        'sodium_100g': _formatNutrient(nutriments['sodium_100g']),
      },
      'image_url': product['image_url'],
      'nutriscore_grade': product['nutriscore_grade']?.toString().toUpperCase(),
    };
  }

  Map<String, dynamic>? _formatUSDAProduct(Map<String, dynamic> food) {
    try {
      final nutrients = food['foodNutrients'] as List? ?? [];
      final nutrientMap = <String, double?>{};

      for (var nutrient in nutrients) {
        if (nutrient is Map<String, dynamic>) {
          final nutrientName =
              nutrient['nutrientName']?.toString().toLowerCase() ?? '';
          final value = _formatNutrient(nutrient['value']);

          if (nutrientName.contains('energy') ||
              nutrientName.contains('calorie')) {
            nutrientMap['energy-kcal_100g'] = value;
          } else if (nutrientName.contains('protein')) {
            nutrientMap['proteins_100g'] = value;
          } else if (nutrientName.contains('carbohydrate')) {
            nutrientMap['carbohydrates_100g'] = value;
          } else if (nutrientName.contains('total lipid') ||
              nutrientName.contains('fat')) {
            nutrientMap['fat_100g'] = value;
          } else if (nutrientName.contains('fiber')) {
            nutrientMap['fiber_100g'] = value;
          } else if (nutrientName.contains('sodium')) {
            nutrientMap['sodium_100g'] = value;
          }
        }
      }

      // Only return if we have at least calories
      if (nutrientMap['energy-kcal_100g'] == null) {
        return null;
      }

      return {
        'product_name': food['description'] ?? 'Unknown Food',
        'brands': 'USDA',
        'source': 'USDA Food Data Central',
        'nutriments': nutrientMap,
        'image_url': null,
        'nutriscore_grade': null,
      };
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic>? _formatEdamamProduct(Map<String, dynamic> food) {
    try {
      final nutrients = food['nutrients'] as Map<String, dynamic>? ?? {};

      return {
        'product_name': food['label'] ?? 'Unknown Food',
        'brands': 'Edamam',
        'source': 'Edamam Food Database',
        'nutriments': {
          'energy-kcal_100g': _formatNutrient(nutrients['ENERC_KCAL']),
          'proteins_100g': _formatNutrient(nutrients['PROCNT']),
          'carbohydrates_100g': _formatNutrient(nutrients['CHOCDF']),
          'fat_100g': _formatNutrient(nutrients['FAT']),
          'fiber_100g': _formatNutrient(nutrients['FIBTG']),
          'sodium_100g': _formatNutrient(nutrients['NA']),
        },
        'image_url': food['image'],
        'nutriscore_grade': null,
      };
    } catch (e) {
      return null;
    }
  }

  double _calculateMatchScore(Map<String, dynamic> product, String query) {
    final productName = (product['product_name'] ?? '').toLowerCase();
    final brands = (product['brands'] ?? '').toLowerCase();
    final source = product['source'] ?? '';

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

    // Source-based scoring (prioritize certain databases)
    switch (source) {
      case 'USDA Food Data Central':
        score += 15; // USDA data is generally very reliable
        break;
      case 'Open Food Facts':
        score += 10; // Good coverage for branded products
        break;
      case 'Edamam Food Database':
        score += 12; // Good for generic foods
        break;
    }

    // Penalize branded products for generic searches
    if (brands.isNotEmpty &&
        brands != 'unknown' &&
        brands != 'none' &&
        brands != 'usda' &&
        brands != 'edamam') {
      score -= 5;
    } else {
      score += 10; // Boost score for generic items
    }

    // Boost if the product name is simple
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
    return {
      'product_name': product['product_name'] ?? 'Unknown Food',
      'brands': product['brands'] ?? 'Unknown Brand',
      'source': product['source'] ?? 'Unknown Source',
      'nutriments': product['nutriments'] ?? {},
      'image_url': product['image_url'],
      'nutriscore_grade': product['nutriscore_grade'],
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
      // Try Open Food Facts first (best for barcodes)
      final response = await http
          .get(Uri.parse('$openFoodFactsBaseUrl/product/$barcode.json'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['product'] != null) {
          final product = data['product'];
          if (_hasValidNutritionalInfo(product)) {
            return formatProductData(_formatOpenFoodFactsProduct(product));
          }
        }
      }

      // If Open Food Facts doesn't have it, try USDA
      if (_usdaApiKey.isNotEmpty) {
        final usdaResponse = await http
            .get(
              Uri.parse(
                '$usdaFoodDataBaseUrl/food/$barcode?api_key=$_usdaApiKey',
              ),
            )
            .timeout(const Duration(seconds: 10));

        if (usdaResponse.statusCode == 200) {
          final data = json.decode(usdaResponse.body);
          final formatted = _formatUSDAProduct(data);
          if (formatted != null) {
            return formatProductData(formatted);
          }
        }
      }

      return null;
    } catch (e) {
      print('Error getting food by barcode: $e');
      return null;
    }
  }

  // Method to get API status
  Future<Map<String, bool>> getApiStatus() async {
    final Map<String, bool> status = {};

    try {
      // Test Open Food Facts
      final offResponse = await http
          .get(
            Uri.parse(
              '$openFoodFactsBaseUrl/search?search_terms=apple&search_simple=1&json=1&page_size=1',
            ),
          )
          .timeout(const Duration(seconds: 5));
      status['Open Food Facts'] = offResponse.statusCode == 200;
    } catch (e) {
      status['Open Food Facts'] = false;
    }

    try {
      // Test USDA
      if (_usdaApiKey.isNotEmpty) {
        final usdaResponse = await http
            .get(
              Uri.parse(
                '$usdaFoodDataBaseUrl/foods/search?query=apple&pageSize=1&api_key=$_usdaApiKey',
              ),
            )
            .timeout(const Duration(seconds: 5));
        status['USDA Food Data Central'] = usdaResponse.statusCode == 200;
      } else {
        status['USDA Food Data Central'] = false;
      }
    } catch (e) {
      status['USDA Food Data Central'] = false;
    }

    try {
      // Test Edamam
      if (_edamamAppId.isNotEmpty && _edamamAppKey.isNotEmpty) {
        final edamamResponse = await http
            .get(
              Uri.parse(
                '$edamamBaseUrl/parser?app_id=$_edamamAppId&app_key=$_edamamAppKey&ingr=apple',
              ),
            )
            .timeout(const Duration(seconds: 5));
        status['Edamam Food Database'] = edamamResponse.statusCode == 200;
      } else {
        status['Edamam Food Database'] = false;
      }
    } catch (e) {
      status['Edamam Food Database'] = false;
    }

    return status;
  }
}

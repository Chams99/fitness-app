import 'package:flutter/material.dart';
import 'dart:io';
import '../services/gemini_food_analyzer_service.dart';

/// Example usage of the GeminiFoodAnalyzerService
///
/// This example shows how to:
/// 1. Initialize the service
/// 2. Analyze a food image
/// 3. Get detailed nutritional analysis
/// 4. Handle errors and cache management
class GeminiFoodAnalyzerExample extends StatefulWidget {
  const GeminiFoodAnalyzerExample({super.key});

  @override
  State<GeminiFoodAnalyzerExample> createState() =>
      _GeminiFoodAnalyzerExampleState();
}

class _GeminiFoodAnalyzerExampleState extends State<GeminiFoodAnalyzerExample> {
  final GeminiFoodAnalyzerService _analyzerService =
      GeminiFoodAnalyzerService();
  Map<String, dynamic>? _lastResult;
  bool _isAnalyzing = false;

  /// Example: Basic food image analysis
  Future<void> _analyzeFoodImage(File imageFile) async {
    setState(() {
      _isAnalyzing = true;
    });

    try {
      final result = await _analyzerService.analyzeFoodImage(imageFile);

      setState(() {
        _lastResult = result;
        _isAnalyzing = false;
      });

      // Print results to console for debugging
      print('Analysis Result: $result');

      if (result['success']) {
        print('Food recognized: ${result['recognized_food']}');
        print('Confidence: ${result['confidence']}');
        print('Best match: ${result['best_match']}');

        final foodData = result['food_data'];
        if (foodData != null) {
          print('Food name: ${foodData['product_name']}');
          print('Brand: ${foodData['brands']}');

          final nutriments = foodData['nutriments'];
          print('Calories: ${nutriments['energy-kcal_100g']} kcal/100g');
          print('Protein: ${nutriments['proteins_100g']}g/100g');
          print('Carbs: ${nutriments['carbohydrates_100g']}g/100g');
          print('Fat: ${nutriments['fat_100g']}g/100g');
        }
      } else {
        print('Analysis failed: ${result['error']}');
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });
      print('Error during analysis: $e');
    }
  }

  /// Example: Detailed nutritional analysis
  Future<void> _getDetailedAnalysis(File imageFile) async {
    setState(() {
      _isAnalyzing = true;
    });

    try {
      final result = await _analyzerService.getDetailedNutritionalAnalysis(
        imageFile,
      );

      setState(() {
        _lastResult = result;
        _isAnalyzing = false;
      });

      if (result['success']) {
        final analysis = result['nutritional_analysis'];
        print('Food category: ${analysis['category']}');
        print('Health score: ${analysis['health_score']}');

        final macros = analysis['macronutrient_breakdown'];
        print('Protein: ${macros['protein_percentage']}%');
        print('Carbs: ${macros['carbs_percentage']}%');
        print('Fat: ${macros['fat_percentage']}%');

        final dailyValues = analysis['daily_value_estimates'];
        print('Calories DV: ${dailyValues['calories_dv']}%');
        print('Protein DV: ${dailyValues['protein_dv']}%');
        print('Carbs DV: ${dailyValues['carbs_dv']}%');
        print('Fat DV: ${dailyValues['fat_dv']}%');
        print('Fiber DV: ${dailyValues['fiber_dv']}%');
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });
      print('Error during detailed analysis: $e');
    }
  }

  /// Example: Cache management
  void _showCacheStats() {
    final stats = _analyzerService.getCacheStats();
    print('Cache size: ${stats['cache_size']}');
    print('Cache duration: ${stats['cache_duration_minutes']} minutes');
  }

  void _clearCache() {
    _analyzerService.clearCache();
    print('Cache cleared');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gemini Food Analyzer Example')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gemini Food Analyzer Service Example',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            if (_isAnalyzing) ...[
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 16),
                      Text('Analyzing...'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_lastResult != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last Analysis Result:',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('Success: ${_lastResult!['success']}'),
                      if (_lastResult!['success']) ...[
                        Text(
                          'Recognized: ${_lastResult!['recognized_food'] ?? 'N/A'}',
                        ),
                        Text(
                          'Confidence: ${(_lastResult!['confidence'] * 100).toStringAsFixed(1)}%',
                        ),
                        Text(
                          'Best match: ${_lastResult!['best_match'] ?? 'N/A'}',
                        ),
                        if (_lastResult!['food_data'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Food Data:',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            'Name: ${_lastResult!['food_data']['product_name']}',
                          ),
                          Text('Brand: ${_lastResult!['food_data']['brands']}'),
                        ],
                      ] else ...[
                        Text('Error: ${_lastResult!['error']}'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            const Text(
              'Usage Instructions:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('1. Add your Gemini API key to the .env file:'),
            const Text('   GEMINI_API_KEY=your_api_key_here'),
            const SizedBox(height: 8),
            const Text('2. Call _analyzeFoodImage() with a File object'),
            const Text('3. Handle the result which contains:'),
            const Text('   - success: boolean'),
            const Text('   - recognized_food: string'),
            const Text('   - confidence: double'),
            const Text('   - food_data: nutritional information'),
            const Text('   - possible_foods: list of alternatives'),
            const SizedBox(height: 16),

            const Text(
              'Cache Management:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _showCacheStats,
                  child: const Text('Show Cache Stats'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _clearCache,
                  child: const Text('Clear Cache'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

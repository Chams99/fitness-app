import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/food_api_service.dart';

/// Example showing how to check the status of all food APIs
/// Run this to verify your API keys are working correctly
Future<void> main() async {
  // Load environment variables
  await dotenv.load(fileName: ".env");

  final foodApiService = FoodApiService();

  print('🔍 Testing Food API Connections...\n');

  // Test API status
  final apiStatus = await foodApiService.getApiStatus();

  print('📊 API Status Report:');
  print('=' * 50);

  for (var entry in apiStatus.entries) {
    final status = entry.value ? '✅ ONLINE' : '❌ OFFLINE';
    print('${entry.key}: $status');
  }

  print('\n🍎 Testing Food Search for "latte"...\n');

  // Test food search
  final searchResults = await foodApiService.searchFood('latte');

  if (searchResults.isNotEmpty) {
    print('✅ Found ${searchResults.length} results:');
    print('-' * 40);

    for (int i = 0; i < searchResults.length && i < 5; i++) {
      final food = searchResults[i];
      final name = food['product_name'] ?? 'Unknown';
      final source = food['source'] ?? 'Unknown';
      final calories =
          food['nutriments']?['energy-kcal_100g']?.toString() ?? 'N/A';

      print('${i + 1}. $name');
      print('   Source: $source');
      print('   Calories: ${calories} kcal/100g');
      print('');
    }
  } else {
    print('❌ No results found for "latte"');
    print('This could mean:');
    print('- All APIs are offline');
    print('- API keys are not configured correctly');
    print('- Network connectivity issues');
  }

  // Test with another common food
  print('\n🥕 Testing Food Search for "carrot"...\n');

  final carrotResults = await foodApiService.searchFood('carrot');

  if (carrotResults.isNotEmpty) {
    print('✅ Found ${carrotResults.length} results for carrot');
    final firstResult = carrotResults.first;
    print('Best match: ${firstResult['product_name']}');
    print('Source: ${firstResult['source']}');
  } else {
    print('❌ No results found for "carrot"');
  }

  print('\n' + '=' * 50);
  print('📝 Configuration Tips:');
  print('');
  print('If APIs are offline, check your .env file:');
  print('- GEMINI_API_KEY=your_key_here (required)');
  print('- USDA_API_KEY=your_key_here (optional)');
  print('- EDAMAM_APP_ID=your_id_here (optional)');
  print('- EDAMAM_APP_KEY=your_key_here (optional)');
  print('');
  print('📖 See README.md for detailed setup instructions');
}

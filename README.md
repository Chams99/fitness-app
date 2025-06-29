# Fitness App

A comprehensive Flutter fitness application with AI-powered food recognition and nutrition tracking.

## Features

- 📸 **AI Food Recognition**: Take photos of food and get instant nutritional information
- 🍎 **Multi-Database Food Search**: Searches across multiple food databases for comprehensive coverage
- 📊 **Nutrition Tracking**: Track calories, macronutrients, and micronutrients
- 👤 **User Profiles**: Manage personal information and fitness goals
- 💪 **Workout Tracking**: Log and track workout sessions
- 📱 **Cross-Platform**: Available on iOS, Android, Web, Windows, macOS, and Linux

## Food Recognition System

The app uses multiple food databases to ensure comprehensive coverage:

1. **Open Food Facts** - Free, open database with excellent barcode support
2. **USDA Food Data Central** - Official USDA nutritional database (requires API key)
3. **Edamam Food Database** - Comprehensive food and nutrition database (requires API key)

The system searches all available databases in parallel and combines results with intelligent scoring to provide the most accurate matches.

## Setup

### Prerequisites

- Flutter SDK (version 3.7.2 or higher)
- Dart SDK
- Android Studio / Xcode (for mobile development)
- Google Gemini API key for food image analysis

### API Keys Required

Create a `.env` file in the root directory with the following keys:

```env
# Required for food image analysis
GEMINI_API_KEY=your_gemini_api_key_here

# Optional but recommended for better food database coverage
USDA_API_KEY=your_usda_api_key_here
EDAMAM_APP_ID=your_edamam_app_id_here
EDAMAM_APP_KEY=your_edamam_app_key_here
```

#### How to get API keys:

1. **Gemini API Key** (Required):
   - Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
   - Create a new API key
   - Add to `.env` as `GEMINI_API_KEY`

2. **USDA API Key** (Optional but recommended):
   - Go to [USDA Food Data Central](https://fdc.nal.usda.gov/api-guide.html)
   - Sign up for a free API key
   - Add to `.env` as `USDA_API_KEY`

3. **Edamam API Keys** (Optional but recommended):
   - Go to [Edamam Developer Portal](https://developer.edamam.com/food-database-api)
   - Sign up for a free account
   - Create a Food Database API application
   - Add both `Application ID` and `Application Key` to `.env`

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd fitness-app
```

2. Install dependencies:
```bash
flutter pub get
```

3. Create and configure your `.env` file (see API Keys section above)

4. Run the app:
```bash
flutter run
```

## Usage

1. **Food Recognition**: 
   - Open the food scanner
   - Take a photo of your food
   - The app will analyze the image and search multiple databases
   - Select the best match from the results

2. **Manual Food Search**:
   - Use the search function to find foods manually
   - Results come from multiple databases for comprehensive coverage

3. **Nutrition Tracking**:
   - Add foods to your daily log
   - Track calories and macronutrients
   - View nutritional analysis and insights

## Performance Features

- **Parallel API Searches**: All food databases are searched simultaneously for faster results
- **Intelligent Result Scoring**: Results are scored and ranked based on relevance and source reliability
- **Result Caching**: Recent food recognition results are cached to improve performance
- **Fallback Support**: App gracefully handles API outages by using available databases

## Database Coverage

- **Open Food Facts**: Best for branded products and international foods
- **USDA Food Data Central**: Most accurate for generic foods and USDA-verified nutrition data
- **Edamam**: Excellent for recipe ingredients and cooking measurements

The app automatically combines results from all available databases to provide the most comprehensive food information possible.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
#   f i t n e s s - a p p 
 
 
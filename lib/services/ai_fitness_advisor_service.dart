import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/fitness_profile.dart';
import '../models/fitness_recommendation.dart';

class AIFitnessAdvisorService extends ChangeNotifier {
  static final AIFitnessAdvisorService _instance =
      AIFitnessAdvisorService._internal();
  factory AIFitnessAdvisorService() => _instance;
  AIFitnessAdvisorService._internal();

  static const String _geminiApiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';
  static final String _geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  static const Duration _apiTimeout = Duration(seconds: 30);

  FitnessProfile? _currentProfile;
  FitnessRecommendation? _currentRecommendation;
  bool _isInitialized = false;

  Map<String, dynamic>? _dangerCheckCache;
  String? _dangerCheckCacheKey;

  // Getters
  FitnessProfile? get currentProfile => _currentProfile;
  FitnessRecommendation? get currentRecommendation => _currentRecommendation;
  bool get isInitialized => _isInitialized;

  // Initialize the service
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await _loadProfile();
      await _loadRecommendation();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing AI fitness advisor: $e');
    }
  }

  // Set user profile and generate recommendations
  Future<void> setProfile(FitnessProfile profile) async {
    _currentProfile = profile;
    notifyListeners();
    // Automatically generate recommendations when profile is set
    await generateRecommendations();
  }

  Future<void> generateRecommendations([FitnessProfile? profile]) async {
    final profileToUse = profile ?? _currentProfile;
    if (profileToUse == null) return;

    try {
      final recommendation = await _generateAIRecommendations(profileToUse);
      _currentRecommendation = recommendation;
      notifyListeners();
    } catch (e) {
      print('Error generating recommendations: $e');
      // Generate basic recommendations as fallback
      _currentRecommendation = _generateBasicRecommendations(profileToUse);
      notifyListeners();
    }
  }

  // Generate AI-powered fitness recommendations using Gemini
  Future<FitnessRecommendation> _generateAIRecommendations(
    FitnessProfile profile,
  ) async {
    if (_geminiApiKey.isEmpty) {
      throw Exception('Gemini API key not configured');
    }

    final prompt = _buildFitnessPrompt(profile);

    try {
      final response = await http
          .post(
            Uri.parse('$_geminiApiUrl?key=$_geminiApiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
              'generationConfig': {
                'temperature': 0.7,
                'topK': 40,
                'topP': 0.95,
                'maxOutputTokens': 2048,
              },
            }),
          )
          .timeout(_apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['candidates'][0]['content']['parts'][0]['text'];
        return _parseAIResponse(aiResponse, profile);
      } else {
        throw Exception('API request failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Gemini API error: $e');
      rethrow;
    }
  }

  // Build comprehensive fitness prompt for Gemini
  String _buildFitnessPrompt(FitnessProfile profile) {
    return '''
You are an expert fitness and nutrition advisor. Based on the following detailed user profile, create a comprehensive, personalized fitness plan.

USER PROFILE:
- Name: ${profile.name}
- Age: ${profile.age} years old
- Gender: ${profile.gender.name}
- Weight: ${profile.weight.toStringAsFixed(1)} kg
- Height: ${profile.height.toStringAsFixed(1)} cm
- BMI: ${profile.bmi.toStringAsFixed(1)} (${profile.bmiCategory})
- BMR: ${profile.bmr.toInt()} calories/day
- TDEE: ${profile.tdee.toInt()} calories/day
- Primary Goal: ${profile.goalDescription}
- Current Activity Level: ${_getActivityDescription(profile.currentActivityLevel)}
- Medical Conditions: ${profile.medicalConditions.join(', ')}
- Preferred Workouts: ${profile.preferredWorkoutTypes.join(', ')}
${profile.targetWeight != null ? '- Target Weight: ${profile.targetWeight!.toStringAsFixed(1)} kg' : ''}

INSTRUCTIONS:
Create a personalized fitness plan considering their current fitness level, goals, medical conditions, and preferences. Base recommendations on WHO guidelines and current exercise science.

Respond ONLY with a valid JSON object in this exact format:
{
  "dailyStepsTarget": <number between 5000-15000>,
  "weeklyWorkoutMinutes": <number between 90-420>,
  "workoutSessionsPerWeek": <number between 3-6>,
  "sessionDurationMinutes": <calculated from weekly minutes / sessions>,
  "targetCalorieDeficit": <number, only if weight loss goal, otherwise 0>,
  "targetCalorieSurplus": <number, only if muscle gain goal, otherwise 0>,
  "recommendedWorkoutTypes": [<array of 3-4 specific workout types>],
  "nutritionTips": [<array of 4-5 specific nutrition tips>],
  "reasoning": "<2-3 sentence explanation of the plan>",
  "detailedExplanations": {
    "Steps": "<why this step target>",
    "Workouts": "<why this workout plan>",
    "Sessions": "<why this frequency>",
    "Nutrition": "<why these calorie adjustments>"
  }
}

Consider:
- Safety first: account for medical conditions
- Progressive approach: don't overwhelm beginners
- Evidence-based: follow WHO recommendations (150-300min moderate exercise/week)
- Personalization: adapt to preferences and lifestyle
- Realistic goals: achievable targets that promote long-term success
''';
  }

  // Parse AI response and create recommendation object
  FitnessRecommendation _parseAIResponse(
    String aiResponse,
    FitnessProfile profile,
  ) {
    try {
      // Extract JSON from the response (in case there's extra text)
      final jsonStart = aiResponse.indexOf('{');
      final jsonEnd = aiResponse.lastIndexOf('}') + 1;

      if (jsonStart == -1 || jsonEnd <= jsonStart) {
        throw Exception('No valid JSON found in AI response');
      }

      final jsonString = aiResponse.substring(jsonStart, jsonEnd);
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      return FitnessRecommendation(
        dailyStepsTarget: data['dailyStepsTarget'] ?? 8000,
        weeklyWorkoutMinutes: data['weeklyWorkoutMinutes'] ?? 150,
        workoutSessionsPerWeek: data['workoutSessionsPerWeek'] ?? 3,
        targetCalorieDeficit: (data['targetCalorieDeficit'] ?? 0).toDouble(),
        targetCalorieSurplus: (data['targetCalorieSurplus'] ?? 0).toDouble(),
        recommendedWorkoutTypes: List<String>.from(
          data['recommendedWorkoutTypes'] ?? ['Mixed Training'],
        ),
        nutritionTips: List<String>.from(
          data['nutritionTips'] ?? ['Eat balanced meals'],
        ),
        reasoning:
            data['reasoning'] ?? 'Personalized plan based on your profile',
        detailedExplanations: Map<String, String>.from(
          data['detailedExplanations'] ?? {},
        ),
      );
    } catch (e) {
      debugPrint('Error parsing AI response: $e');
      // Fallback to basic recommendations
      return _generateBasicRecommendations(profile);
    }
  }

  // Fallback basic recommendations if AI fails
  FitnessRecommendation _generateBasicRecommendations(FitnessProfile profile) {
    final stepTarget = _calculateBasicStepTarget(profile);
    final workoutMinutes = _calculateBasicWorkoutMinutes(profile);
    final sessions = _calculateBasicSessions(profile);

    return FitnessRecommendation(
      dailyStepsTarget: stepTarget,
      weeklyWorkoutMinutes: workoutMinutes,
      workoutSessionsPerWeek: sessions,
      targetCalorieDeficit:
          profile.primaryGoal == FitnessGoal.loseWeight ? 500.0 : 0.0,
      targetCalorieSurplus:
          profile.primaryGoal == FitnessGoal.gainMuscle ? 300.0 : 0.0,
      recommendedWorkoutTypes: _getBasicWorkoutTypes(profile),
      nutritionTips: _getBasicNutritionTips(profile),
      reasoning:
          'Basic plan based on your ${profile.goalDescription.toLowerCase()} goal',
      detailedExplanations: {
        'Steps': 'Daily step target based on your activity level',
        'Workouts': 'Weekly exercise following WHO guidelines',
        'Sessions': 'Optimal workout frequency for your level',
        'Nutrition':
            'Calorie guidance based on your BMR: ${profile.bmr.toInt()}',
      },
    );
  }

  // Helper methods for basic calculations
  int _calculateBasicStepTarget(FitnessProfile profile) {
    int base = 8000;
    if (profile.currentActivityLevel == ActivityLevel.sedentary) base = 6000;
    if (profile.currentActivityLevel == ActivityLevel.veryActive) base = 12000;
    if (profile.primaryGoal == FitnessGoal.loseWeight) base += 2000;
    return base.clamp(5000, 15000);
  }

  int _calculateBasicWorkoutMinutes(FitnessProfile profile) {
    int base = 150;
    if (profile.primaryGoal == FitnessGoal.loseWeight) base = 250;
    if (profile.primaryGoal == FitnessGoal.gainMuscle) base = 200;
    if (profile.currentActivityLevel == ActivityLevel.sedentary)
      base = (base * 0.7).round();
    return base.clamp(90, 420);
  }

  int _calculateBasicSessions(FitnessProfile profile) {
    switch (profile.currentActivityLevel) {
      case ActivityLevel.sedentary:
        return 3;
      case ActivityLevel.lightlyActive:
        return 4;
      case ActivityLevel.moderatelyActive:
        return 4;
      case ActivityLevel.veryActive:
        return 5;
      case ActivityLevel.superActive:
        return 6;
    }
  }

  List<String> _getBasicWorkoutTypes(FitnessProfile profile) {
    switch (profile.primaryGoal) {
      case FitnessGoal.loseWeight:
        return ['Cardio', 'Strength Training', 'Walking'];
      case FitnessGoal.gainMuscle:
        return [
          'Strength Training',
          'Resistance Training',
          'Compound Exercises',
        ];
      default:
        return ['Mixed Training', 'Cardio', 'Flexibility'];
    }
  }

  List<String> _getBasicNutritionTips(FitnessProfile profile) {
    return [
      'Drink at least 8 glasses of water daily',
      'Eat protein with every meal',
      'Include vegetables in most meals',
      'Maintain consistent meal timing',
    ];
  }

  String _getActivityDescription(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return 'Sedentary (little/no exercise)';
      case ActivityLevel.lightlyActive:
        return 'Lightly active (1-3 days/week)';
      case ActivityLevel.moderatelyActive:
        return 'Moderately active (3-5 days/week)';
      case ActivityLevel.veryActive:
        return 'Very active (6-7 days/week)';
      case ActivityLevel.superActive:
        return 'Super active (2x/day or intense)';
    }
  }

  // Storage methods
  Future<void> _saveProfile() async {
    if (_currentProfile == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'fitness_profile',
        jsonEncode(_currentProfile!.toMap()),
      );
    } catch (e) {
      debugPrint('Error saving profile: $e');
    }
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('fitness_profile');
      if (profileJson != null) {
        _currentProfile = FitnessProfile.fromMap(jsonDecode(profileJson));
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> _saveRecommendation() async {
    if (_currentRecommendation == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'fitness_recommendation',
        jsonEncode(_currentRecommendation!.toMap()),
      );
    } catch (e) {
      debugPrint('Error saving recommendation: $e');
    }
  }

  Future<void> _loadRecommendation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recommendationJson = prefs.getString('fitness_recommendation');
      if (recommendationJson != null) {
        _currentRecommendation = FitnessRecommendation.fromMap(
          jsonDecode(recommendationJson),
        );
      }
    } catch (e) {
      debugPrint('Error loading recommendation: $e');
    }
  }

  Future<void> updateRecommendation(
    FitnessRecommendation newRecommendation,
  ) async {
    _currentRecommendation = newRecommendation;
    await _saveRecommendation();
    notifyListeners();
  }

  int getDailyCalorieTarget() {
    if (_currentProfile == null || _currentRecommendation == null) return 2000;

    double targetCalories = _currentProfile!.tdee;
    if (_currentRecommendation!.targetCalorieDeficit > 0) {
      targetCalories -= _currentRecommendation!.targetCalorieDeficit;
    } else if (_currentRecommendation!.targetCalorieSurplus > 0) {
      targetCalories += _currentRecommendation!.targetCalorieSurplus;
    }
    return targetCalories.round();
  }

  // Gemini-powered danger check for dangerous/unrealistic goals
  Future<Map<String, dynamic>> checkForDangerousGoals(
    FitnessProfile profile,
    FitnessRecommendation recommendation,
  ) async {
    final cacheKey = _dangerCheckCacheKeyFor(profile, recommendation);
    if (_dangerCheckCacheKey == cacheKey && _dangerCheckCache != null) {
      return _dangerCheckCache!;
    }

    // Add explicit validation for dangerous weight loss goals
    if (profile.primaryGoal == FitnessGoal.loseWeight &&
        profile.targetWeight != null) {
      final weightDifference = profile.weight - profile.targetWeight!;
      final currentBMI = profile.bmi;
      final targetBMI =
          profile.targetWeight! /
          ((profile.height / 100) * (profile.height / 100));

      // Check for dangerous weight loss scenarios
      if (targetBMI < 18.5) {
        return {
          'danger': true,
          'reason':
              'Your target weight would put you in the underweight category (BMI < 18.5). This could be dangerous for your health. Please consult a healthcare provider.',
        };
      }

      if (weightDifference > profile.weight * 0.25) {
        return {
          'danger': true,
          'reason':
              'Your target weight loss is more than 25% of your current body weight. Such extreme weight loss can be dangerous. Please set a more moderate goal or consult a healthcare provider.',
        };
      }
    }

    final prompt = '''
You are a fitness safety expert. Analyze the following user profile and fitness plan for any dangerous, unsafe, or unrealistic goals. Respond ONLY with a JSON: {"danger": true/false, "reason": "..."}. Always flag if any goal is unsafe, extreme, or not recommended by health authorities. If all is safe, set danger to false and reason to "All goals are safe and realistic.".

USER PROFILE:
- Age: ${profile.age}
- Gender: ${profile.gender.name}
- Current Weight: ${profile.weight.toStringAsFixed(1)} kg
- Target Weight: ${profile.targetWeight?.toStringAsFixed(1) ?? 'Not specified'} kg
- Height: ${profile.height.toStringAsFixed(1)} cm
- Current BMI: ${profile.bmi.toStringAsFixed(1)} (${profile.bmiCategory})
- Target BMI: ${profile.targetWeight != null ? (profile.targetWeight! / ((profile.height / 100) * (profile.height / 100))).toStringAsFixed(1) : 'N/A'}
- Medical Conditions: ${profile.medicalConditions.join(', ')}

FITNESS PLAN:
- Goal: ${profile.goalDescription}
- Daily Steps: ${recommendation.dailyStepsTarget}
- Weekly Workout Minutes: ${recommendation.weeklyWorkoutMinutes}
- Workout Sessions/Week: ${recommendation.workoutSessionsPerWeek}
- Target Calorie Deficit: ${recommendation.targetCalorieDeficit}
- Target Calorie Surplus: ${recommendation.targetCalorieSurplus}
- Nutrition Tips: ${recommendation.nutritionTips.join('; ')}

SAFETY GUIDELINES:
1. Weight loss/gain should not exceed 1-2 pounds (0.45-0.9 kg) per week
2. BMI should stay within healthy range (18.5-24.9)
3. Calorie deficit should not exceed 1000 calories/day
4. Total daily calories should not go below BMR
5. Weight loss should not exceed 25% of current body weight
6. Any extreme goals with medical conditions need medical supervision
''';

    try {
      final response = await http
          .post(
            Uri.parse('$_geminiApiUrl?key=$_geminiApiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
              'generationConfig': {
                'temperature': 0.2,
                'topK': 20,
                'topP': 0.8,
                'maxOutputTokens': 256,
              },
            }),
          )
          .timeout(_apiTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['candidates'][0]['content']['parts'][0]['text'];
        final jsonStart = aiResponse.indexOf('{');
        final jsonEnd = aiResponse.lastIndexOf('}') + 1;
        if (jsonStart == -1 || jsonEnd <= jsonStart) {
          throw Exception('No valid JSON found in AI response');
        }
        final jsonString = aiResponse.substring(jsonStart, jsonEnd);
        final result = jsonDecode(jsonString) as Map<String, dynamic>;
        _dangerCheckCache = result;
        _dangerCheckCacheKey = cacheKey;
        return result;
      } else {
        throw Exception('API request failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Gemini danger check error: $e');
      // Fallback: never block, just say unknown
      return {'danger': false, 'reason': 'Could not verify safety.'};
    }
  }

  String _dangerCheckCacheKeyFor(
    FitnessProfile profile,
    FitnessRecommendation rec,
  ) {
    return '${profile.name}_${profile.age}_${profile.gender}_${profile.weight}_${profile.height}_${profile.primaryGoal}_${rec.dailyStepsTarget}_${rec.weeklyWorkoutMinutes}_${rec.targetCalorieDeficit}_${rec.targetCalorieSurplus}';
  }
}

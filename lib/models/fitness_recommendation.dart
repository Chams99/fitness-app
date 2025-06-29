class FitnessRecommendation {
  final int dailyStepsTarget;
  final int weeklyWorkoutMinutes;
  final int workoutSessionsPerWeek;
  final double targetCalorieDeficit; // For weight loss
  final double targetCalorieSurplus; // For weight gain
  final List<String> recommendedWorkoutTypes;
  final List<String> nutritionTips;
  final String reasoning;
  final Map<String, String> detailedExplanations;
  final bool isCustomized; // Whether user has modified AI recommendations

  const FitnessRecommendation({
    required this.dailyStepsTarget,
    required this.weeklyWorkoutMinutes,
    required this.workoutSessionsPerWeek,
    required this.targetCalorieDeficit,
    required this.targetCalorieSurplus,
    required this.recommendedWorkoutTypes,
    required this.nutritionTips,
    required this.reasoning,
    required this.detailedExplanations,
    this.isCustomized = false,
  });

  // Get daily workout minutes
  int get dailyWorkoutMinutes => (weeklyWorkoutMinutes / 7).round();

  // Get session duration
  int get sessionDurationMinutes {
    if (workoutSessionsPerWeek == 0) return 0;
    return (weeklyWorkoutMinutes / workoutSessionsPerWeek).round();
  }

  // Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'dailyStepsTarget': dailyStepsTarget,
      'weeklyWorkoutMinutes': weeklyWorkoutMinutes,
      'workoutSessionsPerWeek': workoutSessionsPerWeek,
      'targetCalorieDeficit': targetCalorieDeficit,
      'targetCalorieSurplus': targetCalorieSurplus,
      'recommendedWorkoutTypes': recommendedWorkoutTypes,
      'nutritionTips': nutritionTips,
      'reasoning': reasoning,
      'detailedExplanations': detailedExplanations,
      'isCustomized': isCustomized,
    };
  }

  // Create from map
  factory FitnessRecommendation.fromMap(Map<String, dynamic> map) {
    return FitnessRecommendation(
      dailyStepsTarget: map['dailyStepsTarget'] as int,
      weeklyWorkoutMinutes: map['weeklyWorkoutMinutes'] as int,
      workoutSessionsPerWeek: map['workoutSessionsPerWeek'] as int,
      targetCalorieDeficit: (map['targetCalorieDeficit'] as num).toDouble(),
      targetCalorieSurplus: (map['targetCalorieSurplus'] as num).toDouble(),
      recommendedWorkoutTypes: List<String>.from(
        map['recommendedWorkoutTypes'],
      ),
      nutritionTips: List<String>.from(map['nutritionTips']),
      reasoning: map['reasoning'] as String,
      detailedExplanations: Map<String, String>.from(
        map['detailedExplanations'],
      ),
      isCustomized: map['isCustomized'] as bool? ?? false,
    );
  }

  // Create customized version
  FitnessRecommendation copyWith({
    int? dailyStepsTarget,
    int? weeklyWorkoutMinutes,
    int? workoutSessionsPerWeek,
    double? targetCalorieDeficit,
    double? targetCalorieSurplus,
    List<String>? recommendedWorkoutTypes,
    List<String>? nutritionTips,
    String? reasoning,
    Map<String, String>? detailedExplanations,
    bool? isCustomized,
  }) {
    return FitnessRecommendation(
      dailyStepsTarget: dailyStepsTarget ?? this.dailyStepsTarget,
      weeklyWorkoutMinutes: weeklyWorkoutMinutes ?? this.weeklyWorkoutMinutes,
      workoutSessionsPerWeek:
          workoutSessionsPerWeek ?? this.workoutSessionsPerWeek,
      targetCalorieDeficit: targetCalorieDeficit ?? this.targetCalorieDeficit,
      targetCalorieSurplus: targetCalorieSurplus ?? this.targetCalorieSurplus,
      recommendedWorkoutTypes:
          recommendedWorkoutTypes ?? this.recommendedWorkoutTypes,
      nutritionTips: nutritionTips ?? this.nutritionTips,
      reasoning: reasoning ?? this.reasoning,
      detailedExplanations: detailedExplanations ?? this.detailedExplanations,
      isCustomized: isCustomized ?? true, // Default to true when copying
    );
  }
}

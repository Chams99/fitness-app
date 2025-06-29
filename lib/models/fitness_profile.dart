enum Gender { male, female, other }

enum FitnessGoal {
  loseWeight,
  gainMuscle,
  maintainWeight,
  improveEndurance,
  generalFitness,
  toneUp,
}

enum ActivityLevel {
  sedentary, // Little to no exercise
  lightlyActive, // Light exercise 1-3 days/week
  moderatelyActive, // Moderate exercise 3-5 days/week
  veryActive, // Hard exercise 6-7 days/week
  superActive, // Very hard exercise, physical job
}

class FitnessProfile {
  final String name;
  final int age;
  final Gender gender;
  final double weight; // kg
  final double height; // cm
  final double? targetWeight; // kg - optional for weight goals
  final int? targetWeightWeeks; // Number of weeks to reach target weight
  final FitnessGoal primaryGoal;
  final ActivityLevel currentActivityLevel;
  final List<String> medicalConditions; // Any conditions to consider
  final List<String> preferredWorkoutTypes; // e.g., cardio, strength, yoga

  const FitnessProfile({
    required this.name,
    required this.age,
    required this.gender,
    required this.weight,
    required this.height,
    this.targetWeight,
    this.targetWeightWeeks,
    required this.primaryGoal,
    required this.currentActivityLevel,
    this.medicalConditions = const [],
    this.preferredWorkoutTypes = const [],
  });

  // Calculate BMI
  double get bmi => weight / ((height / 100) * (height / 100));

  // Get BMI category
  String get bmiCategory {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal weight';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  // Calculate BMR (Basal Metabolic Rate) using Mifflin-St Jeor Equation
  double get bmr {
    switch (gender) {
      case Gender.male:
        return (10 * weight) + (6.25 * height) - (5 * age) + 5;
      case Gender.female:
        return (10 * weight) + (6.25 * height) - (5 * age) - 161;
      case Gender.other:
        // Use average of male and female formulas
        final male = (10 * weight) + (6.25 * height) - (5 * age) + 5;
        final female = (10 * weight) + (6.25 * height) - (5 * age) - 161;
        return (male + female) / 2;
    }
  }

  // Calculate TDEE (Total Daily Energy Expenditure)
  double get tdee {
    double multiplier;
    switch (currentActivityLevel) {
      case ActivityLevel.sedentary:
        multiplier = 1.2;
        break;
      case ActivityLevel.lightlyActive:
        multiplier = 1.375;
        break;
      case ActivityLevel.moderatelyActive:
        multiplier = 1.55;
        break;
      case ActivityLevel.veryActive:
        multiplier = 1.725;
        break;
      case ActivityLevel.superActive:
        multiplier = 1.9;
        break;
    }
    return bmr * multiplier;
  }

  // Calculate estimated stride length
  double get estimatedStrideLength {
    // Adjust stride length based on gender
    double factor = gender == Gender.male ? 0.43 : 0.41;
    return (height * factor) / 100; // Convert cm to meters
  }

  // Calculate calories burned from steps
  double calculateCaloriesFromSteps(int steps) {
    if (steps <= 0) return 0.0;

    // Adjust calorie calculation based on gender and weight
    final strideLength = estimatedStrideLength;
    double factor = gender == Gender.male ? 0.57 : 0.53;
    final caloriesPerStep = strideLength * weight * factor / 1000;

    return steps * caloriesPerStep;
  }

  // Calculate distance from steps
  double calculateDistanceFromSteps(int steps) {
    if (steps <= 0) return 0.0;
    return (steps * estimatedStrideLength) / 1000; // Convert to kilometers
  }

  // Get fitness goal description
  String get goalDescription {
    switch (primaryGoal) {
      case FitnessGoal.loseWeight:
        return 'Lose Weight';
      case FitnessGoal.gainMuscle:
        return 'Gain Muscle';
      case FitnessGoal.maintainWeight:
        return 'Maintain Weight';
      case FitnessGoal.improveEndurance:
        return 'Improve Endurance';
      case FitnessGoal.generalFitness:
        return 'General Fitness';
      case FitnessGoal.toneUp:
        return 'Tone Up';
    }
  }

  // Get activity level description
  String get activityLevelDescription {
    switch (currentActivityLevel) {
      case ActivityLevel.sedentary:
        return 'Sedentary (Little to no exercise)';
      case ActivityLevel.lightlyActive:
        return 'Lightly Active (1-3 days/week)';
      case ActivityLevel.moderatelyActive:
        return 'Moderately Active (3-5 days/week)';
      case ActivityLevel.veryActive:
        return 'Very Active (6-7 days/week)';
      case ActivityLevel.superActive:
        return 'Super Active (2x/day or intense)';
    }
  }

  // Calculate weekly weight loss/gain target
  double? get weeklyWeightChange {
    if (targetWeight == null ||
        targetWeightWeeks == null ||
        targetWeightWeeks! <= 0) {
      return null;
    }
    return (targetWeight! - weight) / targetWeightWeeks!;
  }

  // Check if weight loss/gain rate is safe
  bool get isWeightChangeRateSafe {
    final change = weeklyWeightChange;
    if (change == null) return true;

    // Safe weight loss: max 1 kg per week
    // Safe weight gain: max 0.5 kg per week
    return change.abs() <= (change < 0 ? 1.0 : 0.5);
  }

  // Calculate recommended weeks for target weight
  int? get recommendedWeeks {
    if (targetWeight == null) return null;

    final totalChange = (targetWeight! - weight).abs();
    // For weight loss: 0.5-1 kg per week
    // For weight gain: 0.25-0.5 kg per week
    final weeklyRate =
        targetWeight! < weight ? 0.75 : 0.35; // Average safe rate
    return (totalChange / weeklyRate).ceil();
  }

  // Convert to map for storage
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'gender': gender.index,
      'weight': weight,
      'height': height,
      'targetWeight': targetWeight,
      'targetWeightWeeks': targetWeightWeeks,
      'primaryGoal': primaryGoal.index,
      'currentActivityLevel': currentActivityLevel.index,
      'medicalConditions': medicalConditions,
      'preferredWorkoutTypes': preferredWorkoutTypes,
    };
  }

  // Create from map for storage
  factory FitnessProfile.fromMap(Map<String, dynamic> map) {
    return FitnessProfile(
      name: map['name'] as String,
      age: map['age'] as int,
      gender: Gender.values[map['gender'] as int],
      weight: (map['weight'] as num).toDouble(),
      height: (map['height'] as num).toDouble(),
      targetWeight:
          map['targetWeight'] != null
              ? (map['targetWeight'] as num).toDouble()
              : null,
      targetWeightWeeks: map['targetWeightWeeks'] as int?,
      primaryGoal: FitnessGoal.values[map['primaryGoal'] as int],
      currentActivityLevel:
          ActivityLevel.values[map['currentActivityLevel'] as int],
      medicalConditions: List<String>.from(map['medicalConditions'] ?? []),
      preferredWorkoutTypes: List<String>.from(
        map['preferredWorkoutTypes'] ?? [],
      ),
    );
  }

  // Create a copy with updated values
  FitnessProfile copyWith({
    String? name,
    int? age,
    Gender? gender,
    double? weight,
    double? height,
    double? targetWeight,
    int? targetWeightWeeks,
    FitnessGoal? primaryGoal,
    ActivityLevel? currentActivityLevel,
    List<String>? medicalConditions,
    List<String>? preferredWorkoutTypes,
  }) {
    return FitnessProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      targetWeight: targetWeight ?? this.targetWeight,
      targetWeightWeeks: targetWeightWeeks ?? this.targetWeightWeeks,
      primaryGoal: primaryGoal ?? this.primaryGoal,
      currentActivityLevel: currentActivityLevel ?? this.currentActivityLevel,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      preferredWorkoutTypes:
          preferredWorkoutTypes ?? this.preferredWorkoutTypes,
    );
  }
}

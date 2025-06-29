class User {
  final String name;
  final String goal;
  final int dailySteps;
  final int dailyCalories;
  final int dailyWorkoutMinutes;
  final double weight;
  final double height;

  const User({
    required this.name,
    required this.goal,
    required this.dailySteps,
    required this.dailyCalories,
    required this.dailyWorkoutMinutes,
    required this.weight,
    required this.height,
  });

  // Convert User object to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'goal': goal,
      'dailySteps': dailySteps,
      'dailyCalories': dailyCalories,
      'dailyWorkoutMinutes': dailyWorkoutMinutes,
      'weight': weight,
      'height': height,
    };
  }

  // Helper method to calculate BMI
  double calculateBMI() {
    return weight / ((height / 100) * (height / 100));
  }

  // Helper method to get BMI category
  String get bmiCategory {
    final bmiValue = calculateBMI();
    if (bmiValue < 18.5) return 'Underweight';
    if (bmiValue < 25) return 'Normal weight';
    if (bmiValue < 30) return 'Overweight';
    return 'Obese';
  }

  static String getBMICategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal weight';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  // Calculate estimated stride length in meters based on height
  double get estimatedStrideLength {
    // Stride length is approximately 0.43 times height for adults
    return (height * 0.43) / 100; // Convert cm to meters
  }

  // Calculate calories burned from steps
  double calculateCaloriesFromSteps(int steps) {
    if (steps <= 0) return 0.0;

    // Formula: Calories = Steps × Stride length (m) × Weight (kg) × 0.57
    // This is a widely used approximation for walking calories
    final strideLength = estimatedStrideLength;
    final caloriesPerStep = strideLength * weight * 0.57 / 1000;

    return steps * caloriesPerStep;
  }

  // Get calories per step for quick calculations
  double get caloriesPerStep {
    final strideLength = estimatedStrideLength;
    return strideLength * weight * 0.57 / 1000;
  }

  // Calculate distance walked in kilometers from steps
  double calculateDistanceFromSteps(int steps) {
    if (steps <= 0) return 0.0;
    return (steps * estimatedStrideLength) /
        1000; // Convert meters to kilometers
  }
}

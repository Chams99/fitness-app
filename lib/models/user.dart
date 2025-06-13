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
}

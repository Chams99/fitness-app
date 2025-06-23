import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user.dart';
import '../main.dart'; // Import MainScreen
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static Future<User?> loadSavedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      if (userJson == null || userJson.isEmpty) return null;

      final data = jsonDecode(userJson) as Map<String, dynamic>;

      // Validate required fields
      if (!data.containsKey('name') ||
          !data.containsKey('weight') ||
          !data.containsKey('height')) {
        return null;
      }

      return User(
        name: data['name'] as String,
        goal: data['goal'] as String? ?? '10,000 steps daily',
        dailySteps: (data['dailySteps'] as num?)?.toInt() ?? 0,
        dailyCalories: (data['dailyCalories'] as num?)?.toInt() ?? 0,
        dailyWorkoutMinutes:
            (data['dailyWorkoutMinutes'] as num?)?.toInt() ?? 0,
        weight: (data['weight'] as num).toDouble(),
        height: (data['height'] as num).toDouble(),
      );
    } catch (e) {
      return null;
    }
  }

  static Future<bool> saveUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userMap = {
        'name': user.name,
        'goal': user.goal,
        'dailySteps': user.dailySteps,
        'dailyCalories': user.dailyCalories,
        'dailyWorkoutMinutes': user.dailyWorkoutMinutes,
        'weight': user.weight,
        'height': user.height,
      };
      final result = await prefs.setString('user', jsonEncode(userMap));
      return result;
    } catch (e) {
      return false;
    }
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final user = User(
        name: _nameController.text.trim(),
        goal: '10,000 steps daily',
        dailySteps: 0,
        dailyCalories: 0,
        dailyWorkoutMinutes: 0,
        weight: double.parse(_weightController.text),
        height: double.parse(_heightController.text),
      );

      final saveSuccess = await OnboardingScreen.saveUser(user);

      setState(() {
        _isLoading = false;
      });

      if (saveSuccess) {
        // Show welcome dialog
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder:
                (context) => AlertDialog(
                  title: const Text('Welcome to FitLite!'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hi ${user.name}!'),
                      const SizedBox(height: 16),
                      const Text('Your fitness journey starts now!'),
                      const SizedBox(height: 16),
                      Text(
                        'Current BMI: ${user.calculateBMI().toStringAsFixed(1)}',
                      ),
                      Text(
                        'Category: ${User.getBMICategory(user.calculateBMI())}',
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        // Navigate directly to MainScreen instead of using routes
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => MainScreen(user: user),
                          ),
                          (route) => false,
                        );
                      },
                      child: const Text('Get Started'),
                    ),
                  ],
                ),
          );
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save user data. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                const Icon(Icons.fitness_center, size: 80, color: Colors.blue),
                const SizedBox(height: 24),
                const Text(
                  'Welcome to FitLite',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your personal fitness companion',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                const Text(
                  'Let\'s get to know you',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Your Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _weightController,
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.monitor_weight),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your weight';
                    }
                    final weight = double.tryParse(value);
                    if (weight == null || weight <= 0 || weight > 300) {
                      return 'Please enter a valid weight';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _heightController,
                  decoration: const InputDecoration(
                    labelText: 'Height (cm)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.height),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your height';
                    }
                    final height = double.tryParse(value);
                    if (height == null || height <= 0 || height > 300) {
                      return 'Please enter a valid height';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Text(
                            'Start Your Journey',
                            style: TextStyle(fontSize: 16),
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

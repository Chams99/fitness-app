import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/fitness_profile.dart';
import '../models/user.dart';
import '../services/ai_fitness_advisor_service.dart';
import '../services/units_service.dart';
import '../theme/app_theme.dart';

class FitnessProfileScreen extends StatefulWidget {
  final User user;

  const FitnessProfileScreen({super.key, required this.user});

  @override
  State<FitnessProfileScreen> createState() => _FitnessProfileScreenState();
}

class _FitnessProfileScreenState extends State<FitnessProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController();
  final _targetWeightController = TextEditingController();
  final _targetWeeksController = TextEditingController();

  final UnitsService _unitsService = UnitsService();

  Gender _selectedGender = Gender.male;
  FitnessGoal _selectedGoal = FitnessGoal.generalFitness;
  ActivityLevel _selectedActivityLevel = ActivityLevel.lightlyActive;
  List<String> _selectedConditions = [];
  List<String> _selectedWorkouts = [];

  // Store temporary profile for safety checks
  FitnessProfile? _tempProfile;

  final List<String> _medicalConditions = [
    'None',
    'Heart condition',
    'High blood pressure',
    'Diabetes',
    'Joint problems',
    'Back problems',
    'Asthma',
    'Previous injuries',
  ];

  final List<String> _workoutTypes = [
    'Cardio',
    'Strength training',
    'Yoga',
    'Pilates',
    'Swimming',
    'Cycling',
    'Running',
    'Dancing',
    'Boxing',
    'Martial arts',
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  void _loadExistingProfile() {
    final aiService = AIFitnessAdvisorService();
    final profile = aiService.currentProfile;

    if (profile != null) {
      _ageController.text = profile.age.toString();

      // Load target weight with proper unit conversion
      if (profile.targetWeight != null) {
        _targetWeightController.text = _unitsService.getWeightDisplayValue(
          profile.targetWeight!,
        );
        if (profile.targetWeightWeeks != null) {
          _targetWeeksController.text = profile.targetWeightWeeks.toString();
        }
      }

      setState(() {
        _selectedGender = profile.gender;
        _selectedGoal = profile.primaryGoal;
        _selectedActivityLevel = profile.currentActivityLevel;
        _selectedConditions = List.from(profile.medicalConditions);
        _selectedWorkouts = List.from(profile.preferredWorkoutTypes);
      });
    }
  }

  // Add this method to check weight change safety
  void _checkWeightChangeSafety() {
    if (_selectedGoal != FitnessGoal.loseWeight &&
        _selectedGoal != FitnessGoal.gainMuscle)
      return;

    final targetWeight = _unitsService.parseWeightInput(
      _targetWeightController.text,
    );
    final weeks = int.tryParse(_targetWeeksController.text);

    if (targetWeight != null && weeks != null) {
      _tempProfile = FitnessProfile(
        name: widget.user.name,
        age: int.tryParse(_ageController.text) ?? 0,
        gender: _selectedGender,
        weight: widget.user.weight,
        height: widget.user.height,
        targetWeight: targetWeight,
        targetWeightWeeks: weeks,
        primaryGoal: _selectedGoal,
        currentActivityLevel: _selectedActivityLevel,
        medicalConditions: _selectedConditions,
        preferredWorkoutTypes: _selectedWorkouts,
      );

      if (!_tempProfile!.isWeightChangeRateSafe) {
        final recommendedWeeks = _tempProfile!.recommendedWeeks;
        if (recommendedWeeks != null) {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Unsafe Weight Change Rate'),
                  content: Text(
                    'Your target weight change rate might be unsafe. For healthy and sustainable results, we recommend spreading this change over at least $recommendedWeeks weeks.\n\nWould you like to update your plan to use this safer timeframe?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Keep Current Plan'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _targetWeeksController.text =
                              recommendedWeeks.toString();
                        });
                        Navigator.pop(context);
                      },
                      child: const Text('Use Recommended Time'),
                    ),
                  ],
                ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fitness Profile Setup'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Personal Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildAgeField()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildGenderDropdown()),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Show current weight and height (read-only)
                      _buildCurrentMeasurements(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fitness Goals',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildGoalDropdown(),
                      const SizedBox(height: 16),
                      if (_selectedGoal == FitnessGoal.loseWeight ||
                          _selectedGoal == FitnessGoal.gainMuscle) ...[
                        _buildTargetWeightSection(),
                        const SizedBox(height: 16),
                      ],
                      _buildActivityLevelDropdown(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Health & Preferences',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildMedicalConditionsSection(),
                      const SizedBox(height: 16),
                      _buildWorkoutPreferencesSection(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _generateRecommendations,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Generate AI Recommendations',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentMeasurements() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                'Current Measurements (from your profile)',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weight',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            isDarkMode
                                ? Colors.grey.shade300
                                : Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _unitsService.formatWeight(widget.user.weight),
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Height',
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            isDarkMode
                                ? Colors.grey.shade300
                                : Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _unitsService.formatHeight(widget.user.height),
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAgeField() {
    return TextFormField(
      controller: _ageController,
      decoration: const InputDecoration(
        labelText: 'Age',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Required';
        }
        final age = int.tryParse(value);
        if (age == null || age < 13 || age > 120) {
          return 'Invalid age';
        }
        return null;
      },
    );
  }

  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<Gender>(
      value: _selectedGender,
      decoration: const InputDecoration(
        labelText: 'Gender',
        border: OutlineInputBorder(),
      ),
      items:
          Gender.values.map((gender) {
            return DropdownMenuItem(
              value: gender,
              child: Text(gender.name.toUpperCase()),
            );
          }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedGender = value;
          });
        }
      },
    );
  }

  Widget _buildTargetWeightField() {
    return TextFormField(
      controller: _targetWeightController,
      decoration: InputDecoration(
        labelText:
            _selectedGoal == FitnessGoal.loseWeight
                ? 'Target ${_unitsService.weightLabel}'
                : 'Goal ${_unitsService.weightLabel}',
        border: const OutlineInputBorder(),
        hintText: 'Optional',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          return _unitsService.getWeightValidationMessage(value);
        }
        return null; // Optional field
      },
    );
  }

  Widget _buildGoalDropdown() {
    return DropdownButtonFormField<FitnessGoal>(
      value: _selectedGoal,
      decoration: const InputDecoration(
        labelText: 'Primary Fitness Goal',
        border: OutlineInputBorder(),
      ),
      items:
          FitnessGoal.values.map((goal) {
            return DropdownMenuItem(
              value: goal,
              child: Text(_getGoalDisplayName(goal)),
            );
          }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedGoal = value;
          });
        }
      },
    );
  }

  Widget _buildActivityLevelDropdown() {
    return DropdownButtonFormField<ActivityLevel>(
      value: _selectedActivityLevel,
      decoration: const InputDecoration(
        labelText: 'Current Activity Level',
        border: OutlineInputBorder(),
      ),
      items:
          ActivityLevel.values.map((level) {
            return DropdownMenuItem(
              value: level,
              child: Text(_getActivityLevelDisplayName(level)),
            );
          }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedActivityLevel = value;
          });
        }
      },
    );
  }

  Widget _buildMedicalConditionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Medical Conditions (Select all that apply)',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children:
              _medicalConditions.map((condition) {
                final isSelected = _selectedConditions.contains(condition);
                return FilterChip(
                  label: Text(condition),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (condition == 'None') {
                        _selectedConditions.clear();
                        if (selected) _selectedConditions.add(condition);
                      } else {
                        _selectedConditions.remove('None');
                        if (selected) {
                          _selectedConditions.add(condition);
                        } else {
                          _selectedConditions.remove(condition);
                        }
                      }
                    });
                  },
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildWorkoutPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Preferred Workout Types',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children:
              _workoutTypes.map((workout) {
                final isSelected = _selectedWorkouts.contains(workout);
                return FilterChip(
                  label: Text(workout),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedWorkouts.add(workout);
                      } else {
                        _selectedWorkouts.remove(workout);
                      }
                    });
                  },
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildTargetWeightSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<UnitSystem>(
          valueListenable: _unitsService.unitSystem,
          builder: (context, unitSystem, child) {
            return _buildTargetWeightField();
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _targetWeeksController,
          decoration: const InputDecoration(
            labelText: 'Time to Reach Goal (weeks)',
            border: OutlineInputBorder(),
            helperText:
                'How many weeks do you want to take to reach your target weight?',
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter the number of weeks';
            }
            final weeks = int.tryParse(value);
            if (weeks == null || weeks < 1) {
              return 'Please enter a valid number of weeks';
            }
            return null;
          },
          onChanged: (value) {
            if (value.isNotEmpty) {
              _checkWeightChangeSafety();
            }
          },
        ),
      ],
    );
  }

  String _getGoalDisplayName(FitnessGoal goal) {
    switch (goal) {
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

  String _getActivityLevelDisplayName(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return 'Sedentary (Little/no exercise)';
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

  Future<void> _generateRecommendations() async {
    if (_formKey.currentState!.validate()) {
      final targetWeight =
          _selectedGoal == FitnessGoal.loseWeight ||
                  _selectedGoal == FitnessGoal.gainMuscle
              ? _unitsService.parseWeightInput(_targetWeightController.text)
              : null;

      final targetWeeks =
          _selectedGoal == FitnessGoal.loseWeight ||
                  _selectedGoal == FitnessGoal.gainMuscle
              ? int.tryParse(_targetWeeksController.text)
              : null;

      final profile = FitnessProfile(
        name: widget.user.name,
        age: int.parse(_ageController.text),
        gender: _selectedGender,
        height: widget.user.height,
        weight: widget.user.weight,
        targetWeight: targetWeight,
        targetWeightWeeks: targetWeeks,
        primaryGoal: _selectedGoal,
        currentActivityLevel: _selectedActivityLevel,
        medicalConditions: _selectedConditions,
        preferredWorkoutTypes: _selectedWorkouts,
      );

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating AI recommendations...'),
                ],
              ),
            ),
      );

      try {
        final aiService = AIFitnessAdvisorService();
        await aiService.setProfile(profile);

        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          Navigator.of(context).pushReplacementNamed('/ai-recommendations');
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error generating recommendations: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    _targetWeightController.dispose();
    _targetWeeksController.dispose();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user.dart';
import '../services/units_service.dart';
import '../services/edit_state_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class EditMeasurementsScreen extends StatefulWidget {
  final User user;

  const EditMeasurementsScreen({super.key, required this.user});

  @override
  State<EditMeasurementsScreen> createState() => _EditMeasurementsScreenState();
}

class _EditMeasurementsScreenState extends State<EditMeasurementsScreen> {
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _feetController;
  late TextEditingController _inchesController;

  // Store current values in internal format (kg/cm)
  late double _currentWeightInKg;
  late double _currentHeightInCm;
  late UnitSystem _lastUnitSystem;

  @override
  void initState() {
    super.initState();

    // Get current or saved edit state
    final editState = EditStateService().getEditState(
      widget.user.weight,
      widget.user.height,
    );
    _currentWeightInKg = editState['weightInKg'];
    _currentHeightInCm = editState['heightInCm'];
    final wasEdited = editState['wasEdited'];

    _lastUnitSystem = UnitsService().unitSystem.value;
    _initializeControllers();

    print(
      'DEBUG: Edit measurements screen initialized with unit system: $_lastUnitSystem',
    );
    print(
      'DEBUG: Initial weight: $_currentWeightInKg kg, height: $_currentHeightInCm cm (edited: $wasEdited)',
    );

    // Add listeners to save edit state as user types
    _weightController.addListener(_saveEditStateFromForm);
    _heightController.addListener(_saveEditStateFromForm);
    _feetController.addListener(_saveEditStateFromForm);
    _inchesController.addListener(_saveEditStateFromForm);
  }

  void _initializeControllers() {
    final unitsService = UnitsService();

    // Initialize weight controller with converted value
    _weightController = TextEditingController(
      text: unitsService.getWeightDisplayValue(widget.user.weight),
    );

    if (unitsService.isMetric) {
      // For metric, use height controller
      _heightController = TextEditingController(
        text: widget.user.height.toStringAsFixed(1),
      );
      _feetController = TextEditingController();
      _inchesController = TextEditingController();
    } else {
      // For imperial, use feet and inches controllers
      final feetInches = unitsService.cmToFeetInches(widget.user.height);
      _feetController = TextEditingController(
        text: feetInches['feet'].toString(),
      );
      _inchesController = TextEditingController(
        text: feetInches['inches'].toString(),
      );
      _heightController = TextEditingController();
    }

    // Note: We now capture values on-demand during unit switches
    // rather than continuously listening to avoid conflicts
  }

  void _handleUnitSystemChange() {
    // Handle unit system changes
    setState(() {
      // First, explicitly save current form values before switching
      _saveFormValuesBeforeUnitSwitch();
      _updateControllersForUnitChange();
    });
  }

  void _saveEditStateFromForm() {
    // Save current form state to persist across navigation
    EditStateService().updateEditStateFromForm(
      weightText: _weightController.text,
      heightText: _heightController.text,
      feetText: _feetController.text,
      inchesText: _inchesController.text,
      currentUnitSystem: UnitsService().unitSystem.value,
    );
  }

  void _checkAndUpdateForUnitSystemChange() {
    final currentUnitSystem = UnitsService().unitSystem.value;

    // If unit system has changed since we last checked
    if (currentUnitSystem != _lastUnitSystem) {
      print(
        'DEBUG: Unit system changed detected in build! From $_lastUnitSystem to $currentUnitSystem',
      );

      // Save current form values using the PREVIOUS unit system
      _saveFormValuesWithUnitSystem(_lastUnitSystem);

      // Update controllers for the new unit system
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _updateControllersForUnitChange();
        });
      });
    }
  }

  void _updateControllersForUnitChange() {
    final unitsService = UnitsService();
    final currentUnitSystem = unitsService.unitSystem.value;

    print('DEBUG: Updating controllers for unit change to: $currentUnitSystem');
    print('DEBUG: Current internal weight: $_currentWeightInKg kg');
    print('DEBUG: Current internal height: $_currentHeightInCm cm');

    // Update controllers with values in the NEW unit system
    _weightController.text = unitsService.getWeightDisplayValue(
      _currentWeightInKg,
    );
    print('DEBUG: New weight controller text: ${_weightController.text}');

    if (unitsService.isMetric) {
      _heightController.text = _currentHeightInCm.toStringAsFixed(1);
      _feetController.clear();
      _inchesController.clear();
      print(
        'DEBUG: New height controller text (metric): ${_heightController.text}',
      );
    } else {
      final feetInches = unitsService.cmToFeetInches(_currentHeightInCm);
      _feetController.text = feetInches['feet'].toString();
      _inchesController.text = feetInches['inches'].toString();
      _heightController.clear();
      print(
        'DEBUG: New height controllers text (imperial): ${_feetController.text}\' ${_inchesController.text}"',
      );
    }

    // Update the last known unit system
    _lastUnitSystem = currentUnitSystem;
  }

  void _saveCurrentFormValues() {
    // Parse current form values using the current unit system
    final currentUnitSystem = UnitsService().unitSystem.value;
    _saveFormValuesWithUnitSystem(currentUnitSystem);
  }

  void _saveFormValuesBeforeUnitSwitch() {
    // Save current form values using the LAST KNOWN unit system
    // This is critical for preserving edits when switching units
    print(
      'DEBUG: Saving form values before unit switch. Using last system: $_lastUnitSystem',
    );
    print('DEBUG: Weight controller text: ${_weightController.text}');
    print('DEBUG: Height controller text: ${_heightController.text}');
    print('DEBUG: Feet controller text: ${_feetController.text}');
    print('DEBUG: Inches controller text: ${_inchesController.text}');

    if (_lastUnitSystem == UnitSystem.metric) {
      // Parse as metric
      if (_weightController.text.isNotEmpty) {
        final newWeight = double.tryParse(_weightController.text);
        if (newWeight != null) {
          _currentWeightInKg = newWeight;
          print('DEBUG: Updated weight in kg: $_currentWeightInKg');
        }
      }
      if (_heightController.text.isNotEmpty) {
        final newHeight = double.tryParse(_heightController.text);
        if (newHeight != null) {
          _currentHeightInCm = newHeight;
          print('DEBUG: Updated height in cm: $_currentHeightInCm');
        }
      }
    } else {
      // Parse as imperial
      if (_weightController.text.isNotEmpty) {
        final weightInLbs = double.tryParse(_weightController.text);
        if (weightInLbs != null) {
          _currentWeightInKg = UnitsService().lbsToKg(weightInLbs);
          print('DEBUG: Updated weight in kg (from lbs): $_currentWeightInKg');
        }
      }
      if (_feetController.text.isNotEmpty ||
          _inchesController.text.isNotEmpty) {
        final feet = int.tryParse(_feetController.text) ?? 0;
        final inches = int.tryParse(_inchesController.text) ?? 0;
        _currentHeightInCm = UnitsService().feetInchesToCm(feet, inches);
        print('DEBUG: Updated height in cm (from ft/in): $_currentHeightInCm');
      }
    }

    print(
      'DEBUG: Final internal values - Weight: $_currentWeightInKg kg, Height: $_currentHeightInCm cm',
    );
  }

  void _saveFormValuesWithUnitSystem(UnitSystem unitSystem) {
    if (unitSystem == UnitSystem.metric) {
      // Parse as metric
      if (_weightController.text.isNotEmpty) {
        _currentWeightInKg =
            double.tryParse(_weightController.text) ?? _currentWeightInKg;
      }
      if (_heightController.text.isNotEmpty) {
        _currentHeightInCm =
            double.tryParse(_heightController.text) ?? _currentHeightInCm;
      }
    } else {
      // Parse as imperial
      if (_weightController.text.isNotEmpty) {
        final weightInLbs = double.tryParse(_weightController.text) ?? 0.0;
        _currentWeightInKg = UnitsService().lbsToKg(weightInLbs);
      }
      if (_feetController.text.isNotEmpty ||
          _inchesController.text.isNotEmpty) {
        final feet = int.tryParse(_feetController.text) ?? 0;
        final inches = int.tryParse(_inchesController.text) ?? 0;
        _currentHeightInCm = UnitsService().feetInchesToCm(feet, inches);
      }
    }
  }

  @override
  void dispose() {
    // Remove listeners
    _weightController.removeListener(_saveEditStateFromForm);
    _heightController.removeListener(_saveEditStateFromForm);
    _feetController.removeListener(_saveEditStateFromForm);
    _inchesController.removeListener(_saveEditStateFromForm);

    // Dispose controllers
    _weightController.dispose();
    _heightController.dispose();
    _feetController.dispose();
    _inchesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if unit system has changed and update controllers if needed
    _checkAndUpdateForUnitSystemChange();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Measurements'),
        actions: [
          TextButton(onPressed: _saveMeasurements, child: const Text('Save')),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Measurements',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildMeasurementField(
                      UnitsService().weightLabel,
                      _weightController,
                      Icons.scale,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
                      ],
                      validator:
                          (value) => UnitsService().getWeightValidationMessage(
                            value ?? '',
                          ),
                    ),
                    const SizedBox(height: 16),
                    if (UnitsService().isMetric) ...[
                      _buildMeasurementField(
                        UnitsService().heightLabel,
                        _heightController,
                        Icons.height,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        validator:
                            (value) => UnitsService()
                                .getHeightValidationMessage(value ?? ''),
                      ),
                    ] else ...[
                      _buildImperialHeightFields(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
    );
  }

  Widget _buildImperialHeightFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Height', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _feetController,
                decoration: const InputDecoration(
                  labelText: 'Feet',
                  border: OutlineInputBorder(),
                  suffixText: 'ft',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  final feet = int.tryParse(value ?? '0') ?? 0;
                  final inches = int.tryParse(_inchesController.text) ?? 0;
                  return UnitsService().getHeightValidationMessage(
                    '',
                    feet: feet,
                    inches: inches,
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _inchesController,
                decoration: const InputDecoration(
                  labelText: 'Inches',
                  border: OutlineInputBorder(),
                  suffixText: 'in',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  final feet = int.tryParse(_feetController.text) ?? 0;
                  final inches = int.tryParse(value ?? '0') ?? 0;
                  return UnitsService().getHeightValidationMessage(
                    '',
                    feet: feet,
                    inches: inches,
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveMeasurements() async {
    // Save any pending form changes before creating the user
    _saveCurrentFormValues();

    // Return updated user to previous screen
    final updatedUser = User(
      name: widget.user.name,
      goal: widget.user.goal,
      dailySteps: widget.user.dailySteps,
      dailyCalories: widget.user.dailyCalories,
      dailyWorkoutMinutes: widget.user.dailyWorkoutMinutes,
      weight: _currentWeightInKg,
      height: _currentHeightInCm,
    );

    // Persist updated user to SharedPreferences
    await _saveUserToPreferences(updatedUser);

    // Clear edit state since measurements are saved
    EditStateService().clearEditState();

    print(
      'DEBUG: Saved user with weight: ${updatedUser.weight}kg, height: ${updatedUser.height}cm',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Measurements saved successfully!'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context, updatedUser);
  }

  Future<void> _saveUserToPreferences(User user) async {
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
      await prefs.setString('user', jsonEncode(userMap));
      print('DEBUG: User data saved to SharedPreferences');
    } catch (e) {
      print('DEBUG: Error saving user data: $e');
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user.dart';

class EditMeasurementsScreen extends StatefulWidget {
  final User user;

  const EditMeasurementsScreen({super.key, required this.user});

  @override
  State<EditMeasurementsScreen> createState() => _EditMeasurementsScreenState();
}

class _EditMeasurementsScreenState extends State<EditMeasurementsScreen> {
  late TextEditingController _weightController;
  late TextEditingController _heightController;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
      text: widget.user.weight.toString(),
    );
    _heightController = TextEditingController(
      text: widget.user.height.toString(),
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                      'Weight (kg)',
                      _weightController,
                      Icons.scale,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildMeasurementField(
                      'Height (cm)',
                      _heightController,
                      Icons.height,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*'),
                        ),
                      ],
                    ),
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
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
    );
  }

  void _saveMeasurements() {
    // Return updated user to previous screen
    final updatedUser = User(
      name: widget.user.name,
      goal: widget.user.goal,
      dailySteps: widget.user.dailySteps,
      dailyCalories: widget.user.dailyCalories,
      dailyWorkoutMinutes: widget.user.dailyWorkoutMinutes,
      weight: double.tryParse(_weightController.text) ?? widget.user.weight,
      height: double.tryParse(_heightController.text) ?? widget.user.height,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Measurements saved successfully!'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context, updatedUser);
  }
}

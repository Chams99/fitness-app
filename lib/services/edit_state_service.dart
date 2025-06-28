import 'package:flutter/material.dart';
import 'units_service.dart';

class EditStateService {
  static final EditStateService _instance = EditStateService._internal();
  factory EditStateService() => _instance;
  EditStateService._internal();

  // Store the current edit state
  double? _editedWeightInKg;
  double? _editedHeightInCm;
  UnitSystem? _editUnitSystem;
  bool _hasActiveEdits = false;

  // Save current form state
  void saveEditState({
    required double weightInKg,
    required double heightInCm,
    required UnitSystem unitSystem,
  }) {
    _editedWeightInKg = weightInKg;
    _editedHeightInCm = heightInCm;
    _editUnitSystem = unitSystem;
    _hasActiveEdits = true;

    print(
      'DEBUG: Saved edit state - Weight: ${weightInKg}kg, Height: ${heightInCm}cm, Unit: $unitSystem',
    );
  }

  // Get current edit state or original user values
  Map<String, dynamic> getEditState(
    double originalWeightKg,
    double originalHeightCm,
  ) {
    if (_hasActiveEdits &&
        _editedWeightInKg != null &&
        _editedHeightInCm != null) {
      print(
        'DEBUG: Returning saved edit state - Weight: ${_editedWeightInKg}kg, Height: ${_editedHeightInCm}cm',
      );
      return {
        'weightInKg': _editedWeightInKg!,
        'heightInCm': _editedHeightInCm!,
        'wasEdited': true,
      };
    } else {
      print(
        'DEBUG: No edit state, returning original values - Weight: ${originalWeightKg}kg, Height: ${originalHeightCm}cm',
      );
      return {
        'weightInKg': originalWeightKg,
        'heightInCm': originalHeightCm,
        'wasEdited': false,
      };
    }
  }

  // Clear edit state (call when saving measurements)
  void clearEditState() {
    _editedWeightInKg = null;
    _editedHeightInCm = null;
    _editUnitSystem = null;
    _hasActiveEdits = false;
    print('DEBUG: Cleared edit state');
  }

  // Update edit state from current form values
  void updateEditStateFromForm({
    required String weightText,
    required String heightText,
    required String feetText,
    required String inchesText,
    required UnitSystem currentUnitSystem,
  }) {
    final unitsService = UnitsService();

    if (currentUnitSystem == UnitSystem.metric) {
      // Parse metric values
      if (weightText.isNotEmpty) {
        final weight = double.tryParse(weightText);
        if (weight != null) _editedWeightInKg = weight;
      }
      if (heightText.isNotEmpty) {
        final height = double.tryParse(heightText);
        if (height != null) _editedHeightInCm = height;
      }
    } else {
      // Parse imperial values
      if (weightText.isNotEmpty) {
        final weightLbs = double.tryParse(weightText);
        if (weightLbs != null) {
          _editedWeightInKg = unitsService.lbsToKg(weightLbs);
        }
      }
      if (feetText.isNotEmpty || inchesText.isNotEmpty) {
        final feet = int.tryParse(feetText) ?? 0;
        final inches = int.tryParse(inchesText) ?? 0;
        _editedHeightInCm = unitsService.feetInchesToCm(feet, inches);
      }
    }

    if (_editedWeightInKg != null && _editedHeightInCm != null) {
      _hasActiveEdits = true;
      _editUnitSystem = currentUnitSystem;
      print(
        'DEBUG: Updated edit state from form - Weight: ${_editedWeightInKg}kg, Height: ${_editedHeightInCm}cm',
      );
    }
  }

  bool get hasActiveEdits => _hasActiveEdits;
}

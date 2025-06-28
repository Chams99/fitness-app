import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UnitSystem { metric, imperial }

class UnitsService {
  static final UnitsService _instance = UnitsService._internal();
  factory UnitsService() => _instance;
  UnitsService._internal();

  final ValueNotifier<UnitSystem> _unitSystem = ValueNotifier(
    UnitSystem.metric,
  );

  ValueNotifier<UnitSystem> get unitSystem => _unitSystem;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final units = prefs.getString('units') ?? 'Metric';
    _unitSystem.value =
        units == 'Imperial' ? UnitSystem.imperial : UnitSystem.metric;
  }

  Future<void> setUnitSystem(UnitSystem system) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'units',
      system == UnitSystem.imperial ? 'Imperial' : 'Metric',
    );
    _unitSystem.value = system;
  }

  bool get isMetric => _unitSystem.value == UnitSystem.metric;
  bool get isImperial => _unitSystem.value == UnitSystem.imperial;

  // Weight conversions (kg <-> lbs)
  double kgToLbs(double kg) => kg * 2.20462;
  double lbsToKg(double lbs) => lbs / 2.20462;

  // Height conversions (cm <-> ft/in)
  double cmToInches(double cm) => cm / 2.54;
  double inchesToCm(double inches) => inches * 2.54;

  // Convert height in cm to feet and inches
  Map<String, int> cmToFeetInches(double cm) {
    final totalInches = cmToInches(cm);
    final feet = totalInches ~/ 12;
    final inches = (totalInches % 12).round();
    return {'feet': feet, 'inches': inches};
  }

  // Convert feet and inches to cm
  double feetInchesToCm(int feet, int inches) {
    final totalInches = (feet * 12) + inches;
    return inchesToCm(totalInches.toDouble());
  }

  // Display weight based on current unit system
  String formatWeight(double weightInKg) {
    if (isMetric) {
      return '${weightInKg.toStringAsFixed(1)} kg';
    } else {
      return '${kgToLbs(weightInKg).toStringAsFixed(1)} lbs';
    }
  }

  // Display height based on current unit system
  String formatHeight(double heightInCm) {
    if (isMetric) {
      return '${heightInCm.toStringAsFixed(1)} cm';
    } else {
      final feetInches = cmToFeetInches(heightInCm);
      return '${feetInches['feet']}\'${feetInches['inches']}"';
    }
  }

  // Get weight unit label
  String get weightLabel => isMetric ? 'Weight (kg)' : 'Weight (lbs)';

  // Get height unit label
  String get heightLabel => isMetric ? 'Height (cm)' : 'Height (ft/in)';

  // Convert weight from display units to kg (storage format)
  double weightToKg(double displayWeight) {
    return isMetric ? displayWeight : lbsToKg(displayWeight);
  }

  // Convert weight from kg (storage format) to display units
  double weightFromKg(double kgWeight) {
    return isMetric ? kgWeight : kgToLbs(kgWeight);
  }

  // Convert height from display units to cm (storage format)
  double heightToCm(dynamic displayHeight) {
    if (isMetric) {
      return displayHeight as double;
    } else {
      // For imperial, expect a Map with feet and inches
      if (displayHeight is Map<String, int>) {
        return feetInchesToCm(displayHeight['feet']!, displayHeight['inches']!);
      }
      return displayHeight as double; // fallback
    }
  }

  // Convert height from cm (storage format) to display units
  dynamic heightFromCm(double cmHeight) {
    if (isMetric) {
      return cmHeight;
    } else {
      return cmToFeetInches(cmHeight);
    }
  }

  // Get display value for weight input
  String getWeightDisplayValue(double weightInKg) {
    return weightFromKg(weightInKg).toStringAsFixed(1);
  }

  // Get display value for height input
  String getHeightDisplayValue(double heightInCm) {
    if (isMetric) {
      return heightInCm.toStringAsFixed(1);
    } else {
      final feetInches = cmToFeetInches(heightInCm);
      return '${feetInches['feet']}\' ${feetInches['inches']}"';
    }
  }

  // Parse weight input from string
  double parseWeightInput(String input) {
    final value = double.tryParse(input) ?? 0.0;
    return weightToKg(value);
  }

  // Parse height input from string (for metric) or from separate feet/inches inputs
  double parseHeightInput(String input, {int? feet, int? inches}) {
    if (isMetric) {
      return double.tryParse(input) ?? 0.0;
    } else {
      return feetInchesToCm(feet ?? 0, inches ?? 0);
    }
  }

  // Validation helpers
  bool isValidWeight(double weightInKg) {
    return weightInKg > 0 &&
        weightInKg <= (isMetric ? 300 : 600); // 300kg or 600lbs max
  }

  bool isValidHeight(double heightInCm) {
    return heightInCm > 0 &&
        heightInCm <= (isMetric ? 300 : 120); // 300cm or 10ft max
  }

  // Get weight validation message
  String? getWeightValidationMessage(String input) {
    final weight = double.tryParse(input);
    if (weight == null || weight <= 0) {
      return 'Please enter a valid weight';
    }
    final weightInKg = weightToKg(weight);
    if (!isValidWeight(weightInKg)) {
      return isMetric
          ? 'Weight must be between 1 and 300 kg'
          : 'Weight must be between 1 and 600 lbs';
    }
    return null;
  }

  // Get height validation message
  String? getHeightValidationMessage(String input, {int? feet, int? inches}) {
    if (isMetric) {
      final height = double.tryParse(input);
      if (height == null || height <= 0) {
        return 'Please enter a valid height';
      }
      if (!isValidHeight(height)) {
        return 'Height must be between 1 and 300 cm';
      }
    } else {
      if (feet == null ||
          inches == null ||
          feet < 0 ||
          inches < 0 ||
          inches >= 12) {
        return 'Please enter valid feet and inches';
      }
      final heightInCm = feetInchesToCm(feet, inches);
      if (!isValidHeight(heightInCm)) {
        return 'Height must be between 1\' and 10\'';
      }
    }
    return null;
  }
}

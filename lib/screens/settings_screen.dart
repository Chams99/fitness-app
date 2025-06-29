import 'package:fitness_app/models/user.dart';
import 'package:fitness_app/services/theme_service.dart';
import 'package:fitness_app/services/units_service.dart';
import 'package:fitness_app/services/step_counter_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key, required this.user}) : super(key: key);
  final User user;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StepCounterService _stepService = StepCounterService();

  @override
  void initState() {
    super.initState();
    _stepService.addListener(_onStepServiceUpdate);
  }

  @override
  void dispose() {
    _stepService.removeListener(_onStepServiceUpdate);
    super.dispose();
  }

  void _onStepServiceUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _setNotifications(bool value) async {
    if (value && !_stepService.notificationPermission) {
      // Request permission if not granted
      final granted = await _stepService.requestNotificationPermission();
      if (!granted) {
        // Show dialog to explain why permission is needed
        if (mounted) {
          _showPermissionDialog();
        }
        return;
      }
    }

    await _stepService.toggleNotifications(value);
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text(
              'Notification permission is required to show step count updates in the notification bar. '
              'Please enable notifications in your device settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showUnitsDialog() {
    showDialog(
      context: context,
      builder:
          (context) => ValueListenableBuilder<UnitSystem>(
            valueListenable: UnitsService().unitSystem,
            builder: (context, unitSystem, child) {
              return AlertDialog(
                title: const Text('Select Units'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<UnitSystem>(
                      title: const Text('Metric'),
                      value: UnitSystem.metric,
                      groupValue: unitSystem,
                      onChanged: (value) {
                        if (value != null) {
                          UnitsService().setUnitSystem(value);
                          Navigator.pop(context);
                        }
                      },
                    ),
                    RadioListTile<UnitSystem>(
                      title: const Text('Imperial'),
                      value: UnitSystem.imperial,
                      groupValue: unitSystem,
                      onChanged: (value) {
                        if (value != null) {
                          UnitsService().setUnitSystem(value);
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  void _showPolicyDialog(String title, String content) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(child: Text(content)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Theme Settings
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeService().themeMode,
            builder: (context, themeMode, child) {
              return ListTile(
                leading: const Icon(Icons.palette),
                title: const Text('Dark Mode'),
                trailing: Switch(
                  value: themeMode == ThemeMode.dark,
                  onChanged: (bool value) {
                    ThemeService().setThemeMode(
                      value ? ThemeMode.dark : ThemeMode.light,
                    );
                  },
                ),
              );
            },
          ),
          const Divider(),

          // Notifications Settings
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Step Notifications'),
            subtitle:
                _stepService.notificationPermission
                    ? const Text(
                      'Show persistent step counter in notification bar',
                    )
                    : const Text('Permission required'),
            trailing: Switch(
              value:
                  _stepService.notificationsEnabled &&
                  _stepService.notificationPermission,
              onChanged: (bool value) {
                _setNotifications(value);
              },
            ),
          ),
          const Divider(),

          // Units Settings
          ValueListenableBuilder<UnitSystem>(
            valueListenable: UnitsService().unitSystem,
            builder: (context, unitSystem, child) {
              return ListTile(
                leading: const Icon(Icons.straighten),
                title: const Text('Units'),
                subtitle: Text(
                  unitSystem == UnitSystem.metric ? 'Metric' : 'Imperial',
                ),
                onTap: _showUnitsDialog,
              );
            },
          ),
          const Divider(),

          // About Section
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('About'),
            subtitle: Text('FitLite v1.0.0'),
          ),
          const Divider(),

          // Privacy Policy
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Policy'),
            onTap: () {
              _showPolicyDialog(
                'Privacy Policy',
                'This is a sample privacy policy. Your data is kept private and secure.',
              );
            },
          ),
          const Divider(),

          // Terms of Service
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Terms of Service'),
            onTap: () {
              _showPolicyDialog(
                'Terms of Service',
                'These are the sample terms of service for FitLite.',
              );
            },
          ),
        ],
      ),
    );
  }
}

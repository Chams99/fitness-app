import 'package:fitness_app/models/user.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key, required this.user}) : super(key: key);
  final User user;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;
  bool _notificationsEnabled = true;
  String _units = 'Metric';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _units = prefs.getString('units') ?? 'Metric';
    });
  }

  Future<void> _setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
    setState(() {
      _isDarkMode = value;
    });
    // Show dialog to inform user to restart app for theme changes
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Restart Required'),
            content: const Text(
              'Please restart the app to apply the theme change.',
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

  Future<void> _setNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', value);
    setState(() {
      _notificationsEnabled = value;
    });
  }

  Future<void> _setUnits(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('units', value);
    setState(() {
      _units = value;
    });
  }

  void _showUnitsDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Select Units'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: const Text('Metric'),
                  value: 'Metric',
                  groupValue: _units,
                  onChanged: (value) {
                    if (value != null) {
                      _setUnits(value);
                      Navigator.pop(context);
                    }
                  },
                ),
                RadioListTile<String>(
                  title: const Text('Imperial'),
                  value: 'Imperial',
                  groupValue: _units,
                  onChanged: (value) {
                    if (value != null) {
                      _setUnits(value);
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
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
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Dark Mode'),
            trailing: Switch(
              value: _isDarkMode,
              onChanged: (bool value) {
                _setDarkMode(value);
              },
            ),
          ),
          const Divider(),

          // Notifications Settings
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (bool value) {
                _setNotifications(value);
              },
            ),
          ),
          const Divider(),

          // Units Settings
          ListTile(
            leading: const Icon(Icons.straighten),
            title: const Text('Units'),
            subtitle: Text(_units),
            onTap: _showUnitsDialog,
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

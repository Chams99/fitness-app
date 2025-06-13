import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

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
              value: Theme.of(context).brightness == Brightness.dark,
              onChanged: (bool value) {
                // TODO: Implement theme switching
              },
            ),
          ),
          const Divider(),

          // Notifications Settings
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            trailing: Switch(
              value: true,
              onChanged: (bool value) {
                // TODO: Implement notifications toggle
              },
            ),
          ),
          const Divider(),

          // Units Settings
          ListTile(
            leading: const Icon(Icons.straighten),
            title: const Text('Units'),
            subtitle: const Text('Metric'),
            onTap: () {
              // TODO: Show units selection dialog
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
              // TODO: Show privacy policy
            },
          ),
          const Divider(),

          // Terms of Service
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Terms of Service'),
            onTap: () {
              // TODO: Show terms of service
            },
          ),
        ],
      ),
    );
  }
}

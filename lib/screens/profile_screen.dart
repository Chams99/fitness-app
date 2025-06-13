import 'package:flutter/material.dart';
import '../models/user.dart';
import 'edit_measurements_screen.dart';

class ProfileScreen extends StatelessWidget {
  final User user;

  const ProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Center(
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    child: Icon(Icons.person, size: 50),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Measurements Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Measurements',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => EditMeasurementsScreen(user: user),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildMeasurementItem(
                      context,
                      'BMI',
                      '${user.calculateBMI().toStringAsFixed(1)}',
                      User.getBMICategory(user.calculateBMI()),
                      Icons.monitor_weight,
                    ),
                    const Divider(),
                    _buildMeasurementItem(
                      context,
                      'Weight',
                      '${user.weight.toStringAsFixed(1)} kg',
                      'Current',
                      Icons.scale,
                    ),
                    const Divider(),
                    _buildMeasurementItem(
                      context,
                      'Height',
                      '${user.height.toStringAsFixed(1)} cm',
                      'Current',
                      Icons.height,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 32),

            // Goals Section
            Text(
              'Fitness Goals',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGoalItem(
                      context,
                      'Daily Steps',
                      '${user.dailySteps} / 10,000',
                      Icons.directions_walk,
                    ),
                    const Divider(),
                    _buildGoalItem(
                      context,
                      'Daily Calories',
                      '${user.dailyCalories} / 500',
                      Icons.local_fire_department,
                    ),
                    const Divider(),
                    _buildGoalItem(
                      context,
                      'Workout Minutes',
                      '${user.dailyWorkoutMinutes} / 60',
                      Icons.fitness_center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Achievements Section
            Text(
              'Recent Achievements',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildAchievementItem(
                      context,
                      '7 Day Streak',
                      'Completed workouts for 7 days in a row',
                      Icons.emoji_events,
                    ),
                    const Divider(),
                    _buildAchievementItem(
                      context,
                      '10K Steps',
                      'Reached 10,000 steps in a day',
                      Icons.directions_walk,
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

  Widget _buildMeasurementItem(
    BuildContext context,
    String title,
    String value,
    String subtitle,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyMeasurement(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, size: 24),
        const SizedBox(height: 8),
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildGoalItem(
    BuildContext context,
    String title,
    String progress,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(progress, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementItem(
    BuildContext context,
    String title,
    String description,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.amber),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/fitness_profile.dart';
import '../services/units_service.dart';
import '../services/ai_fitness_advisor_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_advisor_card.dart';
import 'edit_measurements_screen.dart';
import 'fitness_profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ProfileScreen extends StatefulWidget {
  final User user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  late User _user;
  final AIFitnessAdvisorService _aiService = AIFitnessAdvisorService();

  Map<String, dynamic>? _dangerCheckResult;
  bool _dangerLoading = false;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    WidgetsBinding.instance.addObserver(this);
    _loadUserFromPreferences(); // Load latest user data
    _aiService.addListener(_onAIUpdate);
    _checkDanger();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _aiService.removeListener(_onAIUpdate);
    super.dispose();
  }

  void _onAIUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUserFromPreferences(); // Reload when app resumes
    }
  }

  Future<void> _loadUserFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');

      if (userJson != null && userJson.isNotEmpty) {
        final data = jsonDecode(userJson) as Map<String, dynamic>;

        if (data.containsKey('name') &&
            data.containsKey('weight') &&
            data.containsKey('height')) {
          final loadedUser = User(
            name: data['name'] as String,
            goal: data['goal'] as String? ?? '10,000 steps daily',
            dailySteps: (data['dailySteps'] as num?)?.toInt() ?? 0,
            dailyCalories: (data['dailyCalories'] as num?)?.toInt() ?? 0,
            dailyWorkoutMinutes:
                (data['dailyWorkoutMinutes'] as num?)?.toInt() ?? 0,
            weight: (data['weight'] as num).toDouble(),
            height: (data['height'] as num).toDouble(),
          );

          print(
            'DEBUG: ProfileScreen loaded user from preferences - Weight: ${loadedUser.weight}kg, Height: ${loadedUser.height}cm',
          );

          setState(() {
            _user = loadedUser;
          });
        }
      }
    } catch (e) {
      print('DEBUG: Error loading user from preferences: $e');
    }
  }

  Future<void> _editMeasurements() async {
    final updatedUser = await Navigator.push<User>(
      context,
      MaterialPageRoute(
        builder: (context) => EditMeasurementsScreen(user: _user),
      ),
    );

    if (updatedUser != null) {
      setState(() {
        _user = updatedUser;
      });
      print(
        'DEBUG: ProfileScreen updated with returned user - Weight: ${updatedUser.weight}kg, Height: ${updatedUser.height}cm',
      );

      // Update AI advisor profile with new measurements
      final currentProfile = _aiService.currentProfile;
      if (currentProfile != null) {
        final updatedProfile = currentProfile.copyWith(
          weight: updatedUser.weight,
          height: updatedUser.height,
        );
        await _aiService.setProfile(updatedProfile);
        // Force recalculation of recommendations with new measurements
        await _aiService.generateRecommendations(updatedProfile);
        // Recheck for dangerous goals with new measurements
        await _checkDanger();
      }
    }
  }

  Future<void> _checkDanger() async {
    final profile = _aiService.currentProfile;
    final recommendation = _aiService.currentRecommendation;
    if (profile != null && recommendation != null) {
      setState(() {
        _dangerLoading = true;
      });
      final result = await _aiService.checkForDangerousGoals(
        profile,
        recommendation,
      );
      if (mounted) {
        setState(() {
          _dangerCheckResult = result;
          _dangerLoading = false;
        });
      }
    }
  }

  Future<void> _editName() async {
    final nameController = TextEditingController(text: _user.name);

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Name'),
            content: TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter your name',
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final newName = nameController.text.trim();
                  if (newName.isNotEmpty) {
                    final updatedUser = User(
                      name: newName,
                      goal: _user.goal,
                      dailySteps: _user.dailySteps,
                      dailyCalories: _user.dailyCalories,
                      dailyWorkoutMinutes: _user.dailyWorkoutMinutes,
                      weight: _user.weight,
                      height: _user.height,
                    );

                    // Save to preferences
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString(
                      'user',
                      jsonEncode(updatedUser.toJson()),
                    );

                    if (mounted) {
                      setState(() {
                        _user = updatedUser;
                      });
                    }

                    if (mounted) {
                      Navigator.pop(context);
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadUserFromPreferences();
          await _checkDanger();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _user.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: _editName,
                            tooltip: 'Edit Name',
                          ),
                        ],
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
                      onPressed: _editMeasurements,
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<UnitSystem>(
                  valueListenable: UnitsService().unitSystem,
                  builder: (context, unitSystem, child) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildMeasurementItem(
                              context,
                              'BMI',
                              _user.calculateBMI().toStringAsFixed(1),
                              User.getBMICategory(_user.calculateBMI()),
                              Icons.monitor_weight,
                            ),
                            const Divider(),
                            _buildMeasurementItem(
                              context,
                              'Weight',
                              UnitsService().formatWeight(_user.weight),
                              'Current',
                              Icons.scale,
                            ),
                            const Divider(),
                            _buildMeasurementItem(
                              context,
                              'Height',
                              UnitsService().formatHeight(_user.height),
                              'Current',
                              Icons.height,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),

                // AI Recommendations Section
                const SizedBox(height: 24),
                Text(
                  'AI Fitness Plan',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                AIAdvisorCard(
                  user: _user,
                  profile: _aiService.currentProfile,
                  recommendation: _aiService.currentRecommendation,
                  dangerCheckResult: _dangerCheckResult,
                  isDangerLoading: _dangerLoading,
                  onViewPlan: () {
                    Navigator.pushNamed(context, '/ai-recommendations');
                  },
                ),

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
                          '${_user.dailySteps} / 10,000',
                          Icons.directions_walk,
                        ),
                        const Divider(),
                        _buildGoalItem(
                          context,
                          'Daily Calories',
                          '${_user.dailyCalories} / 500',
                          Icons.local_fire_department,
                        ),
                        const Divider(),
                        _buildGoalItem(
                          context,
                          'Workout Minutes',
                          '${_user.dailyWorkoutMinutes} / 60',
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

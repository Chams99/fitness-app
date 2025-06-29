import 'package:fitness_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:iconsax/iconsax.dart';
import '../models/user.dart';
import '../services/step_counter_service.dart';
import '../services/ai_fitness_advisor_service.dart';
import '../services/units_service.dart';
import '../widgets/ai_advisor_card.dart';
import 'settings_screen.dart';
import 'weekly_steps_screen.dart';
import 'fitness_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final User user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StepCounterService _stepService = StepCounterService();
  final AIFitnessAdvisorService _aiService = AIFitnessAdvisorService();
  final UnitsService _unitsService = UnitsService();

  Map<String, dynamic>? _dangerCheckResult;
  bool _dangerLoading = false;

  @override
  void initState() {
    super.initState();
    _stepService.setUser(widget.user);
    _stepService.addListener(_onStepUpdate);
    _aiService.addListener(_onAIUpdate);
    _unitsService.unitSystem.addListener(_onUnitsUpdate);
    _checkDanger();
  }

  @override
  void dispose() {
    _stepService.removeListener(_onStepUpdate);
    _aiService.removeListener(_onAIUpdate);
    _unitsService.unitSystem.removeListener(_onUnitsUpdate);
    super.dispose();
  }

  void _onStepUpdate() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  void _onAIUpdate() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  void _onUnitsUpdate() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FitLite'),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.setting_4),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(user: widget.user),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Text(
              'Welcome, ${widget.user.name}!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(_getGoalText(), style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),

            // AI Recommendations Card (if available or suggestion)
            _buildAIRecommendationsCard(),
            const SizedBox(height: 16),

            // Progress toward goal card
            if (_stepService.hasPermission) _buildGoalProgressCard(),
            const SizedBox(height: 16),

            // Today's Summary Card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Today's Summary",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const WeeklyStepsScreen(),
                              ),
                            );
                          },
                          child: _buildStepStatItem(
                            context,
                            'Steps',
                            _stepService.currentSteps.toString(),
                            FontAwesomeIcons.personWalking,
                          ),
                        ),
                        _buildStatItem(
                          context,
                          'Calories',
                          _stepService.currentCalories.toStringAsFixed(0),
                          FontAwesomeIcons.fire,
                        ),
                        _buildStatItem(
                          context,
                          'Distance',
                          _unitsService.formatDistance(
                            _stepService.currentDistance,
                          ),
                          FontAwesomeIcons.route,
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

  String _getGoalText() {
    final recommendation = _aiService.currentRecommendation;
    if (recommendation != null) {
      return 'AI Goal: ${recommendation.dailyStepsTarget.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} steps daily';
    }
    return 'Daily Goal: ${widget.user.goal}';
  }

  Widget _buildAIRecommendationsCard() {
    final profile = _aiService.currentProfile;
    final recommendation = _aiService.currentRecommendation;

    return AIAdvisorCard(
      user: widget.user,
      profile: profile,
      recommendation: recommendation,
      dangerCheckResult: _dangerCheckResult,
      isDangerLoading: _dangerLoading,
      onViewPlan: () {
        Navigator.pushNamed(context, '/ai-recommendations');
      },
    );
  }

  Widget _buildGoalProgressCard() {
    // Use AI recommendation for step goal if available
    final recommendation = _aiService.currentRecommendation;
    int dailyGoal;

    if (recommendation != null) {
      dailyGoal = recommendation.dailyStepsTarget;
    } else {
      // Extract step goal number from user's goal string (e.g., "10,000 steps daily")
      final goalString = widget.user.goal;
      final goalMatch = RegExp(
        r'(\d{1,3}(?:,\d{3})*|\d+)',
      ).firstMatch(goalString);
      dailyGoal =
          goalMatch != null
              ? int.parse(goalMatch.group(1)!.replaceAll(',', ''))
              : 10000;
    }

    final currentSteps = _stepService.currentSteps;
    final progress = currentSteps / dailyGoal;
    final progressPercentage = (progress * 100).clamp(0, 100);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  recommendation != null
                      ? 'AI Goal Progress'
                      : 'Daily Goal Progress',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${progressPercentage.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color:
                        progress >= 1.0
                            ? Colors.green
                            : Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? Colors.green : Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$currentSteps / ${dailyGoal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} steps',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (progress >= 1.0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.celebration, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      'Goal achieved! 🎉',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Stack(
          children: [
            Icon(icon, size: 30),
            if (!_stepService.hasPermission)
              Positioned(
                right: 0,
                top: 0,
                child: Icon(Icons.warning, size: 12, color: Colors.orange),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _stepService.hasPermission ? value : '0',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        if (!_stepService.hasPermission)
          Text(
            'Tap for details',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.orange),
          ),
      ],
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, size: 30),
        const SizedBox(height: 8),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

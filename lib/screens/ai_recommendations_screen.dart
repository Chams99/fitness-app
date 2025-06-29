import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/fitness_profile.dart';
import '../models/fitness_recommendation.dart';
import '../services/ai_fitness_advisor_service.dart';
import '../services/units_service.dart';
import '../theme/app_theme.dart';

class AIRecommendationsScreen extends StatefulWidget {
  const AIRecommendationsScreen({super.key});

  @override
  State<AIRecommendationsScreen> createState() =>
      _AIRecommendationsScreenState();
}

class _AIRecommendationsScreenState extends State<AIRecommendationsScreen> {
  final AIFitnessAdvisorService _aiService = AIFitnessAdvisorService();
  final UnitsService _unitsService = UnitsService();
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final TextEditingController _stepsController = TextEditingController();
  final TextEditingController _workoutMinutesController =
      TextEditingController();
  final TextEditingController _sessionsController = TextEditingController();

  bool _isEditing = false;

  Map<String, dynamic>? _dangerCheckResult;
  bool _dangerLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _unitsService.unitSystem.addListener(_onUnitsUpdate);
    _checkDanger();
  }

  void _initializeControllers() {
    final recommendation = _aiService.currentRecommendation;
    if (recommendation != null) {
      _stepsController.text = recommendation.dailyStepsTarget.toString();
      _workoutMinutesController.text =
          recommendation.weeklyWorkoutMinutes.toString();
      _sessionsController.text =
          recommendation.workoutSessionsPerWeek.toString();
    }
  }

  void _onUnitsUpdate() {
    if (mounted) {
      setState(() {});
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
    final profile = _aiService.currentProfile;
    final recommendation = _aiService.currentRecommendation;

    if (profile == null || recommendation == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('AI Recommendations'),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text(
            'No recommendations available. Please set up your profile first.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Fitness Recommendations'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
            ),
          if (_isEditing) ...[
            IconButton(icon: const Icon(Icons.save), onPressed: _saveChanges),
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _initializeControllers();
                });
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          if (_dangerLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  SizedBox(width: 8),
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(width: 12),
                  Text('Checking plan safety...'),
                ],
              ),
            ),
          if (_dangerCheckResult != null &&
              _dangerCheckResult!['danger'] == true)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    Theme.of(
                      context,
                    ).extension<ThemeColors>()?.warningBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color:
                        Theme.of(
                          context,
                        ).extension<ThemeColors>()?.warningColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '⚠️ Warning: Your current plan may be unsafe or unrealistic.\n${_dangerCheckResult!['reason']}',
                      style: TextStyle(
                        color:
                            Theme.of(
                              context,
                            ).extension<ThemeColors>()?.warningColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _buildPageIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              children: [
                _buildOverviewPage(profile, recommendation),
                _buildDetailsPage(recommendation),
                _buildNutritionPage(recommendation),
              ],
            ),
          ),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  _currentPage == index
                      ? AppTheme.primaryColor
                      : Colors.grey.shade300,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildOverviewPage(
    FitnessProfile profile,
    FitnessRecommendation recommendation,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(profile),
          const SizedBox(height: 16),
          _buildQuickStatsCard(recommendation),
          const SizedBox(height: 16),
          _buildEditableRecommendationCard(recommendation),
        ],
      ),
    );
  }

  Widget _buildDetailsPage(FitnessRecommendation recommendation) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Workout Plan',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildWorkoutTypesCard(recommendation),
          const SizedBox(height: 16),
          _buildReasoningCard(recommendation),
        ],
      ),
    );
  }

  Widget _buildNutritionPage(FitnessRecommendation recommendation) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nutrition Guidance',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildCalorieTargetCard(),
          const SizedBox(height: 16),
          _buildNutritionTipsCard(recommendation),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard(FitnessProfile profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, ${profile.name}!',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Here\'s your personalized fitness plan for ${profile.goalDescription.toLowerCase()}.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _buildInfoChip('Age: ${profile.age}'),
                _buildInfoChip('BMI: ${profile.bmi.toStringAsFixed(1)}'),
                _buildInfoChip(profile.bmiCategory),
                _buildInfoChip(_unitsService.formatWeight(profile.weight)),
                _buildInfoChip(_unitsService.formatHeight(profile.height)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
    );
  }

  Widget _buildQuickStatsCard(FitnessRecommendation recommendation) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Stats',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Daily Steps',
                    '${recommendation.dailyStepsTarget}',
                    Icons.directions_walk,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Weekly Workouts',
                    '${recommendation.sessionDurationMinutes}min × ${recommendation.workoutSessionsPerWeek}',
                    Icons.fitness_center,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEditableRecommendationCard(
    FitnessRecommendation recommendation,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Daily Targets',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (recommendation.isCustomized) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.edit, size: 16, color: Colors.orange),
                  const Text(
                    ' Customized',
                    style: TextStyle(color: Colors.orange),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            _buildEditableField(
              'Daily Steps Target',
              _stepsController,
              '${recommendation.dailyStepsTarget} steps',
              Icons.directions_walk,
            ),
            const SizedBox(height: 16),

            _buildEditableField(
              'Weekly Workout Minutes',
              _workoutMinutesController,
              '${recommendation.weeklyWorkoutMinutes} minutes',
              Icons.fitness_center,
            ),
            const SizedBox(height: 16),

            _buildEditableField(
              'Workout Sessions per Week',
              _sessionsController,
              '${recommendation.workoutSessionsPerWeek} sessions',
              Icons.schedule,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller,
    String displayValue,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              if (_isEditing)
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                )
              else
                Text(
                  displayValue,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWorkoutTypesCard(FitnessRecommendation recommendation) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recommended Workout Types',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  recommendation.recommendedWorkoutTypes.map((type) {
                    return Chip(
                      label: Text(type),
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalorieTargetCard() {
    final profile = _aiService.currentProfile!;
    final targetCalories = _aiService.getDailyCalorieTarget();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Calorie Target',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.local_fire_department, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$targetCalories calories/day',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'BMR: ${profile.bmr.toInt()} | TDEE: ${profile.tdee.toInt()}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Based on: ${_unitsService.formatWeight(profile.weight)}, ${_unitsService.formatHeight(profile.height)}, ${profile.age}y ${profile.gender.name}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionTipsCard(FitnessRecommendation recommendation) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nutrition Tips',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...recommendation.nutritionTips.map((tip) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(tip)),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildReasoningCard(FitnessRecommendation recommendation) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.psychology, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'AI Analysis',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              recommendation.reasoning,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            ElevatedButton.icon(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Previous'),
            )
          else
            const SizedBox(),

          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/home');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Start Your Journey'),
          ),

          if (_currentPage < 2)
            ElevatedButton.icon(
              onPressed: () {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next'),
            )
          else
            const SizedBox(),
        ],
      ),
    );
  }

  void _saveChanges() async {
    try {
      final currentRecommendation = _aiService.currentRecommendation!;
      final updatedRecommendation = currentRecommendation.copyWith(
        dailyStepsTarget: int.parse(_stepsController.text),
        weeklyWorkoutMinutes: int.parse(_workoutMinutesController.text),
        workoutSessionsPerWeek: int.parse(_sessionsController.text),
        isCustomized: true,
      );

      await _aiService.updateRecommendation(updatedRecommendation);

      setState(() {
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recommendations updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving changes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _stepsController.dispose();
    _workoutMinutesController.dispose();
    _sessionsController.dispose();
    _unitsService.unitSystem.removeListener(_onUnitsUpdate);
    super.dispose();
  }
}

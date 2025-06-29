import 'package:flutter/material.dart';
import '../models/fitness_profile.dart';
import '../models/fitness_recommendation.dart';
import '../models/user.dart';
import '../screens/fitness_profile_screen.dart';
import '../theme/app_theme.dart';

class AIAdvisorCard extends StatelessWidget {
  final User user;
  final FitnessProfile? profile;
  final FitnessRecommendation? recommendation;
  final Map<String, dynamic>? dangerCheckResult;
  final bool isDangerLoading;
  final VoidCallback? onViewPlan;

  const AIAdvisorCard({
    super.key,
    required this.user,
    required this.profile,
    required this.recommendation,
    required this.dangerCheckResult,
    this.isDangerLoading = false,
    this.onViewPlan,
  });

  @override
  Widget build(BuildContext context) {
    if (profile != null && recommendation != null) {
      return Card(
        elevation: 2,
        color:
            Theme.of(context).brightness == Brightness.dark
                ? AppTheme.aiCardBackgroundDark
                : AppTheme.aiCardBackgroundLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDangerLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 8),
                      CircularProgressIndicator(strokeWidth: 2),
                      SizedBox(width: 12),
                      Text('Checking plan safety...'),
                    ],
                  ),
                ),
              if (dangerCheckResult != null &&
                  dangerCheckResult!['danger'] == true)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color:
                      Theme.of(
                        context,
                      ).extension<ThemeColors>()?.warningBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color:
                                  Theme.of(
                                    context,
                                  ).extension<ThemeColors>()?.warningColor,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Warning',
                              style: TextStyle(
                                color:
                                    Theme.of(
                                      context,
                                    ).extension<ThemeColors>()?.warningColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your current plan may be unsafe or unrealistic.',
                          style: TextStyle(
                            color:
                                Theme.of(
                                  context,
                                ).extension<ThemeColors>()?.warningColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dangerCheckResult!['reason'],
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white70
                                    : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                children: [
                  Icon(
                    Icons.psychology,
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? AppTheme.aiCardAccentDark
                            : AppTheme.aiCardAccentLight,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Fitness Plan',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color:
                            Theme.of(context).brightness == Brightness.dark
                                ? AppTheme.aiCardAccentDark
                                : AppTheme.aiCardAccentLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (recommendation!.isCustomized)
                    Icon(
                      Icons.edit,
                      size: 16,
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.orangeAccent
                              : Colors.orange,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Goal: ${profile!.goalDescription}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Weekly: ${recommendation!.sessionDurationMinutes}min × ${recommendation!.workoutSessionsPerWeek} sessions',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black54,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: onViewPlan,
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Plan'),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.aiCardAccentDark
                              : AppTheme.aiCardAccentLight,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => FitnessProfileScreen(user: user),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit Profile'),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.aiCardAccentDark
                              : AppTheme.aiCardAccentLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      // Suggest setting up AI recommendations
      return Card(
        elevation: 2,
        color:
            Theme.of(context).brightness == Brightness.dark
                ? Color(0xFF1A2720) // Dark green background
                : Color(0xFFE8F5E9), // Light green background
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Color(0xFF81C784) // Lighter green for dark mode
                            : Color(0xFF2E7D32), // Darker green for light mode
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Get Personalized AI Recommendations',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color:
                            Theme.of(context).brightness == Brightness.dark
                                ? Color(
                                  0xFF81C784,
                                ) // Lighter green for dark mode
                                : Color(
                                  0xFF2E7D32,
                                ), // Darker green for light mode
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Let AI create a personalized fitness plan based on your goals, age, and activity level.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FitnessProfileScreen(user: user),
                    ),
                  );
                },
                icon: const Icon(Icons.psychology),
                label: const Text('Set Up AI Coach'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? Color(0xFF66BB6A) // Lighter green for dark mode
                          : Color(0xFF2E7D32), // Darker green for light mode
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}

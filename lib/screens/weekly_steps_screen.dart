import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/step_data.dart';
import '../services/step_counter_service.dart';
import '../services/units_service.dart';

class WeeklyStepsScreen extends StatefulWidget {
  const WeeklyStepsScreen({super.key});

  @override
  State<WeeklyStepsScreen> createState() => _WeeklyStepsScreenState();
}

class _WeeklyStepsScreenState extends State<WeeklyStepsScreen> {
  final StepCounterService _stepService = StepCounterService();
  final UnitsService _unitsService = UnitsService();
  List<StepData> _weeklyData = [];
  bool _isLoading = true;
  Map<String, dynamic>? _weeklyComparison;
  StepData? _selectedDayData;

  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
    _unitsService.unitSystem.addListener(_onUnitsUpdate);
  }

  void _onUnitsUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _unitsService.unitSystem.removeListener(_onUnitsUpdate);
    super.dispose();
  }

  Future<void> _loadWeeklyData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final comparison = await _stepService.getWeeklyComparison();
      setState(() {
        _weeklyComparison = comparison;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading weekly data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Steps'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWeeklyData,
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _weeklyComparison == null
              ? const Center(child: Text('No data available'))
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWeeklySummaryCard(),
                    const SizedBox(height: 20),
                    _buildCurrentWeekChart(),
                    const SizedBox(height: 20),
                    _buildComparisonCard(),
                  ],
                ),
              ),
    );
  }

  Widget _buildWeeklySummaryCard() {
    final currentWeekTotal = _weeklyComparison!['currentWeekTotal'] as int;
    final currentWeekData =
        _weeklyComparison!['currentWeekData'] as List<StepData>;
    final previousWeekData =
        _weeklyComparison!['previousWeekData'] as List<StepData>;
    final percentageChange = _weeklyComparison!['percentageChange'] as double;
    final isIncrease = percentageChange >= 0;

    // Calculate total calories and distance for current week
    final currentWeekCalories = currentWeekData.fold(
      0.0,
      (sum, data) => sum + data.calories,
    );
    final currentWeekDistance = currentWeekData.fold(
      0.0,
      (sum, data) => sum + data.distance,
    );
    final previousWeekCalories = previousWeekData.fold(
      0.0,
      (sum, data) => sum + data.calories,
    );

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This Week Summary',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(FontAwesomeIcons.personWalking, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '$currentWeekTotal steps',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(FontAwesomeIcons.fire, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '${currentWeekCalories.toStringAsFixed(0)} cal',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(FontAwesomeIcons.route, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            _unitsService.formatDistance(currentWeekDistance),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Icon(
                      isIncrease ? Icons.trending_up : Icons.trending_down,
                      color: isIncrease ? Colors.green : Colors.red,
                      size: 40,
                    ),
                    Text(
                      '${percentageChange.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: isIncrease ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'vs last week',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentWeekChart() {
    final currentWeekData =
        _weeklyComparison!['currentWeekData'] as List<StepData>;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This Week Progress',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            if (currentWeekData.isEmpty)
              const Center(child: Text('No data for this week yet'))
            else
              _buildBarChart(currentWeekData),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(List<StepData> data) {
    final maxSteps = data.fold(
      0,
      (max, stepData) => stepData.steps > max ? stepData.steps : max,
    );

    return SizedBox(
      height: 200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children:
            _getDaysOfWeek().map((day) {
              final stepData = data.firstWhere(
                (d) => d.dayOfWeek == day,
                orElse:
                    () => StepData(
                      date: DateTime.now(),
                      steps: 0,
                      timestamp: DateTime.now(),
                    ),
              );

              final height =
                  maxSteps > 0 ? (stepData.steps / maxSteps) * 150 : 0.0;

              return GestureDetector(
                onTap: () => _showDayDetails(context, stepData, day),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      stepData.steps.toString(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 30,
                      height: height,
                      decoration: BoxDecoration(
                        color:
                            stepData.isToday
                                ? Theme.of(context).primaryColor
                                : Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      day.substring(0, 3),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildComparisonCard() {
    final currentWeekData =
        _weeklyComparison!['currentWeekData'] as List<StepData>;
    final previousWeekData =
        _weeklyComparison!['previousWeekData'] as List<StepData>;
    final currentWeekTotal = _weeklyComparison!['currentWeekTotal'] as int;
    final previousWeekTotal = _weeklyComparison!['previousWeekTotal'] as int;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Week Comparison',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildWeekSummary(
                    'This Week',
                    currentWeekTotal,
                    currentWeekData.length,
                    Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildWeekSummary(
                    'Last Week',
                    previousWeekTotal,
                    previousWeekData.length,
                    Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDailyComparison(currentWeekData, previousWeekData),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekSummary(
    String title,
    int totalSteps,
    int daysWithData,
    Color color,
  ) {
    final averageSteps = daysWithData > 0 ? totalSteps / daysWithData : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$totalSteps',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text('total steps', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            '${averageSteps.toStringAsFixed(0)} avg/day',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildDailyComparison(
    List<StepData> currentWeek,
    List<StepData> previousWeek,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Daily Breakdown', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        ..._getDaysOfWeek().map((day) {
          final currentSteps =
              currentWeek
                  .firstWhere(
                    (d) => d.dayOfWeek == day,
                    orElse:
                        () => StepData(
                          date: DateTime.now(),
                          steps: 0,
                          timestamp: DateTime.now(),
                        ),
                  )
                  .steps;
          final previousSteps =
              previousWeek
                  .firstWhere(
                    (d) => d.dayOfWeek == day,
                    orElse:
                        () => StepData(
                          date: DateTime.now(),
                          steps: 0,
                          timestamp: DateTime.now(),
                        ),
                  )
                  .steps;

          final difference = currentSteps - previousSteps;
          final isIncrease = difference >= 0;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    day,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        '$currentSteps',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (previousSteps > 0) ...[
                        Icon(
                          isIncrease
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 16,
                          color: isIncrease ? Colors.green : Colors.red,
                        ),
                        Text(
                          '${difference.abs()}',
                          style: TextStyle(
                            color: isIncrease ? Colors.green : Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  void _showDayDetails(
    BuildContext context,
    StepData stepData,
    String dayName,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      stepData.isToday ? Icons.today : Icons.calendar_today,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      stepData.isToday ? 'Today ($dayName)' : dayName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailRow(
                  context,
                  FontAwesomeIcons.personWalking,
                  'Steps',
                  '${stepData.steps}',
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  context,
                  FontAwesomeIcons.fire,
                  'Calories Burned',
                  '${stepData.calories.toStringAsFixed(1)} cal',
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  context,
                  FontAwesomeIcons.route,
                  'Distance',
                  _unitsService.formatDistance(stepData.distance),
                ),
                if (stepData.steps > 0) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Based on your height and weight, each step burns approximately ${(stepData.calories / stepData.steps).toStringAsFixed(3)} calories.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  List<String> _getDaysOfWeek() {
    return [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
  }
}

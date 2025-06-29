import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/step_data.dart';
import '../models/user.dart';
import '../models/fitness_profile.dart';
import 'notification_service.dart';
import 'ai_fitness_advisor_service.dart';

class StepCounterService extends ChangeNotifier {
  static final StepCounterService _instance = StepCounterService._internal();
  factory StepCounterService() => _instance;
  StepCounterService._internal();

  late Stream<StepCount> _stepCountStream;
  StreamSubscription<StepCount>? _subscription;
  Database? _database;

  int _currentSteps = 0;
  int _todayStartSteps = 0;
  DateTime _lastResetDate = DateTime.now();
  bool _isInitialized = false;
  bool _hasPermission = false;
  User? _currentUser;
  final NotificationService _notificationService = NotificationService();
  final AIFitnessAdvisorService _aiService = AIFitnessAdvisorService();

  // Getters
  int get currentSteps => _currentSteps - _todayStartSteps;
  bool get isInitialized => _isInitialized;
  bool get hasPermission => _hasPermission;
  DateTime get lastResetDate => _lastResetDate;

  // Calculate current calories burned based on steps
  double get currentCalories {
    return _calculateCaloriesFromSteps(currentSteps);
  }

  // Calculate current distance walked
  double get currentDistance {
    return _calculateDistanceFromSteps(currentSteps);
  }

  // Calculate calories from steps using AI profile if available, otherwise User model
  double _calculateCaloriesFromSteps(int steps) {
    final aiProfile = _aiService.currentProfile;
    if (aiProfile != null) {
      // Use AI profile data for more accurate calculation
      final strideLength = aiProfile.height * 0.43; // cm
      final distanceMeters = (steps * strideLength) / 100; // meters
      final distanceKm = distanceMeters / 1000; // km
      // Calories = Distance (km) × Weight (kg) × 0.57
      return distanceKm * aiProfile.weight * 0.57;
    } else if (_currentUser != null) {
      // Fall back to User model calculation
      return _currentUser!.calculateCaloriesFromSteps(steps);
    }
    return 0.0;
  }

  // Calculate distance from steps using AI profile if available, otherwise User model
  double _calculateDistanceFromSteps(int steps) {
    final aiProfile = _aiService.currentProfile;
    if (aiProfile != null) {
      // Use AI profile data for more accurate calculation
      final strideLength = aiProfile.height * 0.43; // cm
      final distanceMeters = (steps * strideLength) / 100; // meters
      return distanceMeters / 1000; // km
    } else if (_currentUser != null) {
      // Fall back to User model calculation
      return _currentUser!.calculateDistanceFromSteps(steps);
    }
    return 0.0;
  }

  // Set current user for calorie calculations
  void setUser(User user) {
    _currentUser = user;
    notifyListeners();
    // Update notification with new user data
    _updateNotification();
  }

  // Update notification with current step data
  void _updateNotification() {
    if (!_notificationService.canShowNotifications) {
      return;
    }

    // Get daily goal from AI recommendation if available, otherwise from user goal
    int dailyGoal = 10000; // default

    final aiRecommendation = _aiService.currentRecommendation;
    if (aiRecommendation != null) {
      dailyGoal = aiRecommendation.dailyStepsTarget;
    } else if (_currentUser != null) {
      // Extract daily goal from user's goal string
      final goalString = _currentUser!.goal;
      final goalMatch = RegExp(
        r'(\d{1,3}(?:,\d{3})*|\d+)',
      ).firstMatch(goalString);
      dailyGoal =
          goalMatch != null
              ? int.parse(goalMatch.group(1)!.replaceAll(',', ''))
              : 10000;
    }

    _notificationService.showStepNotification(
      steps: currentSteps,
      calories: currentCalories,
      distance: currentDistance,
      dailyGoal: dailyGoal,
    );
  }

  // Initialize the service
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await _initDatabase();
      await _requestPermissions();
      await _notificationService.init();
      if (_hasPermission) {
        await _loadTodayData();
        await _initStepCounter();
        await _checkAndResetDaily();
      }
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing step counter: $e');
    }
  }

  // Request necessary permissions
  Future<void> _requestPermissions() async {
    try {
      final status = await Permission.activityRecognition.request();
      _hasPermission = status.isGranted;

      if (!_hasPermission) {
        debugPrint('Activity recognition permission denied');
      }
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      _hasPermission = false;
    }
  }

  // Initialize database
  Future<void> _initDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'steps.db');

      _database = await openDatabase(
        path,
        version: 2,
        onCreate: (db, version) {
          return db.execute(
            'CREATE TABLE step_data(id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT UNIQUE, steps INTEGER, calories REAL, distance REAL, timestamp TEXT)',
          );
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            // Add new columns for existing databases
            await db.execute(
              'ALTER TABLE step_data ADD COLUMN calories REAL DEFAULT 0.0',
            );
            await db.execute(
              'ALTER TABLE step_data ADD COLUMN distance REAL DEFAULT 0.0',
            );
          }
        },
      );
    } catch (e) {
      debugPrint('Error initializing database: $e');
    }
  }

  // Initialize step counter stream
  Future<void> _initStepCounter() async {
    try {
      _stepCountStream = Pedometer.stepCountStream;
      _subscription = _stepCountStream.listen(
        _onStepCount,
        onError: _onStepCountError,
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Error initializing step counter: $e');
    }
  }

  // Handle step count updates
  void _onStepCount(StepCount event) {
    final now = DateTime.now();

    // Check if we need to reset for a new day
    if (_shouldResetForNewDay(now)) {
      _resetForNewDay(now);
    }

    _currentSteps = event.steps;
    notifyListeners();

    // Save current progress
    _saveTodayData();

    // Update notification if enabled and user is set
    _updateNotification();
  }

  // Handle step count errors
  void _onStepCountError(error) {
    debugPrint('Step count error: $error');
  }

  // Check if we should reset for a new day
  bool _shouldResetForNewDay(DateTime now) {
    return now.day != _lastResetDate.day ||
        now.month != _lastResetDate.month ||
        now.year != _lastResetDate.year;
  }

  // Reset for a new day
  void _resetForNewDay(DateTime now) async {
    // Save yesterday's final count if we have data
    if (_currentSteps > _todayStartSteps) {
      final yesterdaySteps = _currentSteps - _todayStartSteps;
      final calories = _calculateCaloriesFromSteps(yesterdaySteps);
      final distance = _calculateDistanceFromSteps(yesterdaySteps);

      await _saveStepData(
        StepData(
          date: _lastResetDate,
          steps: yesterdaySteps,
          calories: calories,
          distance: distance,
          timestamp: now,
        ),
      );
    }

    // Reset for new day
    _todayStartSteps = _currentSteps;
    _lastResetDate = now;
    await _saveTodayData();
  }

  // Check and reset daily (called on app start)
  Future<void> _checkAndResetDaily() async {
    final now = DateTime.now();
    if (_shouldResetForNewDay(now)) {
      _resetForNewDay(now);
    }
  }

  // Load today's data from storage
  Future<void> _loadTodayData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _todayStartSteps = prefs.getInt('today_start_steps') ?? 0;

      final lastResetString = prefs.getString('last_reset_date');
      if (lastResetString != null) {
        _lastResetDate = DateTime.parse(lastResetString);
      }
    } catch (e) {
      debugPrint('Error loading today data: $e');
    }
  }

  // Save today's data to storage
  Future<void> _saveTodayData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('today_start_steps', _todayStartSteps);
      await prefs.setString(
        'last_reset_date',
        _lastResetDate.toIso8601String(),
      );
    } catch (e) {
      debugPrint('Error saving today data: $e');
    }
  }

  // Save step data to database
  Future<void> _saveStepData(StepData stepData) async {
    if (_database == null) return;

    try {
      await _database!.insert(
        'step_data',
        stepData.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('Error saving step data: $e');
    }
  }

  // Get step data for a specific date
  Future<StepData?> getStepDataForDate(DateTime date) async {
    if (_database == null) return null;

    try {
      final dateString = date.toIso8601String().substring(0, 10);
      final List<Map<String, dynamic>> maps = await _database!.query(
        'step_data',
        where: 'date = ?',
        whereArgs: [dateString],
      );

      if (maps.isNotEmpty) {
        return StepData.fromMap(maps.first);
      }
    } catch (e) {
      debugPrint('Error getting step data for date: $e');
    }
    return null;
  }

  // Get weekly step data (last 7 days)
  Future<List<StepData>> getWeeklyStepData() async {
    if (_database == null) return [];

    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final weekAgoString = weekAgo.toIso8601String().substring(0, 10);

      final List<Map<String, dynamic>> maps = await _database!.query(
        'step_data',
        where: 'date >= ?',
        whereArgs: [weekAgoString],
        orderBy: 'date ASC',
      );

      return maps.map((map) => StepData.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error getting weekly step data: $e');
      return [];
    }
  }

  // Get step data for the current week (Monday to Sunday)
  Future<List<StepData>> getCurrentWeekStepData() async {
    if (_database == null) return [];

    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeekString = startOfWeek.toIso8601String().substring(0, 10);

      final List<Map<String, dynamic>> maps = await _database!.query(
        'step_data',
        where: 'date >= ?',
        whereArgs: [startOfWeekString],
        orderBy: 'date ASC',
      );

      final stepDataList = maps.map((map) => StepData.fromMap(map)).toList();

      // Add today's data if not already in the list
      final today = DateTime.now();
      final todayExists = stepDataList.any((data) => data.isToday);

      if (!todayExists && currentSteps > 0) {
        final todayCalories = _calculateCaloriesFromSteps(currentSteps);
        final todayDistance = _calculateDistanceFromSteps(currentSteps);

        stepDataList.add(
          StepData(
            date: today,
            steps: currentSteps,
            calories: todayCalories,
            distance: todayDistance,
            timestamp: today,
          ),
        );
      }

      return stepDataList;
    } catch (e) {
      debugPrint('Error getting current week step data: $e');
      return [];
    }
  }

  // Calculate weekly average
  Future<double> getWeeklyAverage() async {
    final weeklyData = await getWeeklyStepData();
    if (weeklyData.isEmpty) return 0.0;

    final totalSteps = weeklyData.fold(0, (sum, data) => sum + data.steps);
    return totalSteps / weeklyData.length;
  }

  // Get weekly comparison (current week vs previous week)
  Future<Map<String, dynamic>> getWeeklyComparison() async {
    final currentWeekData = await getCurrentWeekStepData();

    // Get previous week data
    final now = DateTime.now();
    final startOfLastWeek = now.subtract(Duration(days: now.weekday + 6));
    final endOfLastWeek = now.subtract(Duration(days: now.weekday));

    final startOfLastWeekString = startOfLastWeek.toIso8601String().substring(
      0,
      10,
    );
    final endOfLastWeekString = endOfLastWeek.toIso8601String().substring(
      0,
      10,
    );

    if (_database == null) {
      return {
        'currentWeekTotal': 0,
        'previousWeekTotal': 0,
        'percentageChange': 0.0,
        'currentWeekData': <StepData>[],
        'previousWeekData': <StepData>[],
      };
    }

    try {
      final List<Map<String, dynamic>> lastWeekMaps = await _database!.query(
        'step_data',
        where: 'date >= ? AND date <= ?',
        whereArgs: [startOfLastWeekString, endOfLastWeekString],
        orderBy: 'date ASC',
      );

      final previousWeekData =
          lastWeekMaps.map((map) => StepData.fromMap(map)).toList();

      final currentWeekTotal = currentWeekData.fold(
        0,
        (sum, data) => sum + data.steps,
      );
      final previousWeekTotal = previousWeekData.fold(
        0,
        (sum, data) => sum + data.steps,
      );

      double percentageChange = 0.0;
      if (previousWeekTotal > 0) {
        percentageChange =
            ((currentWeekTotal - previousWeekTotal) / previousWeekTotal) * 100;
      }

      return {
        'currentWeekTotal': currentWeekTotal,
        'previousWeekTotal': previousWeekTotal,
        'percentageChange': percentageChange,
        'currentWeekData': currentWeekData,
        'previousWeekData': previousWeekData,
      };
    } catch (e) {
      debugPrint('Error getting weekly comparison: $e');
      return {
        'currentWeekTotal': 0,
        'previousWeekTotal': 0,
        'percentageChange': 0.0,
        'currentWeekData': <StepData>[],
        'previousWeekData': <StepData>[],
      };
    }
  }

  // Toggle notifications on/off
  Future<void> toggleNotifications(bool enabled) async {
    await _notificationService.toggleNotifications(enabled);
    if (enabled) {
      _updateNotification();
    }
  }

  // Get notification status
  bool get notificationsEnabled => _notificationService.notificationsEnabled;
  bool get notificationPermission => _notificationService.hasPermission;

  // Request notification permission
  Future<bool> requestNotificationPermission() async {
    return await _notificationService.requestPermissionAgain();
  }

  // Manually reset steps (for testing or manual reset)
  Future<void> manualReset() async {
    _todayStartSteps = _currentSteps;
    _lastResetDate = DateTime.now();
    await _saveTodayData();
    notifyListeners();
    _updateNotification();
  }

  // Dispose of resources
  @override
  void dispose() {
    _subscription?.cancel();
    _database?.close();
    _notificationService.dispose();
    super.dispose();
  }
}

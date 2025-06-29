import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  bool _notificationsEnabled = true;
  bool _hasPermission = false;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get hasPermission => _hasPermission;

  // Notification channel constants
  static const String _channelId = 'step_counter_channel';
  static const String _channelName = 'Step Counter';
  static const String _channelDescription =
      'Persistent step counter notifications';
  static const int _notificationId = 1001;

  // Initialize notification service
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await _loadSettings();
      await _requestPermissions();
      await _initializeNotifications();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing notification service: $e');
    }
  }

  // Load notification settings
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
    }
  }

  // Save notification settings
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', _notificationsEnabled);
    } catch (e) {
      debugPrint('Error saving notification settings: $e');
    }
  }

  // Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      // Request notification permission
      final notificationStatus = await Permission.notification.request();
      _hasPermission = notificationStatus.isGranted;

      if (!_hasPermission) {
        debugPrint('Notification permission denied');
        return;
      }

      // For Android 13+ (API level 33+), request POST_NOTIFICATIONS permission
      if (await Permission.notification.isPermanentlyDenied) {
        debugPrint('Notification permission permanently denied');
        return;
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
      _hasPermission = false;
    }
  }

  // Initialize notifications
  Future<void> _initializeNotifications() async {
    if (!_hasPermission) return;

    try {
      // Android initialization
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: false,
          );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channel for Android
      await _createNotificationChannel();
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  // Create notification channel for Android
  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.low,
      enableLights: false,
      enableVibration: false,
      playSound: false,
      showBadge: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - could navigate to app or specific screen
    debugPrint('Notification tapped: ${response.payload}');
  }

  // Show persistent step notification
  Future<void> showStepNotification({
    required int steps,
    required double calories,
    required double distance,
    required int dailyGoal,
  }) async {
    if (!_isInitialized || !_hasPermission || !_notificationsEnabled) return;

    try {
      final progress = steps / dailyGoal;
      final progressPercentage = (progress * 100).clamp(0, 100).toInt();

      // Create progress text
      String progressText = '';
      if (progress >= 1.0) {
        progressText = '🎉 Goal achieved!';
      } else {
        final remaining = dailyGoal - steps;
        progressText = '$remaining steps to goal';
      }

      final AndroidNotificationDetails
      androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true, // Makes notification persistent
        autoCancel: false,
        showWhen: false,
        enableLights: false,
        enableVibration: false,
        playSound: false,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(
          '$steps steps • ${calories.toStringAsFixed(0)} cal • ${distance.toStringAsFixed(1)} km\n$progressText',
          htmlFormatBigText: false,
          contentTitle: 'FitLite - Step Counter',
          htmlFormatContentTitle: false,
          summaryText: '$progressPercentage% of daily goal',
          htmlFormatSummaryText: false,
        ),
      );

      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: true,
        presentSound: false,
        badgeNumber: steps,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        _notificationId,
        'FitLite - Step Counter',
        '$steps steps • ${calories.toStringAsFixed(0)} cal • ${distance.toStringAsFixed(1)} km',
        details,
        payload: 'step_notification',
      );
    } catch (e) {
      debugPrint('Error showing step notification: $e');
    }
  }

  // Hide step notification
  Future<void> hideStepNotification() async {
    try {
      await _notifications.cancel(_notificationId);
    } catch (e) {
      debugPrint('Error hiding step notification: $e');
    }
  }

  // Toggle notifications on/off
  Future<void> toggleNotifications(bool enabled) async {
    _notificationsEnabled = enabled;
    await _saveSettings();

    if (!enabled) {
      await hideStepNotification();
    }

    notifyListeners();
  }

  // Check if notifications are enabled and permission is granted
  bool get canShowNotifications => _hasPermission && _notificationsEnabled;

  // Request permission again if denied
  Future<bool> requestPermissionAgain() async {
    await _requestPermissions();
    return _hasPermission;
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _notifications.cancelAll();
    } catch (e) {
      debugPrint('Error canceling all notifications: $e');
    }
  }

  // Dispose
  @override
  void dispose() {
    cancelAllNotifications();
    super.dispose();
  }
}

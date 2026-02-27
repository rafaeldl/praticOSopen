import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/fcm_token.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

/// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages if needed
  debugPrint('[NotificationService] Background message: ${message.messageId}');
}

/// Service for managing push notifications via Firebase Cloud Messaging
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  bool _isInitialized = false;
  String? _currentToken;
  String? _deviceId;

  /// Android notification channel ID
  static const String _channelId = 'orders_channel';
  static const String _channelName = 'Ordens de Serviço';
  static const String _channelDescription =
      'Notificações sobre ordens de serviço';

  /// Reminders notification channel
  static const String _remindersChannelId = 'reminders_channel';
  static const String _remindersChannelName = 'Lembretes';
  static const String _remindersChannelDescription =
      'Lembretes de agendamento';

  /// Callback for handling notification taps - set this from your app
  void Function(String? orderId, String? companyId)? onNotificationTap;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize timezone data
    tz_data.initializeTimeZones();

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Initialize local notifications for foreground display
    await _initializeLocalNotifications();

    // Create Android notification channel
    await _createNotificationChannel();

    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    // Check if app was opened from a terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationOpen(initialMessage);
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_handleTokenRefresh);

    // Get device ID
    _deviceId = await _getDeviceId();

    _isInitialized = true;
    debugPrint('[NotificationService] Initialized');
  }

  /// Request notification permissions (required for iOS)
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    debugPrint('[NotificationService] Permission granted: $granted');
    return granted;
  }

  /// Register FCM token for the current user
  Future<void> registerToken(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('[NotificationService] Failed to get FCM token');
        return;
      }

      _currentToken = token;

      final String platform;
      if (kIsWeb) {
        platform = 'web';
      } else {
        platform = Platform.isIOS ? 'ios' : 'android';
      }

      final fcmToken = FcmToken(
        token: token,
        deviceId: _deviceId,
        platform: platform,
        createdAt: DateTime.now(),
        lastUsedAt: DateTime.now(),
      );

      // Update user document with token
      await _updateUserToken(userId, fcmToken);

      debugPrint('[NotificationService] Token registered for user $userId');
    } catch (e) {
      debugPrint('[NotificationService] Error registering token: $e');
    }
  }

  /// Remove FCM token when user logs out
  Future<void> unregisterToken(String userId) async {
    try {
      if (_currentToken == null || _deviceId == null) return;

      // Remove token from user document
      final userRef = _db.collection('users').doc(userId);
      final userDoc = await userRef.get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        final fcmTokens = userData?['fcmTokens'] as List<dynamic>? ?? [];

        // Filter out current device's token
        final updatedTokens = fcmTokens
            .where((t) => t['deviceId'] != _deviceId)
            .toList();

        await userRef.update({'fcmTokens': updatedTokens});
      }

      _currentToken = null;
      debugPrint('[NotificationService] Token unregistered for user $userId');
    } catch (e) {
      debugPrint('[NotificationService] Error unregistering token: $e');
    }
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
  }

  /// Create Android notification channel
  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Reminders channel
    const remindersChannel = AndroidNotificationChannel(
      _remindersChannelId,
      _remindersChannelName,
      description: _remindersChannelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(remindersChannel);
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[NotificationService] Foreground message: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    // Show local notification when app is in foreground
    await _localNotifications.show(
      id: message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: _encodePayload(message.data),
    );
  }

  /// Handle notification tap when app is opened from background
  void _handleNotificationOpen(RemoteMessage message) {
    debugPrint('[NotificationService] Notification opened: ${message.data}');

    final orderId = message.data['orderId'] as String?;
    final companyId = message.data['companyId'] as String?;

    if (onNotificationTap != null) {
      onNotificationTap!(orderId, companyId);
    }
  }

  /// Handle local notification tap
  void _onNotificationResponse(NotificationResponse response) {
    debugPrint('[NotificationService] Local notification tapped: ${response.payload}');

    final data = _decodePayload(response.payload);
    final orderId = data['orderId'] as String?;
    final companyId = data['companyId'] as String?;

    if (onNotificationTap != null) {
      onNotificationTap!(orderId, companyId);
    }
  }

  /// Handle token refresh
  Future<void> _handleTokenRefresh(String newToken) async {
    debugPrint('[NotificationService] Token refreshed');

    final userId = Global.userAggr?.id;
    if (userId != null) {
      _currentToken = newToken;

      final String platform;
      if (kIsWeb) {
        platform = 'web';
      } else {
        platform = Platform.isIOS ? 'ios' : 'android';
      }

      final fcmToken = FcmToken(
        token: newToken,
        deviceId: _deviceId,
        platform: platform,
        createdAt: DateTime.now(),
        lastUsedAt: DateTime.now(),
      );

      await _updateUserToken(userId, fcmToken);
    }
  }

  /// Update user document with FCM token
  Future<void> _updateUserToken(String userId, FcmToken fcmToken) async {
    final userRef = _db.collection('users').doc(userId);
    final userDoc = await userRef.get();

    if (!userDoc.exists) {
      debugPrint('[NotificationService] User document not found: $userId');
      return;
    }

    final userData = userDoc.data();
    final fcmTokens = (userData?['fcmTokens'] as List<dynamic>?)
            ?.map((t) => FcmToken.fromJson(Map<String, dynamic>.from(t)))
            .toList() ??
        [];

    // Remove existing token for this device
    fcmTokens.removeWhere((t) => t.deviceId == fcmToken.deviceId);

    // Add new token
    fcmTokens.add(fcmToken);

    // Update user document
    await userRef.update({
      'fcmTokens': fcmTokens.map((t) => t.toJson()).toList(),
    });
  }

  /// Get unique device identifier
  Future<String> _getDeviceId() async {
    if (kIsWeb) return 'web_device';
    try {
      if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown_ios';
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.id;
      }
    } catch (e) {
      debugPrint('[NotificationService] Error getting device ID: $e');
    }
    return 'unknown_device';
  }

  /// Schedule a local reminder notification for an order
  Future<void> scheduleOrderReminder({
    required String orderId,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required int minutesBefore,
    String? companyId,
  }) async {
    if (minutesBefore <= 0) return;

    final reminderTime = scheduledDate.subtract(Duration(minutes: minutesBefore));
    if (reminderTime.isBefore(DateTime.now())) return;

    final notificationId = orderId.hashCode.abs() % 2147483647;
    final tzReminderTime = tz.TZDateTime.from(reminderTime, tz.local);

    final payload = 'orderId=$orderId${companyId != null ? '&companyId=$companyId' : ''}';

    await _localNotifications.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: tzReminderTime,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _remindersChannelId,
          _remindersChannelName,
          channelDescription: _remindersChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );

    debugPrint('[NotificationService] Scheduled reminder for order $orderId at $reminderTime');
  }

  /// Cancel a previously scheduled reminder for an order
  Future<void> cancelOrderReminder(String orderId) async {
    final notificationId = orderId.hashCode.abs() % 2147483647;
    await _localNotifications.cancel(id: notificationId);
    debugPrint('[NotificationService] Cancelled reminder for order $orderId');
  }

  /// Encode notification data to payload string
  String _encodePayload(Map<String, dynamic> data) {
    return data.entries.map((e) => '${e.key}=${e.value}').join('&');
  }

  /// Decode payload string to map
  Map<String, dynamic> _decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return {};

    final map = <String, dynamic>{};
    for (final part in payload.split('&')) {
      final keyValue = part.split('=');
      if (keyValue.length == 2) {
        map[keyValue[0]] = keyValue[1];
      }
    }
    return map;
  }
}

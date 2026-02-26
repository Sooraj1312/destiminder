import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    
    const AndroidInitializationSettings androidSettings = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings = 
        DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
    
    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'background_monitor',
      'Background Monitoring',
      description: 'Notifications when you arrive at destinations',
      importance: Importance.high,
    );

    final AndroidFlutterLocalNotificationsPlugin? android =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await android?.createNotificationChannel(channel);
    
    _initialized = true;
  }

  Future<void> showArrivalNotification(String placeName) async {
    await initialize();
    
    const AndroidNotificationDetails androidDetails = 
        AndroidNotificationDetails(
      'arrival_channel',
      'Arrival Notifications',
      channelDescription: 'When you reach your destination',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      0,
      '🎯 Destination Reached!',
      'You have arrived at $placeName',
      details,
    );
  }

  Future<void> showBackgroundNotification(String placeName) async {
    await initialize();
    
    const AndroidNotificationDetails androidDetails = 
        AndroidNotificationDetails(
      'background_monitor',
      'Background Monitoring',
      channelDescription: 'Background arrival notification',
      importance: Importance.high,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecond,
      '📍 DestiMinder Alert',
      'You are near $placeName',
      details,
    );
  }

  Future<void> showTrackingNotification(String placeName) async {
    await initialize();
    
    const AndroidNotificationDetails androidDetails = 
        AndroidNotificationDetails(
      'tracking_channel',
      'Tracking Active',
      channelDescription: 'Monitoring your arrival',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1,
      '📍 Tracking Active',
      'Heading to $placeName...',
      details,
    );
  }

  Future<void> cancelTracking() async {
    await _notifications.cancel(1);
  }
}
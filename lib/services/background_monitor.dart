import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/destination.dart';
import 'history_service.dart';
import 'notification_service.dart';

class BackgroundMonitor {
  static const String TAG = "DestiMinder-BG";
  static bool _isRunning = false;
  static Timer? _timer;
  
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();
    
    await service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true, // Auto-start on device boot
        isForegroundMode: true,
        autoStartOnBoot: true, // Start after phone restart
        notificationChannelId: 'background_monitor',
        initialNotificationTitle: 'DestiMinder',
        initialNotificationContent: 'Monitoring your destinations',
        foregroundServiceNotificationId: 999,
      ),
    );
    
    // Check if we should auto-start monitoring
    final prefs = await SharedPreferences.getInstance();
    final shouldMonitor = prefs.getBool('background_monitoring') ?? false;
    if (shouldMonitor) {
      startMonitoring();
    }
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Initialize notification service
    final notificationService = NotificationService();
    await notificationService.initialize();
    
    // Show persistent notification
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
    }

    // Listen for stop event
    service.on('stopService').listen((event) {
      _timer?.cancel();
      if (service is AndroidServiceInstance) {
        service.stopSelf(); // Only AndroidServiceInstance has stopSelf
      }
    });

    // Start monitoring immediately and then every 10 seconds
    _checkDestinations(); // Check immediately on start
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkDestinations();
    });
  }

  @pragma('vm:entry-point')
  static Future<void> _checkDestinations() async {
    try {
      print('$TAG Checking destinations...');
      
      final prefs = await SharedPreferences.getInstance();
      final String? destinationsJson = prefs.getString('destinations');
      
      if (destinationsJson == null) {
        print('$TAG No destinations found');
        return;
      }

      final List<dynamic> decoded = jsonDecode(destinationsJson);
      final destinations = decoded
          .map((item) => Destination.fromJson(item))
          .where((d) => d.isActive)
          .toList();

      if (destinations.isEmpty) {
        print('$TAG No active destinations');
        return;
      }

      // Get current location with high accuracy
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('$TAG Location services disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        print('$TAG No location permission');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print('$TAG Current position: ${position.latitude}, ${position.longitude}');

      for (var destination in destinations) {
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          destination.latitude,
          destination.longitude,
        );

        print('$TAG Distance to ${destination.displayName}: ${distance}m');

        if (distance <= destination.radius) {
          print('$TAG ARRIVED at ${destination.displayName}!');
          
          // Record in history
          final historyService = HistoryService();
          await historyService.addArrival(destination);
          
          // Strong vibration for vehicle
          try {
            bool? hasVibrator = await Vibration.hasVibrator();
            if (hasVibrator == true) {
              // Long strong vibration for vehicle
              await Vibration.vibrate(pattern: [3000, 500, 3000, 500, 3000]);
            }
          } catch (e) {
            print('Vibration error: $e');
          }
          
          // Voice announcement (louder for vehicle)
          if (destination.voiceEnabled) {
            try {
              final tts = FlutterTts();
              await tts.setLanguage("en-US");
              await tts.setSpeechRate(0.4); // Slower for clarity
              await tts.setVolume(1.0); // Max volume
              await tts.speak("You have arrived at ${destination.displayName}");
            } catch (e) {
              print('TTS Error: $e');
            }
          }
          
          // Show notification
          final notificationService = NotificationService();
          await notificationService.initialize();
          await notificationService.showBackgroundNotification(destination.displayName);
        }
      }
    } catch (e) {
      print('$TAG Error: $e');
    }
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }

  static Future<void> startMonitoring() async {
    if (_isRunning) {
      print('$TAG Already running');
      return;
    }
    
    print('$TAG Starting background monitoring...');
    
    // Save state
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('background_monitoring', true);
    
    final service = FlutterBackgroundService();
    await service.startService();
    _isRunning = true;
    print('$TAG Background monitoring STARTED');
  }

  static Future<void> stopMonitoring() async {
    if (!_isRunning) {
      print('$TAG Not running');
      return;
    }
    
    print('$TAG Stopping background monitoring...');
    
    // Save state
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('background_monitoring', false);
    
    _timer?.cancel();
    final service = FlutterBackgroundService();
    
    // Send stop signal
    service.invoke('stopService');
    
    _isRunning = false;
    print('$TAG Background monitoring COMPLETELY STOPPED - No battery usage');
  }

  static Future<void> checkInitialState() async {
    final prefs = await SharedPreferences.getInstance();
    final shouldMonitor = prefs.getBool('background_monitoring') ?? false;
    if (shouldMonitor && !_isRunning) {
      startMonitoring();
    }
  }

  static bool get isRunning => _isRunning;
}
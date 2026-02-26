import 'package:vibration/vibration.dart';
import '../models/destination.dart';
import 'dart:async';

class NativeVibrationService {
  static final NativeVibrationService _instance = NativeVibrationService._internal();
  factory NativeVibrationService() => _instance;
  NativeVibrationService._internal();

  // EXTRA LONG patterns for pocket feel (all durations in milliseconds)
  static const Map<String, List<int>> pocketPatterns = {
    'Default': [2000, 500, 2000, 500, 2000, 500, 2000],  // 3 long vibrations
    'Gentle': [1500, 300, 1500, 300, 1500, 300, 1500],    // 3 medium vibrations
    'Long': [3000, 500, 3000, 500, 3000, 500, 3000],      // 3 very long vibrations
    'Rapid': [800, 200, 800, 200, 800, 200, 800, 200, 800], // 4 quick strong bursts
    'Alert': [2500, 300, 2500, 300, 2500, 300, 2500],      // 3 urgent long vibrations
    'Single': [4000],                           // One VERY long 4 second vibration
    'Double': [2000, 400, 2000, 400, 2000],                // Two 2 second vibrations
  };

  // For devices that support amplitude (Android)
  static const Map<String, int> amplitudes = {
    'Default': 255,
    'Gentle': 255,
    'Long': 255,
    'Rapid': 255,
    'Alert': 255,
    'Single': 255,
    'Double': 255,
  };

  Future<void> vibrateArrival(Destination destination) async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator != true) return;

    final pattern = pocketPatterns[destination.vibrationPattern] ?? 
                    pocketPatterns['Default']!;
    
    try {
      // METHOD 1: Try custom pattern with repetitions
      final canCustom = await Vibration.hasCustomVibrationsSupport() ?? false;
      if (canCustom) {
        // Repeat the pattern 2 times for extra strength
        await Vibration.vibrate(pattern: pattern, repeat: 2);
        
        // Stop after pattern completes
        await Future.delayed(Duration(milliseconds: pattern.reduce((a, b) => a + b) * 2));
        await Vibration.cancel();
        return;
      }

      // METHOD 2: Fallback to sequential vibrations
      for (int i = 0; i < 3; i++) {  // Repeat 3 times for pocket feel
        for (int j = 0; j < pattern.length; j += 2) {
          final duration = pattern[j];
          await Vibration.vibrate(duration: duration);
          
          if (j + 1 < pattern.length) {
            await Future.delayed(Duration(milliseconds: pattern[j + 1]));
          }
        }
        
        // Small pause between repeats
        if (i < 2) await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      // METHOD 3: Ultimate fallback - just vibrate continuously
      await Vibration.vibrate(duration: 5000);  // 5 seconds continuous
    }
  }

  Future<void> testPocketPattern(String patternName) async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator != true) return;

    final pattern = pocketPatterns[patternName] ?? pocketPatterns['Default']!;
    
    try {
      final canCustom = await Vibration.hasCustomVibrationsSupport() ?? false;
      if (canCustom) {
        await Vibration.vibrate(pattern: pattern, repeat: 1);
        await Future.delayed(Duration(milliseconds: pattern.reduce((a, b) => a + b)));
        await Vibration.cancel();
        return;
      }

      // Manual pattern for testing
      for (int j = 0; j < pattern.length; j += 2) {
        final duration = pattern[j];
        await Vibration.vibrate(duration: duration);
        if (j + 1 < pattern.length) {
          await Future.delayed(Duration(milliseconds: pattern[j + 1]));
        }
      }
    } catch (e) {
      await Vibration.vibrate(duration: 3000);
    }
  }

  // Success feedback (short but strong)
  Future<void> vibrateSuccess() async {
    try {
      await Vibration.vibrate(duration: 300, amplitude: 255);
    } catch (e) {
      await Vibration.vibrate(duration: 300);
    }
  }

  // Error feedback (distinct pattern)
  Future<void> vibrateError() async {
    try {
      final canCustom = await Vibration.hasCustomVibrationsSupport() ?? false;
      if (canCustom) {
        await Vibration.vibrate(pattern: [500, 200, 500, 200, 500]);
      } else {
        for (int i = 0; i < 3; i++) {
          await Vibration.vibrate(duration: 500);
          if (i < 2) await Future.delayed(const Duration(milliseconds: 200));
        }
      }
    } catch (e) {
      for (int i = 0; i < 3; i++) {
        await Vibration.vibrate(duration: 500);
        if (i < 2) await Future.delayed(const Duration(milliseconds: 200));
      }
    }
  }
}
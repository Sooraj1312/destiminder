import 'package:vibration/vibration.dart';
import '../models/destination.dart';
import 'dart:async';

class VibrationService {
  static final VibrationService _instance = VibrationService._internal();
  factory VibrationService() => _instance;
  VibrationService._internal();

  // Strong vibration patterns (in milliseconds)
  static const Map<String, List<int>> strongPatterns = {
    'Default': [1500, 500, 1500],     // Strong: 1.5s on, 0.5s off, 1.5s on
    'Gentle': [1000, 300, 1000],       // Still strong: 1s on, 0.3s off, 1s on
    'Long': [3000, 500, 3000],         // Very long: 3s on, 0.5s off, 3s on
    'Rapid': [500, 200, 500, 200, 500], // Fast but strong: 0.5s bursts
    'Alert': [2000, 300, 2000, 300, 2000], // Urgent: 2s bursts
    'Single': [2000],                    // One long 2s vibration
    'Double': [1000, 300, 1000],        // Two 1s vibrations
  };

  // Amplitude levels (Android only, 1-255)
  static const Map<String, int> amplitudes = {
    'Default': 255,    // MAX vibration
    'Gentle': 200,     // Still strong
    'Long': 255,       // MAX
    'Rapid': 255,      // MAX
    'Alert': 255,      // MAX
    'Single': 255,     // MAX
    'Double': 255,     // MAX
  };

  Future<void> vibrateArrival(Destination destination) async {
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator != true) return;

    // Get pattern for this destination
    final pattern = strongPatterns[destination.vibrationPattern] ?? 
                    strongPatterns['Default']!;
    
    // Get amplitude (Android only)
    final amplitude = amplitudes[destination.vibrationPattern] ?? 255;
    
    try {
      // Try vibration with amplitude (stronger)
      if (await Vibration.hasAmplitudeControl() ?? false) {
        // Android: Use amplitude for stronger vibration
        for (int i = 0; i < pattern.length; i += 2) {
          final duration = pattern[i];
          await Vibration.vibrate(duration: duration, amplitude: amplitude);
          if (i + 1 < pattern.length) {
            await Future.delayed(Duration(milliseconds: pattern[i + 1]));
          }
        }
      } else {
        // Fallback to pattern
        await Vibration.vibrate(pattern: pattern);
      }
    } catch (e) {
      // Fallback to simple vibration
      await Vibration.vibrate(duration: 2000);
    }
  }

  Future<void> testStrongPattern(String patternName) async {
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator != true) return;

    final pattern = strongPatterns[patternName] ?? strongPatterns['Default']!;
    final amplitude = amplitudes[patternName] ?? 255;
    
    try {
      if (await Vibration.hasAmplitudeControl() ?? false) {
        for (int i = 0; i < pattern.length; i += 2) {
          final duration = pattern[i];
          await Vibration.vibrate(duration: duration, amplitude: amplitude);
          if (i + 1 < pattern.length) {
            await Future.delayed(Duration(milliseconds: pattern[i + 1]));
          }
        }
      } else {
        await Vibration.vibrate(pattern: pattern);
      }
    } catch (e) {
      await Vibration.vibrate(duration: 2000);
    }
  }

  Future<void> vibrateSuccess() async {
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator != true) return;

    try {
      if (await Vibration.hasAmplitudeControl() ?? false) {
        await Vibration.vibrate(duration: 200, amplitude: 200);
      } else {
        await Vibration.vibrate(duration: 200);
      }
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> vibrateError() async {
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator != true) return;

    try {
      if (await Vibration.hasAmplitudeControl() ?? false) {
        await Vibration.vibrate(duration: 500, amplitude: 255);
        await Future.delayed(const Duration(milliseconds: 200));
        await Vibration.vibrate(duration: 500, amplitude: 255);
        await Future.delayed(const Duration(milliseconds: 200));
        await Vibration.vibrate(duration: 500, amplitude: 255);
      } else {
        await Vibration.vibrate(pattern: [500, 200, 500, 200, 500]);
      }
    } catch (e) {
      // Silent fail
    }
  }
}
import 'package:flutter_tts/flutter_tts.dart';
import '../models/destination.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  
  // Master toggle - add this
  static bool masterEnabled = true;

  // Initialize TTS
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
    
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });
    
    _isInitialized = true;
  }

  // Announce arrival - NOW respects master toggle
  Future<void> announceArrival(Destination destination) async {
    if (!masterEnabled) {
      print('Voice master is OFF - skipping announcement');
      return;
    }
    if (!destination.voiceEnabled) {
      print('Voice disabled for this destination - skipping');
      return;
    }
    
    await initialize();
    
    String message = "You have arrived at ${destination.displayName}";
    
    try {
      _isSpeaking = true;
      await _flutterTts.speak(message);
    } catch (e) {
      print('TTS Error: $e');
      _isSpeaking = false;
    }
  }

  // Stop any ongoing announcement
  Future<void> stop() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      _isSpeaking = false;
    }
  }

  // Test voice - also respects master toggle
  Future<void> testVoice(String placeName) async {
    if (!masterEnabled) return;
    
    await initialize();
    try {
      await _flutterTts.speak("Testing voice for $placeName");
    } catch (e) {
      print('Test TTS Error: $e');
    }
  }

  // Check if speaking
  bool get isSpeaking => _isSpeaking;

  // Dispose
  Future<void> dispose() async {
    await _flutterTts.stop();
  }
}
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/destination.dart';

class DestinationService extends ChangeNotifier {
  List<Destination> _destinations = [];

  List<Destination> get destinations => _destinations;
  
  // NEW - get only active destinations
  List<Destination> get activeDestinations => 
      _destinations.where((d) => d.isActive).toList();

  DestinationService() {
    loadDestinations();
  }

  Future<void> loadDestinations() async {
    final prefs = await SharedPreferences.getInstance();
    final String? destinationsJson = prefs.getString('destinations');
    
    if (destinationsJson != null) {
      final List<dynamic> decoded = json.decode(destinationsJson);
      _destinations = decoded.map((item) => Destination.fromJson(item)).toList();
    }
    notifyListeners();
  }

  Future<void> addDestination(Destination destination) async {
    _destinations.add(destination);
    await _saveDestinations();
    notifyListeners();
  }

  Future<void> removeDestination(String id) async {
    _destinations.removeWhere((d) => d.id == id);
    await _saveDestinations();
    notifyListeners();
  }

  // NEW - toggle active status
  Future<void> toggleActive(String id) async {
    final index = _destinations.indexWhere((d) => d.id == id);
    if (index != -1) {
      _destinations[index].isActive = !_destinations[index].isActive;
      await _saveDestinations();
      notifyListeners();
    }
  }

  // NEW - deactivate all (useful for "Stop All" button)
  Future<void> deactivateAll() async {
    for (var d in _destinations) {
      d.isActive = false;
    }
    await _saveDestinations();
    notifyListeners();
  }

  Future<void> _saveDestinations() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(
      _destinations.map((d) => d.toJson()).toList()
    );
    await prefs.setString('destinations', encoded);
  }
}
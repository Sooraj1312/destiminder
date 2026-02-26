import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/arrival_history.dart';
import '../models/destination.dart';

class HistoryService extends ChangeNotifier {
  List<ArrivalHistory> _history = [];
  
  List<ArrivalHistory> get history => _history;
  
  // Get history for specific destination
  List<ArrivalHistory> getHistoryForDestination(String destinationId) {
    return _history.where((h) => h.destinationId == destinationId).toList();
  }
  
  // Get today's arrivals
  List<ArrivalHistory> get todaysArrivals {
    final today = DateTime.now();
    return _history.where((h) => 
      h.arrivalTime.year == today.year &&
      h.arrivalTime.month == today.month &&
      h.arrivalTime.day == today.day
    ).toList();
  }

  HistoryService() {
    loadHistory();
  }

  Future<void> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString('arrival_history');
    
    if (historyJson != null) {
      final List<dynamic> decoded = json.decode(historyJson);
      _history = decoded.map((item) => ArrivalHistory.fromJson(item)).toList();
      // Sort by most recent first
      _history.sort((a, b) => b.arrivalTime.compareTo(a.arrivalTime));
    }
    notifyListeners();
  }

  Future<void> addArrival(Destination destination, {String? notes}) async {
    final history = ArrivalHistory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      destinationId: destination.id,
      destinationName: destination.displayName,
      latitude: destination.latitude,
      longitude: destination.longitude,
      arrivalTime: DateTime.now(),
      notes: notes,
    );
    
    _history.insert(0, history); 
    await _saveHistory();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _saveHistory();
    notifyListeners();
  }

  Future<void> deleteArrival(String id) async {
    _history.removeWhere((h) => h.id == id);
    await _saveHistory();
    notifyListeners();
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(
      _history.map((h) => h.toJson()).toList()
    );
    await prefs.setString('arrival_history', encoded);
  }

  // Statistics
  int getTotalArrivals() => _history.length;
  
  int getArrivalsForDestination(String destinationId) {
    return _history.where((h) => h.destinationId == destinationId).length;
  }
  
  Map<String, int> getMostVisited() {
    final Map<String, int> counts = {};
    for (var h in _history) {
      counts[h.destinationName] = (counts[h.destinationName] ?? 0) + 1;
    }
    return counts;
  }
  
  DateTime? getLastArrival(String destinationId) {
    final arrivals = getHistoryForDestination(destinationId);
    return arrivals.isNotEmpty ? arrivals.first.arrivalTime : null;
  }
}
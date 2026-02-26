import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  final List<Function(Position)> _listeners = [];

  Future<bool> requestPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    if (await Permission.locationAlways.isDenied) {
      await Permission.locationAlways.request();
    }
    
    return permission == LocationPermission.always || 
           permission == LocationPermission.whileInUse;
  }

  Future<bool> isLocationEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<Position?> getCurrentLocation() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return _currentPosition;
    } catch (e) {
      return null;
    }
  }

  void startListening() {
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      _currentPosition = position;
      for (var listener in _listeners) {
        listener(position);
      }
    });
  }

  void addListener(Function(Position) listener) {
    _listeners.add(listener);
  }

  void removeListener(Function(Position) listener) {
    _listeners.remove(listener);
  }

  void stopListening() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _listeners.clear();
  }

  Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        return '${place.street}, ${place.locality}, ${place.administrativeArea}';
      }
    } catch (e) {
      return 'Unknown location';
    }
    return 'Unknown location';
  }

  double calculateDistance(double startLat, double startLng, 
                          double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

}
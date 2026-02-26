class Destination {
  final String id;
  final String? customName;
  final double latitude;
  final double longitude;
  final String address;
  final DateTime createdAt;
  double radius;
  bool isActive;
  String vibrationPattern;
  bool voiceEnabled;  

  static const Map<String, List<int>> patterns = {
    'Default': [2000, 500, 2000, 500, 2000],
    'Gentle': [1500, 300, 1500, 300, 1500],
    'Long': [3000, 500, 3000, 500, 3000],
    'Rapid': [800, 200, 800, 200, 800, 200, 800],
    'Alert': [2500, 300, 2500, 300, 2500],
    'Single': [4000],
    'Double': [2000, 400, 2000],
  };

  Destination({
    required this.id,
    this.customName,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.createdAt,
    this.radius = 100,
    this.isActive = false,
    this.vibrationPattern = 'Default',
    this.voiceEnabled = false,  
  });

  String get displayName => customName ?? address.split(',').first;

  Map<String, dynamic> toJson() => {
    'id': id,
    'customName': customName,
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'createdAt': createdAt.toIso8601String(),
    'radius': radius,
    'isActive': isActive,
    'vibrationPattern': vibrationPattern,
    'voiceEnabled': voiceEnabled,  
  };

  factory Destination.fromJson(Map<String, dynamic> json) => Destination(
    id: json['id'],
    customName: json['customName'],
    latitude: json['latitude'],
    longitude: json['longitude'],
    address: json['address'],
    createdAt: DateTime.parse(json['createdAt']),
    radius: json['radius'] ?? 100,
    isActive: json['isActive'] ?? false,
    vibrationPattern: json['vibrationPattern'] ?? 'Default',
    voiceEnabled: json['voiceEnabled'] ?? false,  
  );
}
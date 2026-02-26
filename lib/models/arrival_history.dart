class ArrivalHistory {
  final String id;
  final String destinationId;
  final String destinationName;
  final double latitude;
  final double longitude;
  final DateTime arrivalTime;
  final String? notes;

  ArrivalHistory({
    required this.id,
    required this.destinationId,
    required this.destinationName,
    required this.latitude,
    required this.longitude,
    required this.arrivalTime,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'destinationId': destinationId,
    'destinationName': destinationName,
    'latitude': latitude,
    'longitude': longitude,
    'arrivalTime': arrivalTime.toIso8601String(),
    'notes': notes,
  };

  factory ArrivalHistory.fromJson(Map<String, dynamic> json) => ArrivalHistory(
    id: json['id'],
    destinationId: json['destinationId'],
    destinationName: json['destinationName'],
    latitude: json['latitude'],
    longitude: json['longitude'],
    arrivalTime: DateTime.parse(json['arrivalTime']),
    notes: json['notes'],
  );
}
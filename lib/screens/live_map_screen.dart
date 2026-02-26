import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import '../services/voice_service.dart';
import '../services/location_service.dart';
import '../services/destination_service.dart';
import '../services/native_vibration_service.dart';
import '../models/destination.dart';
import '../services/history_service.dart'; 
import 'history_screen.dart';               
import '../widgets/emoji_icons.dart';  

class LiveMapScreen extends StatefulWidget {
  final Destination? initialDestination;
  
  const LiveMapScreen({super.key, this.initialDestination});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen>
    with TickerProviderStateMixin {
  late final AnimatedMapController _mapController;
  final LocationService _locationService = LocationService();
  final NativeVibrationService _vibration = NativeVibrationService();
  
  Position? _currentPosition;
  double _distanceToDestination = 0.0;
  bool _hasArrived = false;
  
  // Map styles
  static const String _osmTileLayer = 
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
  static const String _osmDarkTileLayer = 
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';

  @override
  void initState() {
    super.initState();
    _mapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
    );
    _startLiveTracking();
  }

  void _startLiveTracking() {
    _locationService.addListener(_onLocationUpdate);
    _locationService.getCurrentLocation().then((position) {
      if (position != null) {
        _onLocationUpdate(position);
      }
    });
  }

  Future<void> _onLocationUpdate(Position position) async {
    final destinationService = 
        Provider.of<DestinationService>(context, listen: false);
    
    Destination? currentDest;
    if (widget.initialDestination != null) {
      currentDest = widget.initialDestination;
    } else {
      final active = destinationService.activeDestinations;
      currentDest = active.isNotEmpty ? active.first : null;
    }
    
    if (currentDest != null) {
      setState(() {
        _currentPosition = position;
        _distanceToDestination = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          currentDest!.latitude,   
          currentDest!.longitude,  
        );
      });

      if (!_hasArrived && _distanceToDestination <= currentDest.radius) {
        _onArrived(currentDest);
      }
    }
  }

  Future<void> _onArrived(Destination destination) async {
    setState(() => _hasArrived = true);
    
    // Record in history
    final historyService = Provider.of<HistoryService>(context, listen: false);
    await historyService.addArrival(destination);
    
    await _vibration.vibrateArrival(destination);  // Pass the whole destination object, not just name
    
    // ANNOUNCE if enabled
    if (destination.voiceEnabled) {
      await VoiceService().announceArrival(destination);
    }

    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: EmojiIcons.emojiEmotions(color: Colors.green),
            ),
            const SizedBox(height: 16),
            const Text(
              'You Have Arrived! 🎉',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              destination.displayName,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              destination.address,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EmojiIcons.history(color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'Arrival recorded at ${_formatTime(DateTime.now())}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _hasArrived = false);
            },
            child: const Text('OK'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to history screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HistoryScreen(initialDestination: destination),
                ),
              );
            },
            icon: EmojiIcons.history(size: 16),
            label: const Text('View History'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final destinationService = Provider.of<DestinationService>(context);
    
    Destination? currentDestination;
    if (widget.initialDestination != null) {
      currentDestination = widget.initialDestination;
    } else {
      final active = destinationService.activeDestinations;
      currentDestination = active.isNotEmpty ? active.first : null;
    }
    
    if (currentDestination == null) {
      return const Scaffold(
        body: Center(
          child: Text('No destination selected'),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: EmojiIcons.mapBack(color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _hasArrived 
                ? EmojiIcons.myLocation(color: Colors.green)
                : EmojiIcons.myLocation(color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  _hasArrived 
                      ? 'Arrived!'
                      : '${_distanceToDestination.toStringAsFixed(0)}m',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController.mapController,
            options: MapOptions(
              initialCenter: LatLng(
                currentDestination!.latitude,   
                currentDestination!.longitude, 
              ),
              initialZoom: 15.0,
              maxZoom: 19.0,
              minZoom: 3.0,
              interactionOptions: const InteractionOptions(
                enableScrollWheel: true,
                enableMultiFingerGestureRace: true,
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: isDark ? _osmDarkTileLayer : _osmTileLayer,
                userAgentPackageName: 'com.sooraj.destiminder',
                maxZoom: 19,
                tileProvider: CachedTileProvider(),
              ),
              
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      ),
                      width: 80,
                      height: 80,
                      child: Stack(
                        children: [
                          Center(
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.5),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(
                      currentDestination.latitude,
                      currentDestination.longitude,
                    ),
                    width: 60,
                    height: 60,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.elasticOut,
                      decoration: BoxDecoration(
                        color: _hasArrived 
                            ? Colors.green.withOpacity(0.3)
                            : Colors.red.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _hasArrived ? Colors.green : Colors.red,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_hasArrived ? Colors.green : Colors.red).withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: _hasArrived 
                                ? EmojiIcons.destinationFlag(color: Colors.green)
                                : EmojiIcons.location(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
              
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: LatLng(
                      currentDestination.latitude,
                      currentDestination.longitude,
                    ),
                    radius: currentDestination.radius,
                    color: (_hasArrived ? Colors.green : Colors.blue).withOpacity(0.1),
                    borderColor: (_hasArrived ? Colors.green : Colors.blue).withOpacity(0.3),
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              
              if (_currentPosition != null && !_hasArrived)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        LatLng(
                          currentDestination.latitude,
                          currentDestination.longitude,
                        ),
                      ],
                      color: Colors.blue,
                      strokeWidth: 3,
                    ),
                  ],
                ),
            ],
          ),
          
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildInfoCard(currentDestination),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Destination destination) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _hasArrived 
                          ? Colors.green.withOpacity(0.1)
                          : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _hasArrived 
                            ? EmojiIcons.celebration(color: Colors.green)
                            : EmojiIcons.myLocation(color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          destination.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          _hasArrived 
                              ? 'You are here! 🎉'
                              : '${_distanceToDestination.toStringAsFixed(0)}m away',
                          style: TextStyle(
                            color: _hasArrived 
                                ? Colors.green
                                : Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!_hasArrived) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: (_distanceToDestination / 500).clamp(0, 1),
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _distanceToDestination < 100 
                        ? Colors.orange 
                        : Colors.blue,
                  ),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Distance to arrival',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '${destination.radius}m radius',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _locationService.removeListener(_onLocationUpdate);
    _mapController.dispose();
    super.dispose();
  }
}

class CachedTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
      maxWidth: 256,
      maxHeight: 256,
    );
  }
}
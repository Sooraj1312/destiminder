import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/destination.dart';
import '../services/voice_service.dart';
import '../services/location_service.dart';
import '../services/vibration_service.dart';
import '../widgets/vibration_picker.dart';
import 'dart:ui';
import '../widgets/emoji_icons.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen>
    with TickerProviderStateMixin {
  late final AnimatedMapController _mapController;
  final LocationService _locationService = LocationService();
  final VibrationService _vibration = VibrationService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  double _selectedRadius = 100; // Default radius
  final List<int> _radiusOptions = [10, 30, 50, 100, 200, 300, 500, 1000]; // Quick options
  String _selectedPattern = 'Default';
  LatLng? _selectedLocation;
  String _selectedAddress = '';
  bool _isLoading = false;
  bool _isLocating = false;
  bool _voiceEnabled = false;
  LatLng? _currentLocation;
  
  // Map style - Free OSM tiles with beautiful theme
  static const String _osmTileLayer = 
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
  static const String _osmDarkTileLayer = 
      'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';
  
  final List<MapTileSource> _tileLayers = [
    MapTileSource('Light', _osmTileLayer),
    MapTileSource('Dark', _osmDarkTileLayer),
    MapTileSource('Satellite', 
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'),
  ];
  
  int _selectedTileLayer = 0;

  @override
  void initState() {
    super.initState();
    _mapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
    final position = await _locationService.getCurrentLocation();
    if (position != null) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      
      // Animate to current location
      _mapController.animateTo(
        dest: _currentLocation!,
        zoom: 16.0,
      );
      
      // Auto-select current location after 0.5s
      Future.delayed(const Duration(milliseconds: 500), () {
        _onMapTapped(_currentLocation!);
      });
    }
    setState(() => _isLocating = false);
  }

  Future<void> _onMapTapped(LatLng latLng) async {
    setState(() {
      _selectedLocation = latLng;
      _isLoading = true;
    });

    try {
      // Reverse geocoding to get address
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latLng.latitude, 
        latLng.longitude
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        _selectedAddress = [
          place.street,
          place.locality,
          place.administrativeArea,
          place.country
        ].where((e) => e != null && e.isNotEmpty).join(', ');
      }
      
      // Auto-fill name suggestion from address
      if (_nameController.text.isEmpty) {
        _nameController.text = placemarks.first.street ?? 
                               placemarks.first.locality ?? 
                               'My Destination';
      }
      
    } catch (e) {
      _selectedAddress = 'Selected location';
    }
    
    // Haptic feedback
    await _vibration.vibrateSuccess();
    
    setState(() => _isLoading = false);
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      // Use geocoding for search
      List<Location> locations = await locationFromAddress(query);
      
      if (locations.isNotEmpty) {
        final location = locations.first;
        final latLng = LatLng(location.latitude, location.longitude);
        
        // Animate to searched location
        await _mapController.animateTo(
          dest: latLng,
          zoom: 17.0,
        );
        
        // Auto-select the searched location
        _onMapTapped(latLng);
        
        // Clear search and hide keyboard
        _searchController.clear();
        FocusScope.of(context).unfocus();
      } else {
        _showErrorSnackBar('Location not found');
      }
    } catch (e) {
      _showErrorSnackBar('Could not find location');
    }
    
    setState(() => _isLoading = false);
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            EmojiIcons.errorOutline(color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Fullscreen Map
          FlutterMap(
            mapController: _mapController.mapController,
            options: MapOptions(
              initialCenter: _currentLocation ?? const LatLng(28.6139, 77.2090), // Default: New Delhi
              initialZoom: 12.0,
              onTap: (_, latLng) => _onMapTapped(latLng),
              maxZoom: 19.0,
              minZoom: 3.0,
              interactionOptions: const InteractionOptions(
                enableScrollWheel: true,
                enableMultiFingerGestureRace: true,
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // OSM Tile Layer
              TileLayer(
                urlTemplate: isDark 
                    ? _tileLayers[1].url 
                    : _tileLayers[_selectedTileLayer].url,
                userAgentPackageName: 'com.sooraj.destiminder',
                maxZoom: 19,
                tileProvider: CachedTileProvider(),
              ),
              
              // Current location marker
              if (_currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: EmojiIcons.currentLocation(color: Colors.blue),
                        ),
                      ),
                    ),
                  ],
                ),
              
              // Selected location marker
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 60,
                      height: 60,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.elasticOut,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: EmojiIcons.selectedLocation(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Glass morphism search bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      EmojiIcons.search(color: Colors.grey[600]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search for a place...',
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.grey[600]),
                          ),
                          onSubmitted: _searchLocation,
                          textInputAction: TextInputAction.search,
                        ),
                      ),
                      if (_isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: IconButton(
                    icon: EmojiIcons.back(color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Map type selector
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            right: 16,
            child: Column(
              children: List.generate(_tileLayers.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedTileLayer = index);
                      _vibration.vibrateSuccess();
                    },
                    child: Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: _selectedTileLayer == index
                            ? Theme.of(context).primaryColor
                            : Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: index == 0 
                              ? EmojiIcons.mapStyleLight(color: _selectedTileLayer == index ? Colors.white : Colors.grey[700])
                              : index == 1 
                                  ? EmojiIcons.mapStyleDark(color: _selectedTileLayer == index ? Colors.white : Colors.grey[700])
                                  : EmojiIcons.mapStyleSatellite(color: _selectedTileLayer == index ? Colors.white : Colors.grey[700]),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Current location button
          Positioned(
            bottom: 200,
            right: 16,
            child: GestureDetector(
              onTap: _getCurrentLocation,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _isLocating
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : EmojiIcons.gpsFixed(color: Colors.blue),
              ),
            ),
          ),

          // Bottom selection card
          if (_selectedLocation != null)
            DraggableScrollableSheet(
              initialChildSize: 0.4,  // Starts at 40% of screen
              minChildSize: 0.15,      // Can collapse to 15%
              maxChildSize: 0.7,       // Can expand to 70%
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
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
                    children: [
                      // Drag handle
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Scrollable content
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Location info
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: EmojiIcons.location(color: Theme.of(context).primaryColor),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Selected Location',
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _selectedAddress.isNotEmpty 
                                              ? _selectedAddress.split(',').first 
                                              : 'Tap on map to select',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              
                              // Custom name field
                              TextField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: 'Name this place (optional)',
                                  hintText: 'e.g., Office, Home, Gym',
                                  prefixIcon: EmojiIcons.editName(),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.withOpacity(0.05),
                                ),
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Vibration pattern selector
                              _buildVibrationSelector(),
                              
                              const SizedBox(height: 20),
                              
                              // Voice announcement toggle
                              _buildVoiceToggle(),
                              
                              const SizedBox(height: 20),
                              
                              // Radius selector
                              _buildRadiusSelector(),
                              
                              const SizedBox(height: 20),
                              
                              // Confirm button
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: FilledButton(
                                  onPressed: _isLoading ? null : () {
                                    if (_selectedLocation != null) {
                                      final destination = Destination(
                                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                                        customName: _nameController.text.trim().isEmpty 
                                            ? null 
                                            : _nameController.text.trim(),
                                        latitude: _selectedLocation!.latitude,
                                        longitude: _selectedLocation!.longitude,
                                        address: _selectedAddress,
                                        createdAt: DateTime.now(),
                                        radius: _selectedRadius,
                                        vibrationPattern: _selectedPattern,
                                        voiceEnabled: _voiceEnabled,
                                      );
                                      Navigator.pop(context, destination);
                                    }
                                  },
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'Set Destination',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildVibrationSelector() {
    return GestureDetector(
      onTap: () async {
        final result = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => VibrationPicker(
            currentPattern: _selectedPattern,
            onPatternSelected: (pattern) {
              Navigator.pop(context, pattern);
            },
          ),
        );
        
        if (result != null) {
          setState(() => _selectedPattern = result);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            EmojiIcons.vibration(color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vibration Pattern',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    _selectedPattern,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            EmojiIcons.arrowDropDown(),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          EmojiIcons.voiceToggleOn(color: _voiceEnabled ? Colors.green : Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Voice Announcement',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  _voiceEnabled ? 'Will speak when you arrive' : 'Vibrate only',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: _voiceEnabled ? Colors.green : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _voiceEnabled,
            onChanged: (value) {
              setState(() => _voiceEnabled = value);
              if (value) {
                VoiceService().testVoice(_nameController.text.isEmpty 
                    ? 'this place' 
                    : _nameController.text);
              }
            },
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildRadiusSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EmojiIcons.radius(color: Theme.of(context).primaryColor),
              const SizedBox(width: 12),
              const Text(
                'Detection Radius',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Quick select chips
          Wrap(
            spacing: 8,
            children: const [10, 30, 50, 100, 200, 300, 500, 1000].map((radius) {
              final isSelected = _selectedRadius == radius;
              return ChoiceChip(
                label: Text('$radius m'),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedRadius = radius.toDouble());
                  }
                },
                selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 16),
          
          // Slider
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _selectedRadius,
                  min: 10,
                  max: 1000,
                  divisions: 99,
                  label: '${_selectedRadius.round()} m',
                  onChanged: (value) {
                    setState(() {
                      _selectedRadius = value.roundToDouble();
                    });
                  },
                  activeColor: Theme.of(context).primaryColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_selectedRadius.round()} m',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Info text
          Row(
            children: [
              EmojiIcons.info(color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _selectedRadius <= 50
                      ? 'Small radius - triggers when very close'
                      : _selectedRadius <= 200
                          ? 'Medium radius - triggers when nearby'
                          : 'Large radius - triggers from far away',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}

class MapTileSource {
  final String name;
  final String url;
  
  MapTileSource(this.name, this.url);
}

// Cached tile provider for better performance
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
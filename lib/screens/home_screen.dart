import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';  
import '../services/background_monitor.dart';
import '../services/voice_service.dart';
import '../services/destination_service.dart';
import '../services/location_service.dart';
import '../services/native_vibration_service.dart';
import '../services/history_service.dart';
import '../models/destination.dart';
import 'map_picker_screen.dart';
import 'live_map_screen.dart';
import '../widgets/destination_card.dart';
import '../widgets/vibration_picker.dart';
import 'history_screen.dart'; 
import '../widgets/emoji_icons.dart';
import '../widgets/todo_list.dart';
import '../services/todo_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _fabAnimationController;
  final PanelController _panelController = PanelController();
  final LocationService _locationService = LocationService();
  final NativeVibrationService _vibration = NativeVibrationService();
  bool _masterVoiceEnabled = true;
  bool _backgroundMonitoring = false;
  Position? _currentPosition;
  Map<String, double> _distances = {}; // Store distances for all active destinations
  Timer? _locationTimer;
  bool _isLocationUpdating = false;
  final Set<String> _arrivedDestinations = {};
  final Set<String> _visitedDestinations = {}; // Track if announced for this visit
  

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _initializeServices();
    _getCurrentLocation();
    _checkBackgroundState();
    _loadSavedVoiceState(); 
    
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final destinationService = Provider.of<DestinationService>(context, listen: false);
      destinationService.addListener(_onDestinationsChanged);
      
      // Initial check
      _onDestinationsChanged();
    });
  }

  Future<void> _loadSavedVoiceState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedState = prefs.getBool('master_voice_enabled');
    if (savedState != null) {
      setState(() {
        _masterVoiceEnabled = savedState;
        VoiceService.masterEnabled = savedState;
      });
    }
  }

  void _onDestinationsChanged() {
    // Use Provider with listen: false to avoid rebuild loops
    final destinationService = Provider.of<DestinationService>(context, listen: false);
    
    if (destinationService.activeDestinations.isNotEmpty) {
      _startLocationTracking();
    } else {
      _stopLocationTracking();
      setState(() {
        _distances.clear();
      });
    }
  }

  void _startLocationTracking() {
    if (_isLocationUpdating) return;
    
    _isLocationUpdating = true;
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await _updateLocations();
    });
    
    // Update immediately
    _updateLocations();
  }

  void _stopLocationTracking() {
    _isLocationUpdating = false;
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  Future<void> _updateLocations() async {
    if (!mounted) return;
    
    try {
      // Get current position
      final position = await _locationService.getCurrentLocation();
      if (position == null) return;
      
      setState(() {
        _currentPosition = position;
      });
      
      // Get active destinations
      final destinationService = Provider.of<DestinationService>(context, listen: false);
      final activeDestinations = destinationService.activeDestinations;
      
      if (activeDestinations.isEmpty) {
        _distances.clear();
        return;
      }
      
      // Calculate distances for all active destinations
      final newDistances = <String, double>{};
      for (var dest in activeDestinations) {
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          dest.latitude,
          dest.longitude,
        );
        newDistances[dest.id] = distance;
        
        // Check if arrived
        if (distance <= dest.radius) {
          _onArrived(dest);
        } else {
          // If outside radius, remove from visited set (so can announce again when re-entering)
          if (_visitedDestinations.contains(dest.id)) {
            setState(() {
              _visitedDestinations.remove(dest.id);
            });
          }
        }
      }
      
      setState(() {
        _distances = newDistances;
      });
      
    } catch (e) {
      print('Location update error: $e');
    }
  }

  Future<void> _onArrived(Destination destination) async {
    // Check if already announced for this visit
    if (_visitedDestinations.contains(destination.id)) {
      print('Already announced for ${destination.displayName} this visit');
      return;
    }
    
    // Mark as visited for this session
    setState(() {
      _visitedDestinations.add(destination.id);
      _arrivedDestinations.add(destination.id);
    });
    
    // Record in history
    final historyService = Provider.of<HistoryService>(context, listen: false);
    await historyService.addArrival(destination);
    
    // Vibrate based on pattern
    await _vibration.vibrateArrival(destination);
    
    // Voice announcement if enabled
    if (destination.voiceEnabled && VoiceService.masterEnabled) {
      await VoiceService().announceArrival(destination);
      
      // Also announce pending tasks if any
      final todoService = Provider.of<TodoService>(context, listen: false);
      final pendingTodos = todoService.getPendingTodos(destination.id);
      if (pendingTodos.isNotEmpty) {
        String taskMessage = 'You have ${pendingTodos.length} pending task';
        if (pendingTodos.length > 1) taskMessage += 's';
        taskMessage += ' at ${destination.displayName}';
        await VoiceService().announceCustom(taskMessage);
      }
    }
    
    // Show arrival card
    _buildArrivalCard(destination);

    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _arrivedDestinations.remove(destination.id);
        });
      }
    });
  }

  Future<void> _checkBackgroundState() async {
    final prefs = await SharedPreferences.getInstance();
    final wasRunning = prefs.getBool('background_monitoring') ?? false;
    setState(() {
      _backgroundMonitoring = wasRunning;
    });
    if (wasRunning) {
      await BackgroundMonitor.checkInitialState();
    }
  }

  Future<void> _getCurrentLocation() async {
    final position = await _locationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _currentPosition = position;
      });
    }
  }

  void _startLocationUpdates() {
    _locationService.addListener((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });
  }

  void _showAddTodoDialog(Destination destination) {
    final todoService = Provider.of<TodoService>(context, listen: false);
    final titleController = TextEditingController();
    final descController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Task for ${destination.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Task title',
                hintText: 'e.g., Buy milk',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                todoService.addTodo(
                  destination.id,
                  titleController.text,
                  description: descController.text.isNotEmpty 
                      ? descController.text 
                      : null,
                );
                Navigator.pop(context);
                
                // Show confirmation
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Task added to ${destination.displayName}'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showTodoList(Destination destination) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: TodoList(
          destination: destination,
          onClose: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<void> _toggleBackgroundMonitoring() async {
    if (!_backgroundMonitoring) {
      // Request background location permission
      final status = await Permission.locationAlways.request();
      if (status.isGranted) {
        await BackgroundMonitor.startMonitoring();
        setState(() => _backgroundMonitoring = true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Background monitoring ON - You will be notified even when app is closed'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Background location permission required'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      await BackgroundMonitor.stopMonitoring();
      setState(() => _backgroundMonitoring = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Background monitoring OFF'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _initializeServices() async {
    await _locationService.requestPermissions();
    _locationService.startListening();
  }

  Future<void> _addDestination() async {
    final result = await Navigator.push<Destination>(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );

    if (result != null) {
      final destinationService = Provider.of<DestinationService>(
        context, 
        listen: false
      );
      await destinationService.addDestination(result);
      await _vibration.vibrateSuccess();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                EmojiIcons.success(color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${result.displayName} added successfully!'),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _showDestinationDetails(Destination destination) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // IMPORTANT: Allows scrolling
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Title section
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: EmojiIcons.location(color: Theme.of(context).primaryColor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            destination.displayName,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Added ${_formatDate(destination.createdAt)}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info rows
                        _buildInfoRow(EmojiIcons.address(size: 20, color: Colors.grey[600]), 'Address', destination.address),
                        _buildInfoRow(EmojiIcons.radius(size: 20, color: Colors.grey[600]), 'Detection Radius', '${destination.radius}m'),
                        _buildInfoRow(EmojiIcons.coordinates(size: 20, color: Colors.grey[600]), 'Coordinates', 
                            '${destination.latitude.toStringAsFixed(4)}, ${destination.longitude.toStringAsFixed(4)}'),
                        
                        // Vibration pattern
                        _buildPatternRow(destination),
                        const SizedBox(height: 16),
                        
                        // Voice announcement toggle
                        _buildVoiceToggle(destination),
                        const SizedBox(height: 16),

                        // Todo section
                        Consumer<TodoService>(
                          builder: (context, todoService, child) {
                            final pendingCount = todoService.getPendingTodos(destination.id).length;
                            final totalCount = todoService.getTodosForDestination(destination.id).length;
                            
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: pendingCount > 0 
                                          ? Colors.orange.withOpacity(0.1)
                                          : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.checklist,
                                      color: pendingCount > 0 ? Colors.orange : Colors.grey,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Tasks',
                                          style: TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                        Text(
                                          totalCount == 0
                                              ? 'No tasks added'
                                              : '$pendingCount of $totalCount pending',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                            color: pendingCount > 0 ? Colors.orange : Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _showAddTodoDialog(destination);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.visibility),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _showTodoList(destination);
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Action buttons - fixed at bottom
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: EmojiIcons.close(),
                        label: const Text('Close'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LiveMapScreen(initialDestination: destination),
                            ),
                          );
                        },
                        icon: EmojiIcons.viewOnMap(),
                        label: const Text('View on Map'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildVoiceToggle(Destination destination) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: destination.voiceEnabled 
                  ? Colors.green.withOpacity(0.1) 
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: destination.voiceEnabled 
            ? EmojiIcons.voiceOnSmall(color: Colors.green)
            : EmojiIcons.voiceOffSmall(color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Voice Announcement',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  destination.voiceEnabled 
                      ? 'On - Will speak arrival' 
                      : 'Off - Vibrate only',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: destination.voiceEnabled ? Colors.green : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: destination.voiceEnabled,
            onChanged: (value) async {
              final destinationService = Provider.of<DestinationService>(
                context, 
                listen: false
              );
              
              final updated = Destination(
                id: destination.id,
                customName: destination.customName,
                latitude: destination.latitude,
                longitude: destination.longitude,
                address: destination.address,
                createdAt: destination.createdAt,
                radius: destination.radius,
                isActive: destination.isActive,
                vibrationPattern: destination.vibrationPattern,
                voiceEnabled: value,
              );
              
              await destinationService.removeDestination(destination.id);
              await destinationService.addDestination(updated);
              
              if (value) {
                VoiceService().testVoice(destination.displayName);
              }
              
              Navigator.pop(context);
            },
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(Widget icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          icon,
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxWidth: 250),
                child: Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPatternRow(Destination destination) {
    return GestureDetector(
      onTap: () async {
        final result = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => VibrationPicker(
            currentPattern: destination.vibrationPattern,
            onPatternSelected: (newPattern) {
              Navigator.pop(context, newPattern); // Return the pattern
            },
          ),
        );

        if (result != null && result != destination.vibrationPattern) {
          final destinationService = Provider.of<DestinationService>(
            context, 
            listen: false
          );
          
          final updated = Destination(
            id: destination.id,
            customName: destination.customName,
            latitude: destination.latitude,
            longitude: destination.longitude,
            address: destination.address,
            createdAt: destination.createdAt,
            radius: destination.radius,
            isActive: destination.isActive,
            vibrationPattern: result,
            voiceEnabled: destination.voiceEnabled,
          );
          
          await destinationService.removeDestination(destination.id);
          await destinationService.addDestination(updated);
          
          _vibration.vibrateSuccess();
          
          // Show confirmation
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Vibration pattern updated to $result'),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: EmojiIcons.vibration(color: Colors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vibration Pattern',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    destination.vibrationPattern,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            EmojiIcons.chevronRight(color: Colors.grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      extendBody: false,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.radar_rounded,
                color: theme.colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'DestiMinder',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Consumer<DestinationService>(
                  builder: (context, service, _) {
                    final count = service.activeDestinations.length;
                    return Text(
                      count > 0
                          ? '$count destination${count > 1 ? 's' : ''} active'
                          : 'Ready to travel',
                      style: TextStyle(
                        fontSize: 11,
                        color: count > 0 ? theme.colorScheme.primary : theme.colorScheme.outline,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Background monitor toggle
          IconButton(
            icon: Icon(
              _backgroundMonitoring ? Icons.sync_rounded : Icons.sync_disabled_rounded,
              color: _backgroundMonitoring ? Colors.green : theme.colorScheme.onSurfaceVariant,
            ),
            tooltip: _backgroundMonitoring ? 'Background monitoring ON' : 'Background monitoring OFF',
            onPressed: _toggleBackgroundMonitoring,
          ),
          // Master Voice toggle
          IconButton(
            icon: Icon(
              _masterVoiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: _masterVoiceEnabled ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            ),
            tooltip: _masterVoiceEnabled ? 'Voice announcements ON' : 'Voice announcements OFF',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              setState(() {
                _masterVoiceEnabled = !_masterVoiceEnabled;
                VoiceService.masterEnabled = _masterVoiceEnabled;
              });
              await prefs.setBool('master_voice_enabled', _masterVoiceEnabled);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_masterVoiceEnabled ? 'Voice announcements ON' : 'Voice announcements OFF'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          // History button
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Arrival History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Consumer<DestinationService>(
        builder: (context, destinationService, child) {
          final destinations = destinationService.destinations;
          final activeCount = destinationService.activeDestinations.length;
          
          return SlidingUpPanel(
            controller: _panelController,
            minHeight: 140,
            maxHeight: MediaQuery.of(context).size.height * 0.78,
            panelSnapping: true,
            parallaxEnabled: true,
            parallaxOffset: 0.4,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
            header: Container(
              width: MediaQuery.of(context).size.width,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            panelBuilder: (scrollController) => Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Text(
                          'Your Destinations',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (activeCount > 0)
                          IconButton(
                            icon: EmojiIcons.notificationsOff(),
                            onPressed: () async {
                              await destinationService.deactivateAll();
                              await _vibration.vibrateSuccess();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('All destinations deactivated'),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(12)),
                                  ),
                                ),
                              );
                            },
                            tooltip: 'Deactivate all',
                          ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            activeCount > 0 ? '$activeCount active' : '${destinations.length}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: activeCount > 0 
                                  ? theme.colorScheme.primary 
                                  : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: destinations.isEmpty
                        ? _buildEmptyState()
                        : _buildDestinationsList(destinations, destinationService),
                  ),
                ],
              ),
            ),
            body: _buildRealMapAndHeroSection(destinationService),
          );
        },
      ),
      
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDestination,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Add Destination'),
        elevation: 3,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: EmojiIcons.inactiveDestination(color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            'No destinations yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first destination',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationsList(
    List<Destination> destinations,
    DestinationService service,
  ) {
    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        itemCount: destinations.length,
        itemBuilder: (context, index) {
          final destination = destinations[index];
          final liveDistance = _distances[destination.id];
          
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: DestinationCard(
                  destination: destination,
                  onTap: () {
                    _showDestinationDetails(destination);
                  },
                  onDelete: () async {
                    await service.removeDestination(destination.id);
                    await _vibration.vibrateSuccess();
                  },
                  onToggleActive: (value) async {
                    await service.toggleActive(destination.id);
                    await _vibration.vibrateSuccess();
                    
                    final activeCount = service.activeDestinations.length;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          activeCount == 0
                              ? 'No active destinations'
                              : '$activeCount destination${activeCount > 1 ? 's' : ''} active',
                        ),
                        behavior: SnackBarBehavior.floating,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  liveDistance: liveDistance,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRealMapAndHeroSection(DestinationService destinationService) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeDestinations = destinationService.activeDestinations;

    // Default location (current location or fallback)
    final currentLatLng = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : (activeDestinations.isNotEmpty
            ? LatLng(activeDestinations.first.latitude, activeDestinations.first.longitude)
            : const LatLng(9.9312, 76.2673));

    // Find nearest active destination
    Destination? nearestDest;
    double? minDistance;
    for (var dest in activeDestinations) {
      final d = _distances[dest.id];
      if (d != null) {
        if (minDistance == null || d < minDistance) {
          minDistance = d;
          nearestDest = dest;
        }
      }
    }
    nearestDest ??= activeDestinations.isNotEmpty ? activeDestinations.first : null;


    return Stack(
      children: [
        // 1. Real interactive/ambient map
        Positioned.fill(
          bottom: 110,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: currentLatLng,
              initialZoom: activeDestinations.isNotEmpty ? 13.5 : 15.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // OSM tiles — dark mode uses ColorFilter invert (no API key needed)
              if (isDark)
                ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    -1,  0,  0, 0, 255,
                     0, -1,  0, 0, 255,
                     0,  0, -1, 0, 255,
                     0,  0,  0, 1,   0,
                  ]),
                  child: TileLayer(
                    key: const ValueKey('home-dark'),
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    tileProvider: CachedTileProvider(),
                    userAgentPackageName: 'com.sooraj.destiminder',
                  ),
                )
              else
                TileLayer(
                  key: const ValueKey('home-light'),
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  tileProvider: CachedTileProvider(),
                  userAgentPackageName: 'com.sooraj.destiminder',
                ),
              // Radius geofence circles for active destinations
              CircleLayer(
                circles: activeDestinations.map((dest) {
                  return CircleMarker(
                    point: LatLng(dest.latitude, dest.longitude),
                    radius: dest.radius,
                    useRadiusInMeter: true,
                    color: theme.colorScheme.primary.withValues(alpha: 0.18),
                    borderColor: theme.colorScheme.primary,
                    borderStrokeWidth: 2,
                  );
                }).toList(),
              ),
              // Marker pins
              MarkerLayer(
                markers: [
                  // User location pulsing marker
                  if (_currentPosition != null)
                    Marker(
                      point: currentLatLng,
                      width: 48,
                      height: 48,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        ),
                        child: Center(
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.primary,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Destination numbered pins
                  ...activeDestinations.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final dest = entry.value;
                    return Marker(
                      point: LatLng(dest.latitude, dest.longitude),
                      width: 42,
                      height: 42,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '${idx + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
                  
        // 2. Active Travel Hero Card at top
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: nearestDest != null
              ? _buildActiveHeroCard(nearestDest, minDistance)
              : _buildInactiveHeroCard(),
        ),

        // 3. Arrival alerts
        ..._arrivedDestinations.map((id) {
          try {
            final destination = destinationService.destinations.firstWhere(
              (d) => d.id == id,
            );
            return _buildArrivalCard(destination);
          } catch (e) {
            return const SizedBox.shrink();
          }
        }),
      ],
    );
  }

  Widget _buildActiveHeroCard(Destination dest, double? distance) {
    final theme = Theme.of(context);
    final distText = distance != null
        ? (distance < 1000 ? '${distance.toStringAsFixed(0)}m away' : '${(distance / 1000).toStringAsFixed(1)}km away')
        : 'Calculating...';
    final isArriving = distance != null && distance <= dest.radius;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isArriving
                  ? Colors.green
                  : theme.colorScheme.outline.withValues(alpha: 0.2),
              width: isArriving ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isArriving
                      ? Colors.green.withValues(alpha: 0.15)
                      : theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isArriving ? Icons.celebration_rounded : Icons.navigation_rounded,
                  color: isArriving ? Colors.green : theme.colorScheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dest.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          distText,
                          style: TextStyle(
                            color: isArriving ? Colors.green : theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${dest.vibrationPattern}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.fullscreen_rounded),
                tooltip: 'Open Live Map',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LiveMapScreen(initialDestination: dest),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInactiveHeroCard() {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: theme.colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No active destinations • Toggle switch to track',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArrivalCard(Destination destination) {
    return Consumer<TodoService>(
      builder: (context, todoService, child) {
        final pendingCount = todoService.getPendingTodos(destination.id).length;
        
        return Positioned(
          top: 100,
          left: 16,
          right: 16,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      EmojiIcons.emojiEmotions(color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Arrived at ${destination.displayName}!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _arrivedDestinations.remove(destination.id);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    destination.address,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  // Todo section
                  if (pendingCount > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.checklist, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$pendingCount pending task${pendingCount > 1 ? 's' : ''}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _showTodoList(destination),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.white.withOpacity(0.2),
                            ),
                            child: const Text('View Tasks'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _stopLocationTracking();
    
    // Remove listener
    try {
      final destinationService = Provider.of<DestinationService>(context, listen: false);
      destinationService.removeListener(_onDestinationsChanged);
    } catch (e) {
      // Context might be unavailable during dispose
    }
    
    _fabAnimationController.dispose();
    super.dispose();
  }
}

class CachedTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'dart:async';
import 'dart:math';  
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
      extendBody: true,
      body: Consumer<DestinationService>(
        builder: (context, destinationService, child) {
          final destinations = destinationService.destinations;
          final activeCount = destinationService.activeDestinations.length;
          
          return SlidingUpPanel(
            controller: _panelController,
            minHeight: 120,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            panelSnapping: true,
            parallaxEnabled: true,
            parallaxOffset: 0.5,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(30),
            ),
            header: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
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
                  top: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
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
            body: _buildMapPlaceholder(activeCount),
          );
        },
      ),
      
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDestination,
        icon: EmojiIcons.addLocation(),
        label: const Text('Add Destination'),
        elevation: 4,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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

  Widget _buildMapPlaceholder(int activeCount) {
    return Consumer<DestinationService>(
      builder: (context, destinationService, child) {
        final activeDestinations = destinationService.activeDestinations;
        
        return Stack(
          children: [
            // Background map
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade900,
                    Colors.blue.shade600,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Stack(
                children: [
                  // Mini map view with destinations
                  if (activeDestinations.isNotEmpty && _currentPosition != null)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: MiniMapPainter(
                          destinations: activeDestinations,
                          currentLocation: _currentPosition,
                        ),
                      ),
                    ),
                  
                  // Destinations indicators
                  ...activeDestinations.asMap().entries.map((entry) {
                    final index = entry.key;
                    final dest = entry.value;
                    
                    // Calculate real distance if we have current position
                    String distanceText = '';
                    if (_currentPosition != null) {
                      // 👇 USE _distances MAP INSTEAD OF DIRECT CALCULATION
                      if (_distances.containsKey(dest.id)) {
                        final distance = _distances[dest.id]!;
                        if (distance < 1000) {
                          distanceText = '${distance.toStringAsFixed(0)}m';
                        } else {
                          distanceText = '${(distance/1000).toStringAsFixed(1)}km';
                        }
                      } else {
                        // Fallback to direct calculation if not in _distances
                        final distance = Geolocator.distanceBetween(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                          dest.latitude,
                          dest.longitude,
                        );
                        
                        if (distance < 1000) {
                          distanceText = '${distance.toStringAsFixed(0)}m';
                        } else {
                          distanceText = '${(distance/1000).toStringAsFixed(1)}km';
                        }
                      }
                    }
                    
                    // Position them in a circle around the center
                    final angle = (index * 2 * pi / max(activeDestinations.length, 1));
                    final radius = 120.0;
                    final left = MediaQuery.of(context).size.width / 2 + 
                                radius * cos(angle) - 25;
                    final top = 200 + radius * sin(angle) - 25;
                    
                    return Positioned(
                      left: left,
                      top: top,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.9),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          if (distanceText.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                distanceText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  
                  // Center - your location
                  Positioned(
                    left: MediaQuery.of(context).size.width / 2 - 25,
                    top: 175,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
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
                                blurRadius: 15,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child:Center(
                            child: EmojiIcons.myLocation(color: Colors.white),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'YOU',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Info text overlay
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (activeDestinations.isEmpty) ...[
                          EmojiIcons.coordinates(size: 80, color: Colors.white.withOpacity(0.2)),
                          const SizedBox(height: 16),
                          const Text(
                            'No active destinations',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 300),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              '$activeCount destination${activeCount > 1 ? 's' : ''} active',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap destination card to view on map',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            ..._arrivedDestinations.map((id) {
              try {
                final destination = destinationService.destinations.firstWhere(
                  (d) => d.id == id,
                );
                return _buildArrivalCard(destination);
              } catch (e) {
                // Destination not found, return empty widget
                return const SizedBox.shrink();
              }
            }).toList(),
            
            // App bar (keep existing)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Left side - App title
                    Row(
                      children: [
                        const Text(
                          'DestiMinder',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    
                    // Right side - Buttons
                    Flexible(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Background monitor toggle
                          Container(
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: _backgroundMonitoring 
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: _backgroundMonitoring 
                              ? EmojiIcons.backgroundOn(color: Colors.green) 
                              : EmojiIcons.backgroundOff(color: Colors.white),
                              onPressed: _toggleBackgroundMonitoring,
                              tooltip: _backgroundMonitoring 
                                  ? 'Background monitoring ON' 
                                  : 'Background monitoring OFF',
                            ),
                          ),
                          
                          // Voice master toggle
                          Container(
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: _masterVoiceEnabled 
                              ? EmojiIcons.voiceOn(color: Colors.white)
                              : EmojiIcons.voiceOff(color: Colors.white),
                              onPressed: () async {
                                final prefs = await SharedPreferences.getInstance();
                                setState(() {
                                  _masterVoiceEnabled = !_masterVoiceEnabled;
                                  VoiceService.masterEnabled = _masterVoiceEnabled;
                                });
                                await prefs.setBool('master_voice_enabled', _masterVoiceEnabled);
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _masterVoiceEnabled 
                                          ? 'Voice announcements ON' 
                                          : 'Voice announcements OFF',
                                    ),
                                    duration: const Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                          ),
                          
                          // History button
                          Container(
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: EmojiIcons.history(color: Colors.white),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                                );
                              },
                            ),
                          ),
                          
                          // Notification badge
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Badge(
                              isLabelVisible: activeCount > 0,
                              label: Text('$activeCount'),
                              child: EmojiIcons.notifications(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
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

class MiniMapPainter extends CustomPainter {
  final List<Destination> destinations;
  final Position? currentLocation;

  MiniMapPainter({required this.destinations, required this.currentLocation});

  @override
  void paint(Canvas canvas, Size size) {
    if (destinations.isEmpty || currentLocation == null) return;

    final center = Offset(size.width / 2, 200);
    final radius = 120.0;
    
    // Paint for lines
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Paint for distance text background
    final textBgPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < destinations.length; i++) {
      final dest = destinations[i];
      final angle = (i * 2 * pi / destinations.length);
      final destOffset = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      
      // Draw line from center to destination
      canvas.drawLine(center, destOffset, linePaint);
      
      // Calculate real distance
      final distance = Geolocator.distanceBetween(
        currentLocation!.latitude,
        currentLocation!.longitude,
        dest.latitude,
        dest.longitude,
      );
      
      // Format distance text
      String distanceText;
      if (distance < 1000) {
        distanceText = '${distance.toStringAsFixed(0)}m';
      } else {
        distanceText = '${(distance/1000).toStringAsFixed(1)}km';
      }
      
      // Draw distance label on the line
      final textSpan = TextSpan(
        text: distanceText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      final textOffset = Offset(
        (center.dx + destOffset.dx) / 2 - textPainter.width / 2,
        (center.dy + destOffset.dy) / 2 - 10,
      );
      
      // Draw background for text
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            textOffset.dx - 4,
            textOffset.dy - 2,
            textPainter.width + 8,
            textPainter.height + 4,
          ),
          const Radius.circular(8),
        ),
        textBgPaint,
      );
      
      textPainter.paint(canvas, textOffset);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
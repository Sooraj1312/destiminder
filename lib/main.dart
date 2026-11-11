import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/destination_service.dart';
import 'services/history_service.dart';
import 'services/notification_service.dart';
import 'services/background_monitor.dart';
import 'services/todo_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
    }

    // Initialize native services
    await NotificationService().initialize();
    await BackgroundMonitor.initialize(); // Initialize background service

    // Request permissions
    await Permission.location.request();
    await Permission.notification.request();
    await Permission.locationAlways.request();
  }

  final destinationService = DestinationService();
  final historyService = HistoryService();
  final todoService = TodoService();
  final authService = AuthService();
  final cloudSyncService = CloudSyncService(
    destinationService: destinationService,
    historyService: historyService,
    todoService: todoService,
  );

  destinationService.onLocalChange = cloudSyncService.schedulePush;
  historyService.onLocalChange = cloudSyncService.schedulePush;
  todoService.onLocalChange = cloudSyncService.schedulePush;

  runApp(
    DestiMinderApp(
      destinationService: destinationService,
      historyService: historyService,
      todoService: todoService,
      authService: authService,
      cloudSyncService: cloudSyncService,
    ),
  );
}

class DestiMinderApp extends StatelessWidget {
  const DestiMinderApp({
    super.key,
    required this.destinationService,
    required this.historyService,
    required this.todoService,
    required this.authService,
    required this.cloudSyncService,
  });

  final DestinationService destinationService;
  final HistoryService historyService;
  final TodoService todoService;
  final AuthService authService;
  final CloudSyncService cloudSyncService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: destinationService),
        ChangeNotifierProvider.value(value: historyService),
        ChangeNotifierProvider.value(value: todoService),
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider.value(value: cloudSyncService),
      ],
      child: MaterialApp(
        title: 'DestiMinder',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2563EB),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: false,
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3B82F6),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: false,
          ),
        ),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_screen.dart';
import 'services/destination_service.dart';
import 'services/history_service.dart';
import 'services/notification_service.dart';
import 'services/background_monitor.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  await NotificationService().initialize();
  await BackgroundMonitor.initialize(); // Initialize background service
  
  // Request permissions
  await Permission.location.request();
  await Permission.notification.request();
  await Permission.locationAlways.request();
  
  runApp(const DestiMinderApp());
}

class DestiMinderApp extends StatelessWidget {
  const DestiMinderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DestinationService()),
        ChangeNotifierProvider(create: (_) => HistoryService()),
      ],
      child: MaterialApp(
        title: 'DestiMinder',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
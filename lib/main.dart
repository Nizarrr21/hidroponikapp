import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'services/schedule_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  
  runApp(const HydroponicApp());
}

class HydroponicApp extends StatefulWidget {
  const HydroponicApp({super.key});

  @override
  State<HydroponicApp> createState() => _HydroponicAppState();
}

class _HydroponicAppState extends State<HydroponicApp> {
  final ScheduleService _scheduleService = ScheduleService();

  @override
  void initState() {
    super.initState();
    // Start the schedule engine when app starts
    _scheduleService.startScheduleEngine();
    print('🚀 Hydroponic App initialized with Schedule Engine');
  }

  @override
  void dispose() {
    _scheduleService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hydroponic Controller',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
import 'package:flutter/material.dart';
import 'dart:async';

import 'login_screen.dart';
import 'main_shell.dart';
import 'services/location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DistanceManager().initialize();
  runApp(const HejbejSeApp());
}

class HejbejSeApp extends StatefulWidget {
  const HejbejSeApp({super.key});

  @override
  State<HejbejSeApp> createState() => _HejbejSeAppState();
}

class _HejbejSeAppState extends State<HejbejSeApp> {
  final LocationService _locationService = LocationService();
  late StreamSubscription<double> _locationSubscription;

  @override
  void initState() {
    super.initState();
    _initializeLocationTracking();
  }

  Future<void> _initializeLocationTracking() async {
    // Check if location services are enabled
    final serviceEnabled = await _locationService.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Povolte služby polohy pro sledování vzdálenosti')),
        );
      }
      return;
    }

    // Request permission
    final permissionGranted = await _locationService.requestLocationPermission();
    if (!permissionGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Povolení k poloze je vyžadováno pro sledování')),
        );
      }
      return;
    }

    // Start tracking
    _locationSubscription = _locationService.positionStream.listen((distanceKm) async {
      if (distanceKm > 0) {
        await DistanceManager().addDistance(distanceKm);
        // Notify listeners that distance has changed
        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _locationSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: Colors.lightBlue,
      brightness: Brightness.light,
    ).copyWith(
      secondary: Colors.lime,
      secondaryContainer: Colors.lime.shade100,
      surface: Colors.white,
      surfaceVariant: Colors.lightBlue.shade50,
    );

    return MaterialApp(
      title: 'Hejbej se',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light, // Disable dark mode globally
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightColorScheme,
        scaffoldBackgroundColor: Colors.white,
        canvasColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.lightBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.lightBlue.shade50,
          indicatorColor: Colors.lime.withOpacity(0.28),
          height: 70,
          labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
            return TextStyle(
              color: states.contains(WidgetState.selected)
                  ? Colors.lime
                  : Colors.lightBlue.shade700,
              fontWeight: FontWeight.w700,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
            return IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? Colors.lime
                  : Colors.lightBlue.shade700,
              size: states.contains(WidgetState.selected) ? 32 : 28,
            );
          }),
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.pressed)) {
                return Colors.lime.shade700;
              }
              return Colors.lime;
            }),
            foregroundColor: WidgetStateProperty.all(Colors.black),
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
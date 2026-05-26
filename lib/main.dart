import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';
import 'main_shell.dart';
import 'services/location_service.dart';
import 'features/auth/avatar_selection_screen.dart';
import 'services/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Firebase init error: $e');
    }
  }

  try {
    await DistanceManager().initialize();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('DistanceManager init error: $e');
    }
  }

  // Check if avatar is selected
  String? selectedAvatar;
  try {
    final prefs = await SharedPreferences.getInstance();
    selectedAvatar = prefs.getString('selected_avatar');
  } catch (e) {
    if (kDebugMode) {
      debugPrint('SharedPreferences error: $e');
    }
  }

  // Check secure storage for saved logged-in user
  String? savedUser;
  try {
    savedUser = await AuthService().getUserName();
  } catch (e) {
    if (kDebugMode) {
      debugPrint('AuthService error: $e');
    }
  }

  if (kDebugMode) {
    debugPrint('Saved user: $savedUser');
  }

  runApp(HejbejSeApp(hasSelectedAvatar: selectedAvatar != null, initialUserName: savedUser));
}

class HejbejSeApp extends StatefulWidget {
  const HejbejSeApp({super.key, required this.hasSelectedAvatar, this.initialUserName});

  final bool hasSelectedAvatar;
  final String? initialUserName;

  @override
  State<HejbejSeApp> createState() => _HejbejSeAppState();
}

class _HejbejSeAppState extends State<HejbejSeApp> {
  final LocationService _locationService = LocationService();
  late StreamSubscription<double> _locationSubscription;

  @override
  void initState() {
    super.initState();
    // Defer location initialization to next frame to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocationTracking();
    });
  }

  Future<void> _initializeLocationTracking() async {
    if (!mounted) return;
    
    try {
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

      if (!mounted) return;

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
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Location init error: $e');
      }
    }
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
      secondary: const Color(0xFFBFFF00), // Lime Accent
      secondaryContainer: const Color(0xFFBFFF00).withOpacity(0.1),
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
      home: widget.initialUserName != null
          ? MainShell(userName: widget.initialUserName!)
          : (widget.hasSelectedAvatar ? const LoginScreen() : const AvatarSelectionScreen()),
    );
  }
}
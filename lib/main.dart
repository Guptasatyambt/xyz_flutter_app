import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'core/navigation/app_navigator.dart';
import 'core/services/auth_service.dart';
import 'core/models/ride_models.dart';
import 'core/socket/socket_manager.dart';
import 'screens/auth/phone_entry_screen.dart';
import 'rider/services/ride_service.dart';
import 'rider/screens/active_ride_screen.dart';
import 'rider/screens/rider_shell.dart';
import 'driver/screens/home_screen.dart';
import 'secrets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MapboxOptions.setAccessToken(mapboxPublicToken);
  runApp(const CabApp());
}

class CabApp extends StatelessWidget {
  const CabApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Register the session-expired callback — navigates to login from anywhere.
    onSessionExpired = () {
      SocketManager.instance.disconnectAll();
      appNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PhoneEntryScreen()),
        (_) => false,
      );
    };

    return MaterialApp(
      title: 'QuickRide',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A1A2E)),
        useMaterial3: true,
      ),
      home: const _StartupGate(),
    );
  }
}

/// Checks stored session on first launch and routes accordingly.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final loggedIn = await AuthService.isLoggedIn();
    if (!mounted) return;
    if (!loggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PhoneEntryScreen()),
      );
      return;
    }
    try {
      final user = await AuthService.getMe();
      if (!mounted) return;
      // Open the appropriate socket namespace for this user's role.
      if (user.role == 'DRIVER') {
        unawaited(SocketManager.instance.connectDriver());
      } else if (user.role == 'RIDER') {
        unawaited(SocketManager.instance.connectRider());
      }
      if (user.role == 'DRIVER') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
        );
      } else {
        // For riders: check for an active ride and resume it directly.
        Ride? activeRide;
        try {
          activeRide = await RideService.getActiveRide();
        } catch (_) {}
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => activeRide != null
                ? ActiveRideScreen(initialRide: activeRide)
                : const RiderShell(),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PhoneEntryScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const _SplashScreen();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1A1A2E),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_taxi, color: Colors.white, size: 64),
            SizedBox(height: 16),
            Text(
              'QuickRide',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:heric_webapp/core/providers/location_provider.dart';
import 'package:heric_webapp/features/auth/providers/auth_provider.dart';
import 'package:heric_webapp/features/auth/screens/login_screen.dart';
import 'package:heric_webapp/features/dashboard/screens/dashboard_screen.dart';
import 'package:heric_webapp/shared/layouts/geofence_wrapper.dart';
import 'package:provider/provider.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);

    bool isLoggedIn = await authProvider.initializeAuth();

    if (isLoggedIn && mounted) {
      // 🚀 THE FIX: Pass both the Role AND the Branch ID to the location tracker!
      locationProvider.startTracking(
        authProvider.userRole ?? 'STAFF',
        authProvider.currentUser?.branchId, // Passes the dynamic branch ID
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        
        if (authProvider.isInitializing) {
          return const Scaffold(
            backgroundColor: Color(0xFF2C2C2C),
            body: Center(
              child: CircularProgressIndicator(color: Colors.amber),
            ),
          );
        }

        if (authProvider.currentUser == null) {
          return const LoginScreen();
        }

        return const GeofenceWrapper(
          child: DashboardScreen(), 
        );
      },
    );
  }
}
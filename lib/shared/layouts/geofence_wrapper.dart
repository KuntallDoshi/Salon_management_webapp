import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/location_provider.dart';
import '../../features/auth/providers/auth_provider.dart';

class GeofenceWrapper extends StatelessWidget {
  final Widget child;

  const GeofenceWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final locationProvider = context.watch<LocationProvider>();

    final role = (authProvider.userRole ?? 'STAFF').toUpperCase();

    // // 1. ADMIN BYPASS
    // if (role == 'ADMIN' || role == 'OWNER') {
    //   return child;
    // }
    // 1. 🚨 TESTING OVERRIDE: Let EVERYONE bypass the GPS lock
    if (role == 'ADMIN' || role == 'OWNER' || role == 'STAFF' || role == 'MANAGER') {
      return child;
    }

    // 2. PREMIUM LOADING STATE
    if (locationProvider.isChecking) {
      return Stack(
        children: [
          child,
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: AppColors.primaryBlack.withOpacity(0.75),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.primaryGold, strokeWidth: 3),
                      const SizedBox(height: 24),
                      const Text(
                        'VERIFYING LOCATION...',
                        style: TextStyle(color: AppColors.primaryGold, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 3),
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(begin: 0.4, end: 1.0, duration: 800.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // If inside radius, show app!
    if (locationProvider.isInsideBranch) {
      return child;
    }

    // 3. THE PREMIUM LOCK SCREEN
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(color: AppColors.primaryBlack.withOpacity(0.85)),
          ),
        ),
        Center(
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 40, offset: const Offset(0, 20))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.location_off_rounded, size: 56, color: Colors.redAccent),
                ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                 .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 1.seconds),
                
                const SizedBox(height: 32),
                
                const Text('OUTSIDE WORK ZONE', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppColors.primaryBlack)),
                const SizedBox(height: 16),
                
                Text(
                  'You must be near your assigned branch to access the salon system.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade800, height: 1.5, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withOpacity(0.3))),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text('If you are at the salon, make sure Location Permissions are allowed in your browser settings (site settings) and GPS is turned on.', style: TextStyle(color: Colors.orange.shade800, fontSize: 12))),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlack,
                      foregroundColor: AppColors.primaryGold,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    // 🚀 THE FIX: Passed the branchId to startTracking!
                    onPressed: () => locationProvider.startTracking(role, authProvider.currentUser?.branchId),
                    icon: const Icon(Icons.my_location, size: 20),
                    label: const Text('VERIFY LOCATION', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await authProvider.logout();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                    }
                  },
                  child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                )
              ],
            ),
          ).animate().fade(duration: 500.ms).scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
        )
      ],
    );
  }
}
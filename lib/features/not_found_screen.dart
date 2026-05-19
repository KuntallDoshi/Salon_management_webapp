import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

// Make sure this path matches where your AppColors is located!
import '../../../core/constants/app_colors.dart'; 

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ─── GIANT ANIMATED 404 ───
              Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '404',
                    style: TextStyle(
                      fontSize: 180,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey.shade200,
                      letterSpacing: 10,
                    ),
                  ),
                  const Positioned(
                    bottom: 40,
                    child: Icon(
                      Icons.content_cut, // A subtle nod to the salon!
                      size: 80,
                      color: AppColors.primaryGold,
                    ),
                  ),
                ],
              ).animate().fade(duration: 800.ms).scale(curve: Curves.easeOutBack),
              
              const SizedBox(height: 24),
              
              // ─── TEXT MESSAGE ───
              const Text(
                'Oops! Looks like a bad cut.',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlack,
                ),
                textAlign: TextAlign.center,
              ).animate().fade(delay: 300.ms).slideY(begin: 0.2),
              
              const SizedBox(height: 16),
              
              Text(
                'The page you are looking for does not exist or has been moved.\nLet\'s get you back to the main salon.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ).animate().fade(delay: 500.ms).slideY(begin: 0.2),
              
              const SizedBox(height: 40),
              
              // ─── RETURN BUTTON ───
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlack,
                  foregroundColor: AppColors.primaryGold,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 10,
                  shadowColor: AppColors.primaryBlack.withOpacity(0.3),
                ),
                onPressed: () {
                  // Push back to dashboard and clear the bad route history
                  Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text(
                  'RETURN TO DASHBOARD',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
                ),
              ).animate().fade(delay: 700.ms).slideY(begin: 0.2),
            ],
          ),
        ),
      ),
    );
  }
}
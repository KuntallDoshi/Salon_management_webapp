import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  bool _otpSent = false;
  
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _obscureText = true;

  void _showFeedback(String message, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: success ? Colors.green.shade700 : Colors.redAccent.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1024;
    final isTablet = size.width >= 600 && size.width < 1024;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), // Deep Charcoal matching login
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryGold),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            width: isDesktop ? 550 : (isTablet ? 450 : size.width),
            padding: EdgeInsets.all(isDesktop || isTablet ? 48.0 : 32.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 40, offset: const Offset(0, 20))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock_reset, size: 64, color: AppColors.primaryGold).animate().scale(delay: 200.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 24),
                
                Text(
                  _otpSent ? 'Create New Password' : 'Reset Password',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: isDesktop ? 32 : 26, fontWeight: FontWeight.w800, color: AppColors.primaryBlack),
                ),
                const SizedBox(height: 8),
                Text(
                  _otpSent 
                      ? 'Enter the 6-digit OTP sent to your email and your new password.'
                      : 'Enter your registered email address to receive a 6-digit verification code.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 40),

                if (!_otpSent) ...[
                  // STEP 1: EMAIL ENTRY
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                      filled: true, fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryGold, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, padding: const EdgeInsets.symmetric(vertical: 22), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: isLoading ? null : () async {
                      if (_emailController.text.isEmpty || !_emailController.text.contains('@')) {
                        _showFeedback('Please enter a valid email address.', false);
                        return;
                      }
                      String? err = await context.read<AuthProvider>().requestPasswordReset(_emailController.text);
                      if (err == null) {
                        setState(() => _otpSent = true);
                        _showFeedback('OTP sent! Please check your inbox.', true);
                      } else {
                        _showFeedback(err, false);
                      }
                    },
                    child: isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.primaryGold, strokeWidth: 2))
                        : const Text('SEND OTP', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ),
                ] else ...[
                  // STEP 2: OTP & NEW PASSWORD
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: '6-Digit OTP',
                      prefixIcon: const Icon(Icons.dialpad, color: Colors.grey),
                      filled: true, fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryGold, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      labelText: 'New Password (e.g. Salon@123)',
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                      suffixIcon: IconButton(icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: () => setState(() => _obscureText = !_obscureText)),
                      filled: true, fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryGold, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGold, padding: const EdgeInsets.symmetric(vertical: 22), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: isLoading ? null : () async {
                      if (_otpController.text.length != 6 || _passwordController.text.isEmpty) {
                        _showFeedback('Please enter a valid 6-digit OTP and Password.', false);
                        return;
                      }
                      String? err = await context.read<AuthProvider>().submitNewPassword(_otpController.text, _passwordController.text);
                      if (context.mounted) {
                        if (err == null) {
                          _showFeedback('Password reset successfully! You can now log in.', true);
                          Navigator.pop(context); // Back to login
                        } else {
                          _showFeedback(err, false);
                        }
                      }
                    },
                    child: isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.primaryBlack, strokeWidth: 2))
                        : const Text('RESET PASSWORD', style: TextStyle(color: AppColors.primaryBlack, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  ),
                ],
              ],
            ).animate().fade().slideY(begin: 0.1),
          ),
        ),
      ),
    );
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:heric_webapp/features/auth/screens/forgot_password_screen.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../../../core/providers/location_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isHoveringBtn = false;
  bool _obscureText = true;
  bool _initialBrandRevealComplete = false;
  bool _isSlowNetwork = false; // 🚀 PRODUCTION FIX: Tracks slow API wake-ups

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _initialBrandRevealComplete = true);
    });
  }

  void _handleLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);

    // 🚀 PRODUCTION FIX: Start a timer to warn users if the server is waking up
    Timer? slowNetworkTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && authProvider.isLoading) {
        setState(() => _isSlowNetwork = true);
      }
    });

    String? errorMessage = await authProvider.login(
      _emailController.text.trim(), 
      _passwordController.text.trim()
    );

    slowNetworkTimer.cancel(); // Cancel timer once request finishes
    if (mounted) setState(() => _isSlowNetwork = false); // Reset state

    if (mounted) {
      if (errorMessage == null) {
        final role = authProvider.userRole ?? 'staff';
        // Example of what it should look like in your LoginScreen if you do it there:
locationProvider.startTracking(
  authProvider.userRole ?? 'STAFF', 
  authProvider.currentUser?.branchId
);
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage, style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.redAccent.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1024;
    final isTablet = size.width >= 600 && size.width < 1024;
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF1E1E1E), Color(0xFF2E2411)],
              ),
            ),
          ),
          isDesktop 
            ? _buildDesktopLayout(size, isLoading)
            : _buildMobileTabletLayout(size, isTablet, isLoading),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(Size size, bool isLoading) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(48.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeInOutCubicEmphasized,
                  height: _initialBrandRevealComplete ? 160 : 300,
                  child: Image.asset('assets/herik_logo.png', fit: BoxFit.contain)
                      .animate().fade(duration: 1200.ms, curve: Curves.easeOut).scale(begin: const Offset(0.8, 0.8), end: const Offset(1.0, 1.0), duration: 1500.ms),
                ),
                if (_initialBrandRevealComplete) ...[
                  const SizedBox(height: 32),
                  const Text('ELEVATING YOUR STYLE', textAlign: TextAlign.center, style: TextStyle(color: AppColors.primaryGold, fontSize: 18, letterSpacing: 5.0, fontWeight: FontWeight.w600))
                      .animate().fade(delay: 300.ms).slideY(begin: 0.2),
                  const SizedBox(height: 8),
                  Text('The Premium Salon Experience', textAlign: TextAlign.center, style: TextStyle(color: AppColors.lightGold.withOpacity(0.7), fontSize: 14, letterSpacing: 1.5, fontWeight: FontWeight.w300))
                      .animate().fade(delay: 500.ms).slideY(begin: 0.2),
                ]
              ],
            ),
          ),
        ),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 800),
          opacity: _initialBrandRevealComplete ? 1.0 : 0.0,
          child: Container(
            width: size.width * 0.45,
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40, offset: const Offset(-10, 0))]),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _buildLoginForm(isLoading, true),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileTabletLayout(Size size, bool isTablet, bool isLoading) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Image.asset('assets/herik_logo.png', height: isTablet ? 120 : 90)
                  .animate().fade(duration: 1000.ms).scale(begin: const Offset(0.8, 0.8)),
            ),
            const SizedBox(height: 16),
            const Text('MANAGEMENT PORTAL', style: TextStyle(color: AppColors.primaryGold, fontSize: 12, letterSpacing: 4.0, fontWeight: FontWeight.bold)).animate().fade(delay: 500.ms),
            SizedBox(height: isTablet ? 48 : 32),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 800),
              opacity: _initialBrandRevealComplete ? 1.0 : 0.0,
              child: Container(
                width: isTablet ? 500 : size.width * 0.9,
                padding: EdgeInsets.all(isTablet ? 40 : 24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 30)],
                ),
                child: _buildLoginForm(isLoading, false),
              ),
            ).animate(delay: 800.ms).slideY(begin: 0.1),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm(bool isLoading, bool isDesktop) {
    final titleColor = isDesktop ? AppColors.primaryBlack : Colors.white;
    final subtitleColor = isDesktop ? Colors.grey.shade600 : Colors.grey.shade400;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Welcome Back', style: TextStyle(fontSize: isDesktop ? 36 : 28, fontWeight: FontWeight.w800, color: titleColor)),
        const SizedBox(height: 8),
        Text('Sign in to manage your branch.', style: TextStyle(color: subtitleColor, fontSize: 16)),
        SizedBox(height: isDesktop ? 48 : 32),
        
        _buildTextField(isDesktop, controller: _emailController, label: 'Email Address', icon: Icons.email_outlined),
        const SizedBox(height: 24),
        _buildTextField(isDesktop, controller: _passwordController, label: 'Password', icon: Icons.lock_outline, isPassword: true),
        
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPasswordScreen())),
            child: const Text('Forgot Password?', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.w600)),
          ),
        ),

        const SizedBox(height: 32),
        
        MouseRegion(
          onEnter: (_) => setState(() => _isHoveringBtn = true),
          onExit: (_) => setState(() => _isHoveringBtn = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.translationValues(0, _isHoveringBtn ? -3 : 0, 0),
            decoration: BoxDecoration(
              boxShadow: _isHoveringBtn ? [BoxShadow(color: AppColors.primaryGold.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))] : [],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 24),
                backgroundColor: AppColors.primaryGold,
                foregroundColor: AppColors.primaryBlack,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: isLoading ? null : _handleLogin,
              child: isLoading 
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: AppColors.primaryBlack, strokeWidth: 3))
                  : const Text('SIGN IN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
            ),
          ),
        ),

        // 🚀 PRODUCTION FIX: Waking up server notification
        if (_isSlowNetwork)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Text(
              'Waking up secure server. This may take up to 30s...', 
              textAlign: TextAlign.center, 
              style: TextStyle(color: AppColors.primaryGold.withOpacity(0.8), fontSize: 13, fontStyle: FontStyle.italic)
            ).animate().fade().slideY(begin: -0.2),
          )
      ],
    );
  }

  Widget _buildTextField(bool isDesktop, {required TextEditingController controller, required String label, required IconData icon, bool isPassword = false}) {
    final textColor = isDesktop ? AppColors.primaryBlack : Colors.white;
    final hintColor = isDesktop ? Colors.grey.shade600 : Colors.white54;
    final fillColor = isDesktop ? Colors.grey.shade50 : Colors.black.withOpacity(0.3);
    final borderColor = isDesktop ? Colors.grey.shade300 : Colors.white24;

    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscureText : false,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: hintColor),
        prefixIcon: Icon(icon, color: hintColor),
        suffixIcon: isPassword
            ? IconButton(icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility, color: hintColor), onPressed: () => setState(() => _obscureText = !_obscureText))
            : null,
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryGold, width: 2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
      ),
    );
  }
}
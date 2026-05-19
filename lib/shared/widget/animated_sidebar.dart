import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../features/auth/providers/auth_provider.dart';

class AnimatedSidebar extends StatelessWidget {
  final int currentIndex; // 🚀 Now passed directly from the URL Router
  
  const AnimatedSidebar({super.key, required this.currentIndex});

  void _navigateTo(BuildContext context, String routeName) {
    // If we are on mobile and the drawer is open, close it first
    if (Scaffold.of(context).hasDrawer && Scaffold.of(context).isDrawerOpen) {
      Navigator.pop(context);
    }
    // Change the URL!
    Navigator.pushReplacementNamed(context, routeName);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final accessibleRoutes = authProvider.currentUser?.accessibleRoutes ?? [];
    final isAdmin = authProvider.userRole == 'ADMIN' || authProvider.userRole == 'OWNER';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E1E1E), Color(0xFF2D2412)],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Image.asset('assets/herik_logo.png', height: 100)
                .animate()
                .fade(duration: 800.ms)
                .scale(curve: Curves.easeOutBack),
          ),
          const SizedBox(height: 12),
          const Text('MANAGEMENT',
                  style: TextStyle(
                      color: AppColors.primaryGold,
                      fontSize: 10,
                      letterSpacing: 4.0,
                      fontWeight: FontWeight.bold))
              .animate()
              .fade(delay: 300.ms)
              .slideY(begin: -0.5),
          const SizedBox(height: 48),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                
                // 🚀 DASHBOARD: FIXED! Removed the 'if' condition so it is ALWAYS visible for all users.
                _NavItem(
                  icon: Icons.dashboard_outlined, title: 'Dashboard',
                  isActive: currentIndex == 0, 
                  onTap: () => _navigateTo(context, '/dashboard'),
                ).animate().fade(delay: 300.ms).slideX(begin: -0.1),
                
                // 🚀 INVENTORY 
                if (isAdmin || accessibleRoutes.contains('Inventory'))
                  _NavItem(
                    icon: Icons.inventory_2_outlined, title: 'Inventory Management',
                    isActive: currentIndex == 1, 
                    onTap: () => _navigateTo(context, '/inventory'),
                  ).animate().fade(delay: 400.ms).slideX(begin: -0.1),
                
                // 🚀 VISITORS 
                if (isAdmin || accessibleRoutes.contains('Visitors'))
                  _NavItem(
                    icon: Icons.people_outline, title: 'Customer Management',
                    isActive: currentIndex == 2, 
                    onTap: () => _navigateTo(context, '/visitors'),
                  ).animate().fade(delay: 500.ms).slideX(begin: -0.1),
                
                // 🚀 SYSTEM MANAGEMENT 
                if (isAdmin || accessibleRoutes.contains('System Management'))
                  _NavItem(
                    icon: Icons.admin_panel_settings_outlined, title: 'System Management',
                    isActive: currentIndex == 3, 
                    onTap: () => _navigateTo(context, '/admin'),
                  ).animate().fade(delay: 600.ms).slideX(begin: -0.1),
                
                // 🚀 REVENUE 
                if (isAdmin || accessibleRoutes.contains('Revenue'))
                  _NavItem(
                    icon: Icons.account_balance_wallet_outlined, title: 'Revenue',
                    isActive: currentIndex == 4, 
                    onTap: () => _navigateTo(context, '/revenue'), 
                  ).animate().fade(delay: 700.ms).slideX(begin: -0.1),
              ],
            ),
          ),
          
          const Divider(color: Colors.white12),
          
          // 🚀 PROFILE
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _NavItem(
              icon: Icons.person_outline,
              title: 'My Profile',
              isActive: currentIndex == 5, 
              onTap: () => _navigateTo(context, '/profile'),
            ).animate().fade(delay: 750.ms),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _NavItem(
                icon: Icons.logout,
                title: 'Logout',
                isActive: false,
                isLogout: true,
                onTap: () async {
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                  }
                }).animate().fade(delay: 800.ms),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final bool isActive;
  final VoidCallback onTap;
  final bool isLogout;

  const _NavItem({required this.icon, required this.title, required this.isActive, required this.onTap, this.isLogout = false});

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.isLogout ? Colors.redAccent : (widget.isActive ? AppColors.primaryBlack : AppColors.primaryGold);
    final textColor = widget.isLogout ? Colors.redAccent : (widget.isActive ? AppColors.primaryBlack : Colors.white70);
    final bgColor = widget.isActive ? AppColors.primaryGold : (_isHovering ? Colors.white.withOpacity(0.05) : Colors.transparent);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
        child: ListTile(
          leading: Icon(widget.icon, color: iconColor),
          title: Text(widget.title, style: TextStyle(color: textColor, fontWeight: widget.isActive ? FontWeight.bold : FontWeight.w500, letterSpacing: 0.5)),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}
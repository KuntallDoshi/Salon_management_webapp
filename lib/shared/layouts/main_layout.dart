import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../widget/animated_sidebar.dart';

class MainLayout extends StatelessWidget {
  final Widget content;
  final int currentIndex;

  const MainLayout({
    super.key, 
    required this.content, 
    required this.currentIndex
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: AppColors.primaryBlack,
              iconTheme: const IconThemeData(color: AppColors.primaryGold),
              title: Image.asset('assets/herik_logo.png', height: 40),
              centerTitle: true,
            ),
      drawer: isDesktop ? null : Drawer(child: AnimatedSidebar(currentIndex: currentIndex)),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar is PERMANENT here on Desktop
          if (isDesktop) SizedBox(width: 280, child: AnimatedSidebar(currentIndex: currentIndex)),

          // 🚀 The right side content changes instantly based on the URL!
          Expanded(
            child: content,
          ),
        ],
      ),
    );
  }
}
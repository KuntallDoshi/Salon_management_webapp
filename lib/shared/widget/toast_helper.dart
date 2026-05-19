import 'package:flutter/material.dart';


class ToastHelper {
  static void show(BuildContext context, String message, {bool isSuccess = true}) {
    final size = MediaQuery.of(context).size;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isSuccess ? Icons.check_circle : Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green.shade700 : Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
        
        // 🚀 CHANGED: Adjusted margin to push it to the Top Right
        margin: EdgeInsets.only(
          bottom: size.height - 120, // Pushes it to the top
          right: 24,                 // 24px from the right edge
          left: size.width > 400 ? size.width - 350 : 24, // 🚀 Keeps it a fixed width (approx 326px) on desktop, expands on mobile
        ),
        
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
        elevation: 10,
      ),
    );
  }
}
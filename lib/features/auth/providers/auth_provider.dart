import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http show get;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../../../core/api/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isInitializing = true; // Tracks initial app load
  bool get isInitializing => _isInitializing;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  
  String? get userRole => _currentUser?.role;

  // ─── 1. RESTORE SESSION ON WEB RELOAD ────────────────────────────────────
Future<bool> initializeAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token != null) {
      // 🚀 THE FIX: Fetch live data from backend so Loans & Salary are always accurate!
      try {
        final res = await http.get(
          Uri.parse('${ApiService().baseUrl}/users/me'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body)['data'];
          _currentUser = UserModel.fromJson(data);
          await prefs.setString('user_data', jsonEncode(data)); // update cache
        }
      } catch (e) {
        // Fallback to cache if offline
        final userDataString = prefs.getString('user_data');
        if (userDataString != null) _currentUser = UserModel.fromJson(jsonDecode(userDataString));
      }
      
      _isInitializing = false;
      notifyListeners();
      return true; 
    }

    _isInitializing = false;
    notifyListeners();
    return false;
  }

  // ─── 2. LOGIN & SAVE TO LOCAL STORAGE ────────────────────────────────────
  // ─── 2. LOGIN & SAVE TO LOCAL STORAGE ────────────────────────────────────
  // 🚀 FIXED: Now returns Future<String?> instead of Future<bool>
  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners(); // 🌀 START SPINNER

    try {
      final response = await _apiService.login(email, password);
      
      if (response['success'] == true) {
        _currentUser = UserModel.fromJson(response['data']['user']);
        
        // Save user data to SharedPreferences so it survives a web refresh!
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(response['data']['user']));

        _isLoading = false;
        notifyListeners(); // 🛑 STOP SPINNER (SUCCESS)
        return null; // 🚀 NULL MEANS SUCCESS (No errors!)
      } else {
        _isLoading = false;
        notifyListeners(); // 🛑 STOP SPINNER (FAILED)
        // 🚀 RETURN THE ACTUAL BACKEND ERROR MESSAGE
        return response['message'] ?? 'Login failed. Please try again.';
      }
    } catch (e) {
      debugPrint('Login Error: $e');
      _isLoading = false;
      notifyListeners(); // 🛑 STOP SPINNER (CRASHED)
      // 🚀 CLEAN UP AND RETURN THE CRASH MESSAGE
      return e.toString().replaceAll('Exception: ', '');
    }
  }
  // ─── 3. PASSWORD RESET FLOW ──────────────────────────────────────────────
  Future<String?> requestPasswordReset(String email) async {
    _isLoading = true;
    notifyListeners();
    String? err = await _apiService.sendPasswordResetOTP(email);
    _isLoading = false;
    notifyListeners();
    return err;
  }

  Future<String?> submitNewPassword(String otp, String newPassword) async {
    _isLoading = true;
    notifyListeners();
    String? err = await _apiService.resetPasswordWithOTP(otp, newPassword);
    _isLoading = false;
    notifyListeners();
    return err;
  }

  // ─── 4. UPDATE MY PROFILE ────────────────────────────────────────────────
// ─── 4. UPDATE MY PROFILE ────────────────────────────────────────────────
  Future<String?> updateProfile(String name, String phone, String password) async {
    _isLoading = true;
    notifyListeners();
    
    // Call the API we created in api_service.dart
    String? err = await _apiService.updateMyProfile(name, phone, password);
    
    // 🚀 If successful, we MUST update the local memory and SharedPreferences 
    // so the UI (like the Dashboard header) updates instantly without needing a reload!
    if (err == null && _currentUser != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final userDataString = prefs.getString('user_data');

        if (userDataString != null) {
          // Decode the saved JSON, update the name and phone, and save it back
          Map<String, dynamic> userMap = jsonDecode(userDataString);
          userMap['name'] = name;
          userMap['phone'] = phone;

          // Rebuild the currentUser object
          _currentUser = UserModel.fromJson(userMap);

          // Save the new data back to local storage
          await prefs.setString('user_data', jsonEncode(userMap));
        }
      } catch (e) {
        debugPrint('Failed to update local user cache: $e');
      }
    }
    
    _isLoading = false;
    notifyListeners();
    return err;
  }

  // ─── 5. LOGOUT ───────────────────────────────────────────────────────────
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Wipes token and user data
    _currentUser = null;
    notifyListeners();
  }
}
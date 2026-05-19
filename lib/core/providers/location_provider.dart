import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:heric_webapp/core/api/api_service.dart';

class LocationProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  // 🚀 CHANGED: Now nullable, because they will be fetched dynamically!
  double? branchLat; 
  double? branchLng; 
  
  final double allowedRadiusInMeters = 150.0; 

  bool _isInsideBranch = false;
  bool get isInsideBranch => _isInsideBranch;

  bool _isChecking = true;
  bool get isChecking => _isChecking;

  StreamSubscription<Position>? _positionStream;

  void setBranchCoordinates(double lat, double lng) {
    branchLat = lat;
    branchLng = lng;
    notifyListeners();
  }

  // 🚀 CHANGED: Now requires the branchId of the logged-in user
  void startTracking(String userRole, String? branchId) async {
    final role = userRole.toUpperCase(); 

    // // Admins and Owners completely bypass GPS tracking
    // if (role == 'ADMIN' || role == 'OWNER') {
    //   _isInsideBranch = true;
    //   _isChecking = false;
    //   notifyListeners();
    //   return; 
    // }
// 🚨 TESTING OVERRIDE: Treat everyone like an Admin so it doesn't check GPS
    if (role == 'ADMIN' || role == 'OWNER' || role == 'STAFF' || role == 'MANAGER') {
      _isInsideBranch = true;
      _isChecking = false;
      notifyListeners();
      return; 
    }
    // If staff has no branch assigned, stop tracking
    if (branchId == null) {
      debugPrint("❌ User has no branch ID assigned.");
      _isChecking = false;
      notifyListeners();
      return;
    }

    // 🚀 THE FIX: FETCH DYNAMIC COORDINATES FROM BACKEND
    try {
      final branches = await _apiService.getBranches();
      final myBranch = branches.firstWhere((b) => b['_id'] == branchId, orElse: () => null);

      if (myBranch != null && myBranch['latitude'] != null && myBranch['longitude'] != null) {
        branchLat = (myBranch['latitude'] as num).toDouble();
        branchLng = (myBranch['longitude'] as num).toDouble();
        debugPrint("🎯 Dynamic Branch Coordinates Loaded: Lat: $branchLat, Lng: $branchLng");
      } else {
        debugPrint("❌ Branch coordinates missing from backend data.");
        _isChecking = false;
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint("❌ Failed to fetch branches for Geofencing: $e");
      _isChecking = false;
      notifyListeners();
      return;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _isChecking = false;
      notifyListeners();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _isChecking = false;
        notifyListeners();
        return;
      }
    }

    try {
      Position initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );
      _checkGeofence(initialPosition);
    } catch (e) {
      _isChecking = false;
      notifyListeners();
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((Position position) {
      _checkGeofence(position);
    });
  }

  void _checkGeofence(Position currentPosition) {
    if (branchLat == null || branchLng == null) return; // Safety check

    double distanceInMeters = Geolocator.distanceBetween(
        branchLat!, branchLng!, currentPosition.latitude, currentPosition.longitude);

    debugPrint("📍 GPS CHECK: You are ${distanceInMeters.toStringAsFixed(0)} meters away from your assigned branch.");

    bool previouslyInside = _isInsideBranch;
    _isInsideBranch = distanceInMeters <= allowedRadiusInMeters;
    _isChecking = false;

    if (previouslyInside == false && _isInsideBranch == true) {
      _logStaffMovement('CLOCK_IN', currentPosition);
    } 
    else if (previouslyInside == true && _isInsideBranch == false) {
      _logStaffMovement('CLOCK_OUT', currentPosition);
    }

    notifyListeners();
  }

  void _logStaffMovement(String action, Position pos) async {
    debugPrint('ATTEMPTING: $action at ${DateTime.now()}');

    if (action == 'CLOCK_IN') {
      bool success = await _apiService.clockIn(pos.latitude, pos.longitude);
      if (success) debugPrint("✅ Successfully Saved Clock-In to Database!");
      else debugPrint("❌ Backend rejected Clock-In."); 
    } 
    else if (action == 'CLOCK_OUT') {
      bool success = await _apiService.clockOut(pos.latitude, pos.longitude);
      if (success) debugPrint("✅ Successfully Saved Clock-Out to Database!");
      else debugPrint("❌ Backend rejected Clock-Out.");
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }
}
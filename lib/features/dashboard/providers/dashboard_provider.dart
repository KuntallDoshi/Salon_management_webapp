import 'package:flutter/material.dart';
import '../../../core/api/api_service.dart';

class DashboardProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String currentFilter = 'today';
  DateTime? customStartDate;
  DateTime? customEndDate;

  // ─── ADMIN STATS ───
  double dailyRevenue = 0.0;
  int todayVisitors = 0;
  int allBranchVisitors = 0;
  String mostUsedService = "Loading...";
  List<Map<String, dynamic>> branchRevenues = [];
  List<double> chartValues = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  List<String> chartLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  // ─── PERSONAL STAFF STATS ───
  double personalRevenue = 0.0;
  int personalJobs = 0;
  bool isClockedIn = false;
  int totalMinutesWorked = 0;

  Future<void> fetchDashboardData(String branchId, String userRole, {String? filter, DateTime? start, DateTime? end}) async {
    _isLoading = true;
    
    // Safely update filters
    if (filter != null) currentFilter = filter;
    if (start != null) customStartDate = start;
    if (end != null) customEndDate = end;
    
    notifyListeners();

    try {
      // 🚀 THE FIX: Handle roles appropriately!
      if (userRole == 'ADMIN' || userRole == 'OWNER') {
        await _fetchAdminStats();
      } else if (userRole == 'MANAGER') {
        // Managers need BOTH branch stats AND personal attendance!
        await Future.wait([
          _fetchAdminStats(),
          _fetchStaffStats(),
        ]);
      } else {
        // Regular Staff
        await _fetchStaffStats();
      }
    } catch (e) {
      debugPrint("Dashboard Fetch Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Helper function for Admin/Branch data
Future<void> _fetchAdminStats() async {
    final adminData = await _apiService.getAdminDashboardStats(
      filter: currentFilter, 
      startDate: customStartDate?.toIso8601String(), 
      endDate: customEndDate?.toIso8601String()
    );
    
    if (adminData != null) {
      dailyRevenue = (adminData['dailyRevenue'] ?? 0).toDouble();
      todayVisitors = adminData['todayVisitors'] ?? 0;
      allBranchVisitors = adminData['allBranchVisitors'] ?? 0;
      mostUsedService = adminData['mostUsedService'] ?? "No services yet";
      
      if (adminData['branchRevenues'] != null) {
        branchRevenues = List<Map<String, dynamic>>.from(adminData['branchRevenues']);
      }
      
      // These will now always be 7 days of data from the backend
      chartValues = (adminData['chartValues'] as List).map((x) => (x as num).toDouble()).toList();
      chartLabels = List<String>.from(adminData['chartLabels']);
    }
  }

  // Helper function for Personal Attendance/Revenue
  Future<void> _fetchStaffStats() async {
    final staffData = await _apiService.getStaffDashboardStats();
    if (staffData != null) {
      personalRevenue = (staffData['personalRevenue'] ?? 0).toDouble();
      personalJobs = staffData['jobsCompleted'] ?? 0;
      isClockedIn = staffData['isClockedIn'] ?? false;
      totalMinutesWorked = staffData['totalMinutesWorked'] ?? 0;
    }
  }
}
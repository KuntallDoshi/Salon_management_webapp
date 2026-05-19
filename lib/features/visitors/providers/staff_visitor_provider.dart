import 'package:flutter/material.dart';
import '../../../core/api/api_service.dart';
import '../models/visitor_models.dart';

class StaffVisitorProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _currentBranchId;
  String? get currentBranchId => _currentBranchId;
  
  List<StaffModel> staffList = [];
  List<ServiceModel> services = [];
  List<VisitRecordModel> activeVisits = [];
  List<VisitRecordModel> completedVisits = [];
  List<dynamic> branches = [];

  // 🚀 PAGINATION TRACKERS
  int activeTotalPages = 1;
  int activeTotalItems = 0;
  int historyTotalPages = 1;
  int historyTotalItems = 0;

  bool _isProfileLoading = false;
  bool get isProfileLoading => _isProfileLoading;

  List<VisitRecordModel> selectedStaffVisits = [];
  List<dynamic> selectedStaffLogs = []; 
  double selectedStaffTotalRevenue = 0.0;

  // 🚀 UNIVERSAL DATA EXTRACTOR
  List<dynamic> _extractData(dynamic result) {
    if (result is Map) return result['data'] as List<dynamic>? ?? [];
    if (result is List) return result;
    return [];
  }

  // --- INITIALIZATION ---
  Future<void> fetchInitialData(String branchId, {String? serviceId, String? staffId, String? status, double? minRev, double? maxRev}) async {
    _isLoading = true;
    _currentBranchId = branchId;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.getBranchStaff(branchId),
        _apiService.getServices(fetchAll: true),
        _apiService.getBranches(), 
      ]);

      staffList = _extractData(results[0]).map((s) => StaffModel.fromJson(s)).toList();
      services = _extractData(results[1]).map((s) => ServiceModel.fromJson(s)).toList();
      branches = _extractData(results[2]);

      // 🚀 Fetch Queue and History Independently!
      await fetchActiveQueue(branchId: branchId);
      await fetchVisitHistory(branchId: branchId, serviceId: serviceId, staffId: staffId, status: status, minRev: minRev, maxRev: maxRev, page: 1);

    } catch (e) {
      debugPrint("Error fetching Staff/Visitor data: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 🚀 FETCH ACTIVE QUEUE (Unpaginated or large limit, since it's just live walk-ins)
  Future<void> fetchActiveQueue({required String branchId, String? search}) async {
    try {
      final res = await _apiService.getLiveQueue(branchId, search: search, page: 1, limit: 100);
      final all = _extractData(res).map((v) => VisitRecordModel.fromJson(v)).toList();
      
      activeVisits = all.where((v) => v.status != 'completed' && v.status != 'cancelled').toList();
      activeTotalItems = activeVisits.length;
      activeTotalPages = 1;
    } catch(e) { debugPrint("Active Queue Fetch Error: $e"); }
    notifyListeners();
  }

  // 🚀 FETCH VISIT HISTORY (Server-Side Paginated)
  Future<void> fetchVisitHistory({required String branchId, int page = 1, String? search, String? serviceId, String? staffId, String? status, double? minRev, double? maxRev}) async {
    _isLoading = true; notifyListeners();
    try {
      // If no status is selected, default to fetching completed & cancelled history
      final targetStatus = (status == null || status == 'All') ? null : status.toLowerCase();

      final res = await _apiService.getLiveQueue(
        branchId, 
        status: targetStatus, 
        search: search, page: page, limit: 10,
        serviceId: serviceId, staffId: staffId, 
        minRev: minRev, maxRev: maxRev
      );
      
      final parsed = _extractData(res).map((v) => VisitRecordModel.fromJson(v)).toList();
      completedVisits = parsed.where((v) => v.status == 'completed' || v.status == 'cancelled').toList();

      if (res is Map) {
        historyTotalPages = res['totalPages'] ?? 1;
        historyTotalItems = res['totalItems'] ?? 0;
      } else {
        historyTotalPages = 1;
        historyTotalItems = completedVisits.length;
      }
    } catch(e) { debugPrint("Visit History Fetch Error: $e"); }
    _isLoading = false; notifyListeners();
  }

  Future<Map<String, dynamic>?> checkReturningVisitor(String phone) async {
    if (phone.length == 10) return await _apiService.getVisitorByPhone(phone);
    return null;
  }
  
  List<ServiceModel> getServicesForGender(String gender) {
    return services.where((s) => s.genderCategory.toLowerCase() == gender.toLowerCase() || s.genderCategory.toLowerCase() == 'unisex').toList();
  }

  List<StaffModel> getAvailableStaff() {
    return staffList.where((s) => !s.isBusy).toList();
  }

  Future<List<dynamic>> searchVisitors(String query) async {
    return await _apiService.searchVisitors(query);
  }

  Future<String?> createNewVisit(String name, String phone, String gender, List<String> serviceIds, String staffId, {String? branchId}) async {
    _isLoading = true; notifyListeners();
    final targetBranchId = branchId ?? _currentBranchId;

    if (targetBranchId == null) {
      _isLoading = false; notifyListeners(); return "No branch selected";
    }

    final visitData = {
      'visitorName': name, 'phone': phone, 'gender': gender, 
      'serviceIds': serviceIds, 'assignedStaffId': staffId, 'branchId': targetBranchId, 
    };

    try {
      String? errorMessage = await _apiService.createVisit(targetBranchId, visitData);
      if (errorMessage == null) {
        if (_currentBranchId == targetBranchId) await fetchInitialData(_currentBranchId!); 
        return null; 
      }
      _isLoading = false; notifyListeners();
      return errorMessage; 
    } catch (e) {
      _isLoading = false; notifyListeners();
      return e.toString();
    }
  }

  Future<String?> completeService(String visitId, {double discountPercent = 0.0, String? paymentMethod}) async {
    _isLoading = true; notifyListeners();
    String? errorMessage = await _apiService.completeVisit(visitId, discountPercent: discountPercent, paymentMethod: paymentMethod);
    if (errorMessage == null && _currentBranchId != null) await fetchInitialData(_currentBranchId!); 
    else { _isLoading = false; notifyListeners(); }
    return errorMessage;
  }

  Future<void> fetchStaffProfile(String staffId) async {
    _isProfileLoading = true; notifyListeners();
    try {
      final results = await Future.wait([
        _apiService.getStaffPerformance(staffId),
        _apiService.getStaffLogs(staffId),
      ]);
      selectedStaffVisits = _extractData(results[0]).map((v) => VisitRecordModel.fromJson(v)).toList();
      selectedStaffTotalRevenue = selectedStaffVisits.fold(0.0, (sum, visit) => sum + visit.totalBasePrice);
      selectedStaffLogs = _extractData(results[1]);
    } catch (e) { debugPrint("Profile Fetch Error: $e"); } 
    finally { _isProfileLoading = false; notifyListeners(); }
  }

  Future<List<ServiceModel>> searchLiveServices(String query, String gender) async {
    try {
      final results = await _apiService.getServices(search: query, gender: gender);
      return _extractData(results).map((s) => ServiceModel.fromJson(s)).toList();
    } catch (e) { return []; }
  }

 Future<String?> editVisit(String visitId, String name, String phone, List<String> serviceIds, String staffId, {String? paymentMethod,double? discountPercent}) async {
    _isLoading = true; notifyListeners();
    final visitData = {
      'visitorName': name, 'phone': phone, 'serviceIds': serviceIds, 'assignedStaffId': staffId,
      if (paymentMethod != null) 'paymentMethod': paymentMethod, 
      if (discountPercent != null) 'discountPercent': discountPercent, 
    };

    try {
      String? errorMessage = await _apiService.editVisit(visitId, visitData);
      if (errorMessage == null && _currentBranchId != null) await fetchInitialData(_currentBranchId!); 
      else { _isLoading = false; notifyListeners(); }
      return errorMessage;
    } catch (e) { _isLoading = false; notifyListeners(); return e.toString(); }
  }

  Future<String?> deleteVisit(String visitId) async {
    _isLoading = true; notifyListeners();
    try {
      String? errorMessage = await _apiService.deleteVisit(visitId);
      if (errorMessage == null && _currentBranchId != null) await fetchInitialData(_currentBranchId!); 
      else { _isLoading = false; notifyListeners(); }
      return errorMessage;
    } catch (e) { _isLoading = false; notifyListeners(); return e.toString(); }
  }
}
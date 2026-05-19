import 'package:flutter/material.dart';
import 'package:heric_webapp/features/inventory/models/inventory_item.dart';
import '../../../core/api/api_service.dart';
import '../../visitors/models/visitor_models.dart'; 

class AdminProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool get isLoading => _isLoading;
  
  bool _isProfileLoading = false;
  bool get isProfileLoading => _isProfileLoading;
  
  String? _currentBranchId;
  String? get currentBranchId => _currentBranchId;

  // ─── DATA LISTS ───
  List<dynamic> branches = [];
  List<ProductModel> masterProducts = [];
  List<ServiceModel> services = [];
  List<StaffModel> branchStaff = [];
  List<StaffModel> get staffList => branchStaff; 
  List<dynamic> brandsCatalog = [];
  List<dynamic> categoriesCatalog = [];
  List<dynamic> customersList = [];
  
  // ─── STAFF PROFILE ───
  List<VisitRecordModel> selectedStaffVisits = [];
  List<dynamic> selectedStaffLogs = []; 
  double selectedStaffTotalRevenue = 0.0;

  // ─── PAGINATION TRACKERS ───
  int serviceTotalPages = 1; int serviceTotalItems = 0;
  int customerTotalPages = 1; int customerTotalItems = 0;
  int staffTotalPages = 1; int staffTotalItems = 0;
  int productTotalPages = 1; int productTotalItems = 0;

  // =====================================================================
  // 🚀 UNIVERSAL DATA EXTRACTOR
  // Safely extracts data and pagination math regardless of API version!
  // =====================================================================
  List<dynamic> _extractData(dynamic result, void Function(int pages, int items) onPagination) {
    if (result is Map) {
      onPagination(result['totalPages'] ?? 1, result['totalItems'] ?? 0);
      return result['data'] as List<dynamic>? ?? [];
    } else if (result is List) {
      onPagination(1, result.length);
      return result;
    }
    onPagination(1, 0);
    return [];
  }

  // =====================================================================
  // CORE FETCH METHODS
  // =====================================================================

  Future<void> fetchAdminData(String branchId) async {
    _isLoading = true; _currentBranchId = branchId; notifyListeners();
    
    try {
      final results = await Future.wait([
        _apiService.getServices(fetchAll: false, page: 1, limit: 8), 
        _apiService.getBranchStaff(branchId),    
        _apiService.getProducts(),               
        _apiService.getBranches(),               
        _apiService.getBrands(),                 
        _apiService.getCategories(),             
        _apiService.getAllCustomers(),           
      ]);
      
      services = _extractData(results[0], (p, i) { serviceTotalPages = p; serviceTotalItems = i; }).map((s) => ServiceModel.fromJson(s)).toList();
      branchStaff = _extractData(results[1], (p, i) { staffTotalPages = p; staffTotalItems = i; }).map((s) => StaffModel.fromJson(s)).toList();
      masterProducts = _extractData(results[2], (p, i) { productTotalPages = p; productTotalItems = i; }).map((p) => ProductModel.fromJson(p)).toList();
      branches = _extractData(results[3], (p, i) {}); 
      brandsCatalog = _extractData(results[4], (p, i) {});     
      categoriesCatalog = _extractData(results[5], (p, i) {}); 
      customersList = _extractData(results[6], (p, i) { customerTotalPages = p; customerTotalItems = i; }); 
      
      _isLoading = false; notifyListeners();
    } catch (e) {
      _isLoading = false; notifyListeners();
      debugPrint("🚨 Admin Fetch Error: $e");
    }
  }

  Future<void> fetchFilteredServices({String? search, String? gender, int page = 1}) async {
    _isLoading = true; notifyListeners();
    try {
      final res = await _apiService.getServices(search: search, gender: gender, page: page, limit: 8, fetchAll: false);
      services = _extractData(res, (p, i) { serviceTotalPages = p; serviceTotalItems = i; }).map((s) => ServiceModel.fromJson(s)).toList();
    } catch (e) { debugPrint("Fetch Services Error: $e"); }
    _isLoading = false; notifyListeners();
  }

  Future<void> fetchCustomers({String? search, int page = 1}) async {
    _isLoading = true; notifyListeners();
    try {
      final res = await _apiService.getAllCustomers(search: search); 
      // Note: If you add page parameter to getAllCustomers in api_service, pass it above!
      customersList = _extractData(res, (p, i) { customerTotalPages = p; customerTotalItems = i; });
    } catch (e) { debugPrint("Fetch Customers Error: $e"); }
    _isLoading = false; notifyListeners();
  }

  Future<void> fetchFilteredStaff({String? search, String? role, int page = 1}) async {
    if (_currentBranchId == null) return;
    _isLoading = true; notifyListeners();
    try {
      final res = await _apiService.getBranchStaff(_currentBranchId!, search: search, role: role);
      branchStaff = _extractData(res, (p, i) { staffTotalPages = p; staffTotalItems = i; }).map((s) => StaffModel.fromJson(s)).toList();
    } catch (e) { }
    _isLoading = false; notifyListeners();
  }

  // =====================================================================
  // ACTIONS (CREATE, EDIT, DELETE, TOGGLE)
  // =====================================================================

  Future<String?> addBrand(String name, String description) async {
    _isLoading = true; notifyListeners();
    String? err = await _apiService.createBrand(name, description);
    if (err == null && _currentBranchId != null) await fetchAdminData(_currentBranchId!);
    else { _isLoading = false; notifyListeners(); }
    return err;
  }

  Future<String?> removeBrand(String id) async {
    _isLoading = true; notifyListeners();
    String? err = await _apiService.deleteBrand(id);
    if (err == null && _currentBranchId != null) await fetchAdminData(_currentBranchId!);
    else { _isLoading = false; notifyListeners(); }
    return err;
  }

  Future<String?> editBrand(String id, String name, String description) async {
    _isLoading = true; notifyListeners();
    String? err = await _apiService.updateBrand(id, name, description);
    if (err == null && _currentBranchId != null) await fetchAdminData(_currentBranchId!);
    else { _isLoading = false; notifyListeners(); }
    return err;
  }

  Future<String?> addCategory(String name, String description) async {
    _isLoading = true; notifyListeners();
    String? err = await _apiService.createCategory(name, description);
    if (err == null && _currentBranchId != null) await fetchAdminData(_currentBranchId!);
    else { _isLoading = false; notifyListeners(); }
    return err;
  }

  Future<String?> removeCategory(String id) async {
    _isLoading = true; notifyListeners();
    String? err = await _apiService.deleteCategory(id);
    if (err == null && _currentBranchId != null) await fetchAdminData(_currentBranchId!);
    else { _isLoading = false; notifyListeners(); }
    return err;
  }

  Future<String?> editCategory(String id, String name, String description) async {
    _isLoading = true; notifyListeners();
    String? err = await _apiService.updateCategory(id, name, description);
    if (err == null && _currentBranchId != null) await fetchAdminData(_currentBranchId!);
    else { _isLoading = false; notifyListeners(); }
    return err;
  }

  Future<bool> toggleService(String serviceId) async {
    bool success = await _apiService.toggleServiceStatus(serviceId);
    if (success) {
      final res = await _apiService.getServices(fetchAll: true);
      services = _extractData(res, (p,i){}).map((s) => ServiceModel.fromJson(s)).toList();
      notifyListeners();
    }
    return success;
  }

  Future<bool> updateService(String serviceId, String name, String category, String genderCategory, double price) async {
    if (_currentBranchId == null) return false;
    _isLoading = true; notifyListeners();
    bool success = await _apiService.updateService(serviceId, name, category, genderCategory, price);
    if (success) { await fetchAdminData(_currentBranchId!); } 
    else { _isLoading = false; notifyListeners(); }
    return success;
  }

  Future<bool> addService(String name, String category, String genderCategory, double price) async {
    if (_currentBranchId == null) return false;
    _isLoading = true; notifyListeners();
    bool success = await _apiService.createService(name, category, genderCategory, price);
    if (success) { await fetchAdminData(_currentBranchId!); } 
    else { _isLoading = false; notifyListeners(); }
    return success;
  }

  Future<String?> addBranch(String name, String address, String city, double lat, double lng) async {
    _isLoading = true; notifyListeners();
    String? errorMessage = await _apiService.addBranch(name, address, city, lat, lng);
    if (errorMessage == null && _currentBranchId != null) await fetchAdminData(_currentBranchId!);
    _isLoading = false; notifyListeners();
    return errorMessage; 
  }

  Future<String?> deleteBranch(String id) async {
    _isLoading = true; notifyListeners();
    String? errorMessage = await _apiService.removeBranch(id);
    if (errorMessage == null && _currentBranchId != null) await fetchAdminData(_currentBranchId!);
    _isLoading = false; notifyListeners();
    return errorMessage;
  }

  Future<String?> editBranch(String id, String name, String address, String city, double lat, double lng) async {
    _isLoading = true; notifyListeners();
    String? errorMessage = await _apiService.updateBranch(id, name, address, city, lat, lng);
    if (errorMessage == null && _currentBranchId != null) await fetchAdminData(_currentBranchId!); 
    else { _isLoading = false; notifyListeners(); }
    return errorMessage; 
  }

  Future<String?> addMasterProduct(String name, String brand, String category, double price, int threshold) async {
    if (_currentBranchId == null) return "Error: Branch ID missing";
    _isLoading = true; notifyListeners();
    try {
      await _apiService.createProduct(name, brand, category, price, threshold);
      await fetchAdminData(_currentBranchId!); 
      return null; 
    } catch (e) {
      _isLoading = false; notifyListeners();
      return e.toString(); 
    }
  }

  Future<String?> removeMasterProduct(String id) async {
    _isLoading = true; notifyListeners();
    String? err = await _apiService.deleteProduct(id);
    if (err == null && _currentBranchId != null) await fetchAdminData(_currentBranchId!);
    else { _isLoading = false; notifyListeners(); }
    return err;
  }

  Future<String?> editMasterProduct(String id, String name, String brand, String category, double price) async {
    if (_currentBranchId == null) return "Error: Branch ID missing";
    _isLoading = true; notifyListeners();
    try {
      String? err = await _apiService.updateProduct(id, name, brand, category, price);
      if (err == null) await fetchAdminData(_currentBranchId!); 
      else { _isLoading = false; notifyListeners(); }
      return err; 
    } catch (e) {
      _isLoading = false; notifyListeners();
      return e.toString(); 
    }
  }

  Future<String?> addStaff(String name, String role, String email, String phone, String address, String password, String branchId, List<String> accessibleScreens, double salary, double loanAmount) async {
    _isLoading = true; notifyListeners();
    String? errorMessage = await _apiService.createStaff(branchId, name, role, email, phone, address, password, accessibleScreens, salary: salary, loanAmount: loanAmount);
    
    if (errorMessage == null && _currentBranchId != null) await fetchAdminData(_currentBranchId!); 
    else { _isLoading = false; notifyListeners(); }
    return errorMessage; 
  }

  Future<bool> toggleStaff(String staffId) async {
    _isLoading = true; notifyListeners(); 
    bool success = await _apiService.toggleStaffStatus(staffId);
    
    if (success && _currentBranchId != null) await fetchAdminData(_currentBranchId!);
    else { _isLoading = false; notifyListeners(); }
    return success;
  }

  Future<String?> transferStaff(String staffId, String newBranchId, String newRole) async {
    _isLoading = true; notifyListeners();
    String? errorMessage = await _apiService.transferStaff(staffId, newBranchId, newRole);
    if (errorMessage == null && _currentBranchId != null) await fetchAdminData(_currentBranchId!); 
    else { _isLoading = false; notifyListeners(); }
    return errorMessage;
  }

  Future<String?> forceResetPassword(String staffId, String newPassword) async {
    _isLoading = true; notifyListeners();
    String? errorMessage = await _apiService.adminResetPassword(staffId, newPassword);
    _isLoading = false; notifyListeners();
    return errorMessage;
  }

  Future<void> fetchStaffProfile(String staffId) async {
    _isProfileLoading = true; notifyListeners();
    try {
      final results = await Future.wait([
        _apiService.getStaffPerformance(staffId),
        _apiService.getStaffLogs(staffId),
      ]);
      selectedStaffVisits = _extractData(results[0], (p,i){}).map((v) => VisitRecordModel.fromJson(v)).toList();
      selectedStaffTotalRevenue = selectedStaffVisits.fold(0.0, (sum, visit) => sum + (visit.finalPrice ?? visit.totalBasePrice));
      selectedStaffLogs = _extractData(results[1], (p,i){});
    } catch (e) { debugPrint("Profile Fetch Error: $e"); } 
    finally { _isProfileLoading = false; notifyListeners(); }
  }

  Future<String?> updateFinancials(String staffId, double salary, double newLoanAmount) async {
    try {
      final errorMessage = await _apiService.updateFinancials(staffId, salary, newLoanAmount);
      if (errorMessage == null && _currentBranchId != null) await fetchAdminData(_currentBranchId!); 
      return errorMessage;
    } catch (e) { return 'Failed to update financials: $e'; }
  }

  Future<String?> logRepayment(String staffId, double amount, String note) async {
    try {
      final errorMessage = await _apiService.logRepayment(staffId, amount, note);
      if (errorMessage == null && _currentBranchId != null) await fetchAdminData(_currentBranchId!); 
      return errorMessage;
    } catch (e) { return 'Failed to log repayment: $e'; }
  }

  Future<String?> deleteRepayment(String staffId, String repaymentId) async {
    try {
      final errorMessage = await _apiService.deleteRepayment(staffId, repaymentId);
      if (errorMessage == null && _currentBranchId != null) await fetchAdminData(_currentBranchId!); 
      return errorMessage;
    } catch (e) { return 'Failed to delete repayment: $e'; }
  }

  Future<List<dynamic>> getProductDistribution(String productId) async {
    return await _apiService.getProductDistribution(productId);
  }
}
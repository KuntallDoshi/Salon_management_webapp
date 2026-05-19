import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final String baseUrl = 'http://localhost:3000/api';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // =========================================================================
  // AUTHENTICATION
  // =========================================================================
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        body: jsonEncode({'email': email, 'password': password}),
        headers: {'Content-Type': 'application/json'},
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', data['data']['accessToken']);
        return data; 
      } else {
        throw Exception(data['message'] ?? 'Failed to login');      
      }
    } catch (e) { throw Exception(e.toString()); }
  }

  Future<String?> updateMyProfile(String name, String phone, String password) async {
    final token = await getToken();
    try {
      final res = await http.patch(
        Uri.parse('$baseUrl/users/me'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({ 'name': name, 'phone': phone }),
      );
      if (res.statusCode == 200) return null; 
      return jsonDecode(res.body)['message'] ?? 'Failed to update profile';
    } catch (e) { return 'Network Error: $e'; }
  }

  Future<String?> sendPasswordResetOTP(String email) async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/auth/forgot-password'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'email': email}));
      if (res.statusCode == 200) return null; 
      return jsonDecode(res.body)['message'] ?? 'Failed to send OTP';
    } catch (e) { return 'Network error'; }
  }

  Future<String?> resetPasswordWithOTP(String otp, String newPassword) async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/auth/reset-password'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'token': otp, 'newPassword': newPassword}));
      if (res.statusCode == 200) return null; 
      final data = jsonDecode(res.body);
      if (data['errors'] != null && data['errors'].isNotEmpty) return data['errors'][0]['msg']; 
      return data['message'] ?? 'Failed to reset password';
    } catch (e) { return 'Network error'; }
  }

  // =========================================================================
  // VISITORS & QUEUE
  // =========================================================================
  Future<Map<String, dynamic>?> getVisitorByPhone(String phone) async {
    final token = await getToken();
    try {
      final res = await http.get(Uri.parse('$baseUrl/visits/visitor/$phone'), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) return jsonDecode(res.body)['data'];
      return null;
    } catch (e) { return null; }
  }

// ─── VISITS / QUEUE API ───
  Future<dynamic> getLiveQueue(String branchId, {String? serviceId, String? staffId, String? status, double? minRev, double? maxRev, String? search, int page = 1, int limit = 10}) async {
    final token = await getToken();
    try {
      String url = '$baseUrl/visits/branches/$branchId/queue?page=$page&limit=$limit';
      if (serviceId != null && serviceId.isNotEmpty) url += '&serviceId=$serviceId';
      if (staffId != null && staffId.isNotEmpty) url += '&staffId=$staffId';
      if (status != null && status.isNotEmpty) url += '&status=$status';
      if (minRev != null) url += '&minRevenue=$minRev';
      if (maxRev != null) url += '&maxRevenue=$maxRev';
      if (search != null && search.isNotEmpty) url += '&search=$search';

      final res = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) {
        return jsonDecode(res.body); // 🚀 Returns Map with data, totalPages, totalItems
      }
      return {'data': [], 'totalPages': 1, 'totalItems': 0};
    } catch (e) {
      return {'data': [], 'totalPages': 1, 'totalItems': 0};
    }
  }

  Future<String?> createVisit(String branchId, Map<String, dynamic> visitData) async {
    final token = await getToken();
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/visits/walk-in'), 
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, 
        body: jsonEncode(visitData)
      );
      if (res.statusCode == 201 || res.statusCode == 200) return null; 
      return jsonDecode(res.body)['message'] ?? 'Unknown Backend Error';
    } catch (e) { return 'Network Error: $e'; }
  }

  Future<List<dynamic>> searchVisitors(String query) async {
    final token = await getToken();
    try {
      final res = await http.get(Uri.parse('$baseUrl/visits/visitors/search?q=$query'), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) return jsonDecode(res.body)['data'];
      return [];
    } catch (e) { return []; }
  }

Future<String?> completeVisit(String visitId, {double discountPercent = 0, String? paymentMethod}) async {
      final token = await getToken();
    try {
final res = await http.patch(
        Uri.parse('$baseUrl/visits/$visitId/complete'), 
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, 
        body: jsonEncode({'discountPercent': discountPercent, 'paymentMethod': paymentMethod}) // 🚀 Added to payload
      );
      if (res.statusCode == 200) return null; 
      return jsonDecode(res.body)['message'] ?? 'Unknown Backend Error';
    } catch (e) { return 'Network Error: $e'; }
  }

  // =========================================================================
  // INVENTORY & CATALOG
  // =========================================================================
  Future<List<dynamic>> getBranchStock(String branchId, {String? category, String? brand, double? minPrice, double? maxPrice}) async {
    final token = await getToken();
    String url = '$baseUrl/inventory/branches/$branchId/stock?';
    if (category != null && category.isNotEmpty) url += '&category=$category';
    if (brand != null && brand.isNotEmpty) url += '&brand=$brand';
    if (minPrice != null) url += '&minPrice=$minPrice';
    if (maxPrice != null) url += '&maxPrice=$maxPrice';

    final res = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 200) return jsonDecode(res.body)['data'];
    return [];
  }

  Future<List<dynamic>> getTransactions(String branchId) async {
    final token = await getToken();
    final res = await http.get(Uri.parse('$baseUrl/inventory/branches/$branchId/transactions'), headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 200) return jsonDecode(res.body)['data'];
    return [];
  }

  Future<List<dynamic>> getLowStockAlerts(String branchId) async {
    final token = await getToken();
    final response = await http.get(Uri.parse('$baseUrl/inventory/branches/$branchId/alerts/low-stock'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) return jsonDecode(response.body)['data'];
    throw Exception('Failed to load alerts');
  }

  Future<bool> stockIn(String branchId, String productId, int qty) async {
    final token = await getToken();
    try {
      final res = await http.post(Uri.parse('$baseUrl/inventory/branches/$branchId/stock-in'), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: jsonEncode({'productId': productId, 'quantity': qty}));
      if (res.statusCode == 200 || res.statusCode == 201) return true;
      throw Exception(jsonDecode(res.body)['message'] ?? 'Unknown Backend Error');
    } catch (e) { rethrow; }
  }

  Future<bool> manualUse(String branchId, String productId, int qty, String? note) async {
    final token = await getToken();
    final res = await http.post(Uri.parse('$baseUrl/inventory/branches/$branchId/manual-use'), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: jsonEncode({'productId': productId, 'quantity': qty, 'note': note}));
    return res.statusCode == 200;
  }

  Future<String?> transferStock(String branchId, String toBranchId, String productId, int qty) async {
    final token = await getToken();
    try {
      final res = await http.post(Uri.parse('$baseUrl/inventory/branches/$branchId/transfer'), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: jsonEncode({'productId': productId, 'toBranchId': toBranchId, 'quantity': qty}));
      if (res.statusCode == 200 || res.statusCode == 201) return null; 
      return jsonDecode(res.body)['message'] ?? 'Unknown Transfer Error';
    } catch (e) { return e.toString(); }
  }

  Future<List<dynamic>> getProducts() async {
    final token = await getToken();
    final res = await http.get(Uri.parse('$baseUrl/products'), headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 200) return jsonDecode(res.body)['data'];
    throw Exception('Failed to load global products');
  }

  Future<String?> updateProduct(String id, String name, String brand, String category, double price) async {
    final token = await getToken();
    try {
      final res = await http.patch(Uri.parse('$baseUrl/products/$id'), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: jsonEncode({'name': name, 'brand': brand, 'category': category.toLowerCase(), 'purchasePrice': price}));
      if (res.statusCode == 200) return null;
      return jsonDecode(res.body)['message'] ?? 'Unknown Error';
    } catch (e) { return e.toString(); }
  }

  Future<bool> createProduct(String name, String brand, String category, double price, int lowStockThreshold) async {
    final token = await getToken();
    try {
      final res = await http.post(Uri.parse('$baseUrl/products'), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: jsonEncode({'name': name, 'brand': brand, 'category': category.toLowerCase(), 'unit': 'pcs', 'purchasePrice': price, 'lowStockThreshold': lowStockThreshold}));
      if (res.statusCode == 201 || res.statusCode == 200) return true;
      throw Exception(jsonDecode(res.body)['message'] ?? 'Unknown Error');
    } catch (e) { rethrow; }
  }

  Future<List<dynamic>> getProductDistribution(String productId) async {
    final token = await getToken();
    try {
      final res = await http.get(Uri.parse('$baseUrl/inventory/products/$productId/stock'), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) return jsonDecode(res.body)['data'];
      return [];
    } catch (e) { return []; }
  }

  Future<String?> deleteProduct(String id) async {
    final token = await getToken();
    try {
      final res = await http.delete(Uri.parse('$baseUrl/products/$id'), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) return null;
      return jsonDecode(res.body)['message'] ?? 'Failed to delete product';
    } catch (e) { return 'Network Error'; }
  }

  // =========================================================================
  // BRAND & CATEGORY CRUD
  // =========================================================================
  Future<List<dynamic>> getBrands() async {
    final token = await getToken();
    final res = await http.get(Uri.parse('$baseUrl/catalog/brands'), headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 200) return jsonDecode(res.body)['data'];
    return [];
  }

  Future<List<dynamic>> getCategories() async {
    final token = await getToken();
    final res = await http.get(Uri.parse('$baseUrl/catalog/categories'), headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 200) return jsonDecode(res.body)['data'];
    return [];
  }

  Future<String?> createBrand(String name, String description) async {
    final token = await getToken();
    try {
      final res = await http.post(Uri.parse('$baseUrl/catalog/brands'), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: jsonEncode({'name': name, 'description': description}));
      if (res.statusCode == 201 || res.statusCode == 200) return null;
      return jsonDecode(res.body)['message'] ?? 'Failed to create brand';
    } catch (e) { return 'Network Error'; }
  }

  Future<String?> updateBrand(String id, String name, String description) async {
    final token = await getToken();
    try {
      final res = await http.patch(Uri.parse('$baseUrl/catalog/brands/$id'), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: jsonEncode({'name': name, 'description': description}));
      if (res.statusCode == 200) return null;
      return jsonDecode(res.body)['message'] ?? 'Failed to update brand';
    } catch (e) { return 'Network Error'; }
  }

  Future<String?> deleteBrand(String id) async {
    final token = await getToken();
    try {
      final res = await http.delete(Uri.parse('$baseUrl/catalog/brands/$id'), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) return null;
      return jsonDecode(res.body)['message'] ?? 'Failed to delete brand';
    } catch (e) { return 'Network Error'; }
  }

  Future<String?> createCategory(String name, String description) async {
    final token = await getToken();
    try {
      final res = await http.post(Uri.parse('$baseUrl/catalog/categories'), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: jsonEncode({'name': name, 'description': description}));
      if (res.statusCode == 201 || res.statusCode == 200) return null;
      return jsonDecode(res.body)['message'] ?? 'Failed to create category';
    } catch (e) { return 'Network Error'; }
  }

  Future<String?> updateCategory(String id, String name, String description) async {
    final token = await getToken();
    try {
      final res = await http.patch(Uri.parse('$baseUrl/catalog/categories/$id'), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: jsonEncode({'name': name, 'description': description}));
      if (res.statusCode == 200) return null;
      return jsonDecode(res.body)['message'] ?? 'Failed to update category';
    } catch (e) { return 'Network Error'; }
  }

  Future<String?> deleteCategory(String id) async {
    final token = await getToken();
    try {
      final res = await http.delete(Uri.parse('$baseUrl/catalog/categories/$id'), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) return null;
      return jsonDecode(res.body)['message'] ?? 'Failed to delete category';
    } catch (e) { return 'Network Error'; }
  }

  // =========================================================================
  // ADMIN SETUP (SERVICES & STAFF & BRANCHES)
  // =========================================================================
Future<Map<String, dynamic>> getServices({String? search, String? gender, bool fetchAll = false, int page = 1, int limit = 8}) async {
    final token = await getToken();
    try {
      // 🚀 Pass page and limit to URL
      String url = '$baseUrl/services?fetchAll=$fetchAll&page=$page&limit=$limit';
      if (search != null && search.isNotEmpty) url += '&search=$search';
      if (gender != null && gender.isNotEmpty) url += '&gender=$gender';

      final res = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) {
        return jsonDecode(res.body); // 🚀 Returns the FULL Map (data + totalPages)
      }
      return {'data': [], 'totalPages': 1, 'totalItems': 0};
    } catch (e) { 
      return {'data': [], 'totalPages': 1, 'totalItems': 0}; 
    }
  }

  Future<bool> createService(String name, String category, String genderCategory, double price) async {
    final token = await getToken();
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/services'), 
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, 
        body: jsonEncode({'name': name, 'category': category, 'genderCategory': genderCategory, 'price': price})
      ); 
      if (res.statusCode == 201 || res.statusCode == 200) return true;
      return false;
    } catch (e) { return false; }
  }

  Future<bool> updateService(String serviceId, String name, String category, String genderCategory, double price) async {
    final token = await getToken();
    try {
      final res = await http.patch(Uri.parse('$baseUrl/services/$serviceId'), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, 
      body: jsonEncode({'name': name, 'category': category, 'genderCategory': genderCategory, 'price': price}));
      return res.statusCode == 200;
    } catch (e) { return false; }
  }

  Future<bool> toggleServiceStatus(String serviceId) async {
    final token = await getToken();
    try {
      final res = await http.patch(Uri.parse('$baseUrl/services/$serviceId/toggle'), headers: {'Authorization': 'Bearer $token'});
      return res.statusCode == 200;
    } catch (e) { return false; }
  }

  Future<List<dynamic>> getBranchStaff(String branchId, {String? search, String? role}) async {
    final token = await getToken();
    try {
      String url = '$baseUrl/users/branches/$branchId/staff?';
      if (search != null && search.isNotEmpty) url += '&search=$search';
      if (role != null && role.isNotEmpty && role != 'All') url += '&role=$role';

      final res = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) return jsonDecode(res.body)['data'];
      return [];
    } catch (e) { return []; }
  }

  Future<bool> toggleStaffStatus(String staffId) async {
    final token = await getToken();
    try {
      final res = await http.patch(Uri.parse('$baseUrl/users/$staffId/toggle-status'), headers: {'Authorization': 'Bearer $token'});
      return res.statusCode == 200;
    } catch (e) { return false; }
  }

  // 🚀 FIXED: Added Salary and Loan to createStaff payload
  Future<String?> createStaff(String branchId, String name, String role, String email, String phone, String address, String password, List<String> accessibleRoutes, {double salary = 0.0, double loanAmount = 0.0}) async {
    final token = await getToken();
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/register'), 
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, 
        body: jsonEncode({
          'branchId': branchId, 'name': name, 'role': role.toUpperCase(), 
          'email': email, 'phone': phone, 'address': address, 'password': password, 
          'accessibleScreens': accessibleRoutes,
          'salary': salary, 'loanAmount': loanAmount // 🚀 Added Financial Data
        })
      );
      if (res.statusCode == 201 || res.statusCode == 200) return null;
      final data = jsonDecode(res.body);
      if (data['errors'] != null && data['errors'].isNotEmpty) return data['errors'][0]['msg']; 
      return data['message'] ?? 'Failed to register staff';
    } catch (e) { return 'Network Error: Please check your connection.'; }
  }

  Future<String?> transferStaff(String staffId, String newBranchId, String newRole) async {
    final token = await getToken();
    try {
      final res = await http.patch(Uri.parse('$baseUrl/users/$staffId/transfer'), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: jsonEncode({'branchId': newBranchId, 'role': newRole}));
      if (res.statusCode == 200) return null; 
      return jsonDecode(res.body)['message'] ?? 'Unknown Transfer Error';
    } catch (e) { return 'Network Error: $e'; }
  }

  Future<String?> adminResetPassword(String staffId, String newPassword) async {
    final token = await getToken();
    try {
      final res = await http.patch(Uri.parse('$baseUrl/users/$staffId/force-reset-password'), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: jsonEncode({'newPassword': newPassword}));
      if (res.statusCode == 200) return null; 
      final data = jsonDecode(res.body);
      if (data['errors'] != null && data['errors'].isNotEmpty) return data['errors'][0]['msg']; 
      return data['message'] ?? 'Failed to reset password.';
    } catch (e) { return 'Network Error'; }
  }

  // 🚀 FIXED: Added the Financial APIs for Admin use
  Future<String?> updateFinancials(String staffId, double salary, double newLoanAmount) async {
    final token = await getToken();
    try {
      final res = await http.patch(
        Uri.parse('$baseUrl/users/$staffId/financials'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'salary': salary, 'newLoanAmount': newLoanAmount}),
      );
      if (res.statusCode == 200) return null;
      return jsonDecode(res.body)['message'] ?? 'Failed to update financials';
    } catch (e) {
      return 'Network Error: $e';
    }
  }

  Future<String?> logRepayment(String staffId, double amount, String note) async {
    final token = await getToken();
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/users/$staffId/repay-loan'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'amount': amount, 'note': note}),
      );
      if (res.statusCode == 200) return null;
      return jsonDecode(res.body)['message'] ?? 'Failed to log repayment';
    } catch (e) {
      return 'Network Error: $e';
    }
  }

  // =========================================================================
  // OTHER METHODS (Branches, Dashboard, Geofence, Performance)
  // =========================================================================
  Future<List<dynamic>> getBranches() async {
    final token = await getToken();
    final res = await http.get(Uri.parse('$baseUrl/branches'), headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 200) return jsonDecode(res.body)['data'];
    throw Exception('Failed to load branches');
  }

  Future<String?> addBranch(String name, String address, String city, double lat, double lng) async {
    final token = await getToken();
    try {
      final res = await http.post(Uri.parse('$baseUrl/branches'), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: jsonEncode({'name': name, 'address': address, 'city': city, 'latitude': lat, 'longitude': lng}));
      if (res.statusCode == 201 || res.statusCode == 200) return null; 
      return jsonDecode(res.body)['message'] ?? 'Failed to create branch.';
    } catch (e) { return 'Network Error: $e'; }
  }

  Future<String?> updateBranch(String id, String name, String address, String city, double lat, double lng) async {
    final token = await getToken();
    try {
      final res = await http.patch(
        Uri.parse('$baseUrl/branches/$id'), 
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, 
        body: jsonEncode({
          'name': name, 
          'address': address, 
          'city': city,
          'latitude': lat, 
          'longitude': lng 
        })
      );
      if (res.statusCode == 200) return null; 
      return jsonDecode(res.body)['message'] ?? 'Failed to update branch.';
    } catch (e) { return 'Network Error: $e'; }
  }

  Future<String?> removeBranch(String branchId) async {
    final token = await getToken();
    try {
      final res = await http.delete(Uri.parse('$baseUrl/branches/$branchId'), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) return null; 
      return jsonDecode(res.body)['message'] ?? 'Failed to delete branch.';
    } catch (e) { return 'Network Error: $e'; }
  }

  Future<Map<String, dynamic>?> getAdminDashboardStats({String filter = 'today', String? startDate, String? endDate}) async {
    final token = await getToken();
    try {
      String url = '$baseUrl/users/dashboard/admin/stats?filter=$filter';
      if (filter == 'custom' && startDate != null && endDate != null) url += '&startDate=$startDate&endDate=$endDate';
      final res = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) return jsonDecode(res.body)['data'];
      return null;
    } catch (e) { return null; }
  }

  Future<Map<String, dynamic>?> getStaffDashboardStats() async {
    final token = await getToken();
    try {
      final res = await http.get(Uri.parse('$baseUrl/users/dashboard/staff/stats'), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) return jsonDecode(res.body)['data'];
      return null;
    } catch (e) { return null; }
  }

  Future<Map<String, dynamic>> getBranchRevenue(String branchId, {String? startDate, String? endDate, String? serviceId, String? search, int page = 1, int limit = 10}) async {
    final token = await getToken();
    try {
      // 🚀 Pass page and limit to URL
String url = '$baseUrl/revenue/branches/$branchId?page=$page&limit=$limit';
      if (startDate != null && startDate.isNotEmpty) url += '&startDate=$startDate';
      if (endDate != null && endDate.isNotEmpty) url += '&endDate=$endDate';
      if (serviceId != null && serviceId.isNotEmpty) url += '&serviceId=$serviceId';
      if (search != null && search.isNotEmpty) url += '&search=$search';

      final res = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) {
        return jsonDecode(res.body); // 🚀 Returns the FULL Map (data + totalPages)
      }
      return {'data': [], 'totalPages': 1, 'totalItems': 0};
    } catch (e) { 
      return {'data': [], 'totalPages': 1, 'totalItems': 0}; 
    }
  }

  Future<List<dynamic>> getStaffPerformance(String staffId) async {
    final token = await getToken();
    try {
      final res = await http.get(Uri.parse('$baseUrl/visits/staff/$staffId/performance'), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) return jsonDecode(res.body)['data'];
      return [];
    } catch (e) { return []; }
  }

  Future<List<dynamic>> getStaffLogs(String staffId) async {
    final token = await getToken();
    try {
      final res = await http.get(Uri.parse('$baseUrl/attendance/staff/$staffId/logs'), headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) return jsonDecode(res.body)['data'];
      return [];
    } catch (e) { return []; }
  }

  Future<bool> clockIn(double latitude, double longitude) async {
    final token = await getToken();
    try {
      final res = await http.post(Uri.parse('$baseUrl/attendance/clock-in'), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: jsonEncode({'latitude': latitude, 'longitude': longitude}));
      if (res.statusCode == 200 || res.statusCode == 201) return true;
      return false;
    } catch (e) { return false; }
  }

  Future<bool> clockOut(double latitude, double longitude) async {
    final token = await getToken();
    try {
      final res = await http.post(Uri.parse('$baseUrl/attendance/clock-out'), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: jsonEncode({'latitude': latitude, 'longitude': longitude}));
      if (res.statusCode == 200 || res.statusCode == 201) return true;
      return false;
    } catch (e) { return false; }
  }
  Future<String?> deleteRepayment(String staffId, String repaymentId) async {
    final token = await getToken();
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/users/$staffId/repay-loan/$repaymentId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) return null;
      return jsonDecode(res.body)['message'] ?? 'Failed to delete repayment';
    } catch (e) {
      return 'Network Error: $e';
    }
  }
  // Inside ApiService class, add these under Visit Methods:
  
Future<String?> editVisit(String visitId, Map<String, dynamic> visitData) async {
    final token = await getToken();
    try {
      final res = await http.patch(
        Uri.parse('$baseUrl/visits/$visitId/edit'), 
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, 
        body: jsonEncode(visitData)
      );
      if (res.statusCode == 200) return null; 
      
      // 🚀 SAFE HTML CATCHER
      try {
        return jsonDecode(res.body)['message'] ?? 'Failed to update visit';
      } catch (e) {
        return 'Server Error (500). Please check backend logs.';
      }
    } catch (e) { return 'Network Error: $e'; }
  }

  Future<String?> deleteVisit(String visitId) async {
    final token = await getToken();
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/visits/$visitId'), 
        headers: {'Authorization': 'Bearer $token'}
      );
      if (res.statusCode == 200) return null; 
      
      // 🚀 SAFE HTML CATCHER
      try {
        return jsonDecode(res.body)['message'] ?? 'Failed to delete visit';
      } catch (e) {
        return 'Server Error (500). Please check backend logs.';
      }
    } catch (e) { return 'Network Error: $e'; }
  }
Future<List<dynamic>> getAllCustomers({String? search}) async {
    final token = await getToken();
    try {
      String url = '$baseUrl/visits/customers/all';
      // 🚀 NEW: Append search query if it exists
      if (search != null && search.isNotEmpty) {
        url += '?search=$search';
      }
      
      final res = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body)['data'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
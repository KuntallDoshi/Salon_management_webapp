import 'package:flutter/material.dart';
import 'package:heric_webapp/features/inventory/models/inventory_item.dart';
import '../../../core/api/api_service.dart';

class InventoryProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _selectedBranchId;
  String? get selectedBranchId => _selectedBranchId;

  String _searchQuery = ''; 

  List<BranchModel> branches = [];
  List<ProductModel> masterProducts = []; // NEW: Global Product Catalog
  List<BrandModel> brandsCatalog = [];     // 🚀 NEW
  List<CategoryModel> categoriesCatalog = []; // 🚀 NEW
  List<InventoryItem> _allItems = [];
  List<StockTransactionModel> transfers = [];
  List<StockTransactionModel> sales = [];

  List<InventoryItem> get items {
    if (_searchQuery.isEmpty) return _allItems;
    return _allItems.where((item) => 
      item.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
      item.category.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }
// --- DYNAMICALLY CREATE NEW PRODUCT ---
  // Returns NULL if successful, or an ERROR STRING if failed
  Future<String?> createNewMasterProduct(String name, String brand, String category, double price, int threshold) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _apiService.createProduct(name, brand, category, price, threshold);
      
      // Refresh the master catalog instantly
      final productsRes = await _apiService.getProducts();
      masterProducts = (productsRes as List).map((p) => ProductModel.fromJson(p)).toList();
      
      _isLoading = false;
      notifyListeners();
      return null; // Null means NO ERRORS (Success!)
      
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      // Return the exact error message from Node.js
      return e.toString().replaceAll('Exception: ', ''); 
    }
  }
Future<void> fetchInitialData(String userBranchId) async {
    _isLoading = true;
    notifyListeners();
    try {
      // 🚀 Fetch Branches, Products, Brands, and Categories all at once!
      final results = await Future.wait([
        _apiService.getBranches(),
        _apiService.getProducts(), 
        _apiService.getBrands(),     // 🚀 NEW
        _apiService.getCategories(), // 🚀 NEW
      ]);
      
      branches = (results[0] as List).map((b) => BranchModel.fromJson(b)).toList();
      masterProducts = (results[1] as List).map((p) => ProductModel.fromJson(p)).toList();
      brandsCatalog = (results[2] as List).map((b) => BrandModel.fromJson(b)).toList();
      categoriesCatalog = (results[3] as List).map((c) => CategoryModel.fromJson(c)).toList();
      
      _selectedBranchId = userBranchId;
      await fetchInventoryForBranch(_selectedBranchId!);
    } catch (e) {
      debugPrint("Init Inventory Error: $e");
    }
  }

  void setBranch(String branchId) {
    _selectedBranchId = branchId;
    fetchInventoryForBranch(branchId);
  }

Future<void> fetchInventoryForBranch(String branchId, {String? category, String? brand, double? minPrice, double? maxPrice}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _apiService.getBranchStock(branchId, category: category, brand: brand, minPrice: minPrice, maxPrice: maxPrice), // 🚀 Pass filters!
        _apiService.getTransactions(branchId),
      ]);
      _allItems = (results[0] as List).map((i) => InventoryItem.fromJson(i, branchId)).toList();
      
      final allTransactions = (results[1] as List).map((t) => StockTransactionModel.fromJson(t)).toList();
      transfers = allTransactions.where((t) => t.type == 'transfer_out' || t.type == 'transfer_in').toList();
      sales = allTransactions.where((t) => t.type == 'manual_use').toList();
    } catch (e) {
      debugPrint("Fetch Inventory Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
// Returns NULL if successful, or an ERROR STRING if it fails
  Future<String?> addStock(String productId, int quantity) async {
    if (_selectedBranchId == null) return "No branch selected";
    
    _isLoading = true;
    notifyListeners();

    try {
      await _apiService.stockIn(_selectedBranchId!, productId, quantity);
      await fetchInventoryForBranch(_selectedBranchId!); // Refresh list
      
      _isLoading = false;
      notifyListeners();
      return null; // Success!

    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return e.toString().replaceAll('Exception: ', ''); // Return the exact error
    }
  }

  Future<bool> logUsage(String productId, int quantity, String? note) async {
    if (_selectedBranchId == null) return false;
    bool success = await _apiService.manualUse(_selectedBranchId!, productId, quantity, note);
    if (success) await fetchInventoryForBranch(_selectedBranchId!);
    return success;
  }

 // Returns NULL if successful, or an ERROR STRING if it fails
  Future<String?> transferStock(String productId, String toBranchId, int quantity) async {
    if (_selectedBranchId == null) return "No branch selected";
    
    _isLoading = true;
    notifyListeners();

    String? errorMessage = await _apiService.transferStock(_selectedBranchId!, toBranchId, productId, quantity);
    
    if (errorMessage == null) {
      await fetchInventoryForBranch(_selectedBranchId!); // Refresh list on success
    } else {
      _isLoading = false;
      notifyListeners();
    }
    
    return errorMessage; 
  }

  Future<bool> sellToVisitor(String productId, String visitorName, int quantity, double discount) async {
    return await logUsage(productId, quantity, 'Sold to visitor: $visitorName. Discount: $discount%');
  }
}
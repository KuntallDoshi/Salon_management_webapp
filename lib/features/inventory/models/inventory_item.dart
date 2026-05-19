class BranchModel {
  final String id;
  final String name;

  BranchModel({required this.id, required this.name});

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    return BranchModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? 'Unknown Branch',
    );
  }
}

class ProductModel {
  final String id;
  final String name;
  final String brand; // 🚀 Added
  final String category;

  ProductModel({required this.id, required this.name, required this.brand, required this.category});

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? 'Unknown Product',
      brand: json['brand'] ?? 'Unknown Brand',
      category: json['category'] ?? 'other',
    );
  }
}

class InventoryItem {
  final String id; 
  final String productId; 
  final String name;
  final String brand; // 🚀 Added
  final String category;
  final String unit; // 🚀 Added
  int currentStock;
  final int minRequiredStock;
  final DateTime? expiryDate;
  final String branchId;
  final double price;

  InventoryItem({
    required this.id, required this.productId, required this.name, required this.brand,
    required this.category, required this.unit, required this.currentStock,
    required this.minRequiredStock, this.expiryDate, required this.branchId, required this.price,
  });

  bool get isLowStock => currentStock <= minRequiredStock;
  bool get isExpiringSoon => expiryDate != null && expiryDate!.difference(DateTime.now()).inDays <= 30;
  int get neededStock => isLowStock ? (minRequiredStock - currentStock) + 5 : 0;

  factory InventoryItem.fromJson(Map<String, dynamic> json, String branchId) {
    final product = json['product'] ?? json['productId'] ?? {};
    return InventoryItem(
      id: json['_id'] ?? '',
      productId: product['_id'] ?? '',
      name: product['name'] ?? 'Unknown Product',
      brand: product['brand'] ?? 'N/A', // 🚀 Captured
      category: product['category'] ?? 'other',
      unit: product['unit'] ?? 'pcs', // 🚀 Captured
      currentStock: json['currentStock'] ?? 0,
      minRequiredStock: product['lowStockThreshold'] ?? 10,
      expiryDate: json['expiryDate'] != null ? DateTime.tryParse(json['expiryDate']) : null,
      branchId: branchId,
      price: (product['purchasePrice'] ?? 0).toDouble(),
    );
  }
}

class StockTransactionModel {
  final String id;
  final String type; 
  final String itemName;
  final String brand; 
  final int quantity;
  final String? note;
  final DateTime date;

  StockTransactionModel({
    required this.id, required this.type, required this.itemName, 
    required this.brand, required this.quantity, this.note, required this.date,
  });

  factory StockTransactionModel.fromJson(Map<String, dynamic> json) {
    return StockTransactionModel(
      id: json['_id'] ?? '',
      type: json['type'] ?? '',
      itemName: json['productId']?['name'] ?? 'Unknown Product',
      brand: json['productId']?['brand'] ?? 'N/A',
      quantity: json['quantity'] ?? 0,
      note: json['note'],
      date: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class BrandModel {
  final String id;
  final String name;
  BrandModel({required this.id, required this.name});
  factory BrandModel.fromJson(Map<String, dynamic> json) {
    return BrandModel(id: json['_id'] ?? '', name: json['name'] ?? 'Unknown');
  }
}

class CategoryModel {
  final String id;
  final String name;
  CategoryModel({required this.id, required this.name});
  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(id: json['_id'] ?? '', name: json['name'] ?? 'Unknown');
  }
}
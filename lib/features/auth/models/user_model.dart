class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String role;
  final String branchId;
  final bool isActive;
  final List<String> accessibleRoutes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // 🚀 FINANCIAL FIELDS ADDED HERE
  final double salary;
  final double loanRemaining;
  final double loanPrincipal;
  final int trustScore;
  final List<dynamic> repayments;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.role,
    required this.branchId,
    required this.isActive,
    required this.accessibleRoutes,
    this.createdAt,
    this.updatedAt, 
    required this.salary, 
    required this.loanRemaining, 
    required this.loanPrincipal, 
    required this.trustScore, 
    required this.repayments,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final loanData = json['loan'] ?? {};
    return UserModel(
      id: json['_id'] ?? '', 
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      role: json['role'] ?? 'STAFF', 
      branchId: json['branchId'] is Map 
          ? json['branchId']['_id'] ?? '' 
          : json['branchId'] ?? '',
      isActive: json['isActive'] ?? true,
      accessibleRoutes: json['accessibleRoutes'] != null
          ? List<String>.from(json['accessibleRoutes'])
          : [],
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
      
      // 🚀 PARSING THEM FROM MONGODB
    // 🚀 BULLETPROOF PARSING
      salary: (json['salary'] as num?)?.toDouble() ?? 0.0,
      loanRemaining: (loanData['remainingAmount'] as num?)?.toDouble() ?? 0.0,
      loanPrincipal: (loanData['principalAmount'] as num?)?.toDouble() ?? 0.0,
      trustScore: loanData['trustScore'] ?? 750,
      repayments: loanData['repayments'] ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'role': role,
      'branchId': branchId,
      'isActive': isActive,
      'accessibleRoutes': accessibleRoutes,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
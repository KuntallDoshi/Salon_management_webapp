class StaffModel {
  final String id;
  final String name;
  final String role;
  final bool isBusy;
  final String? branchId; 
  final bool isActive;
  
  // 🚀 FINANCIAL TRACKING FIELDS ADDED HERE
  final double salary;
  final double loanRemaining;
  final double loanPrincipal;
  final int trustScore;
  final List<dynamic> repayments;

  StaffModel({
    required this.id, 
    required this.name, 
    required this.role, 
    this.isBusy = false, 
    this.branchId,
    this.isActive = true,
    this.salary = 0.0,
    this.loanRemaining = 0.0,
    this.loanPrincipal = 0.0,
    this.trustScore = 750,
    this.repayments = const [],
  });

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    final loanData = json['loan'] ?? {};

    return StaffModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? 'Unknown Staff',
      role: json['role'] ?? 'Staff',
      isBusy: json['isBusy'] ?? false,
      isActive: json['isActive'] ?? true,
      branchId: json['branchId']?.toString(), 
      
// 🚀 BULLETPROOF PARSING
      salary: (json['salary'] as num?)?.toDouble() ?? 0.0,
      loanRemaining: (loanData['remainingAmount'] as num?)?.toDouble() ?? 0.0,
      loanPrincipal: (loanData['principalAmount'] as num?)?.toDouble() ?? 0.0,
      trustScore: loanData['trustScore'] ?? 750,
      repayments: loanData['repayments'] ?? [],
    );
  }
}

class ServiceModel {
  final String id;
  final String name;
  final String category; 
  final String genderCategory;
  final double price;
  final bool isActive; 

  ServiceModel({
    required this.id, 
    required this.name, 
    required this.category, 
    required this.genderCategory, 
    required this.price,
    this.isActive = true, 
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? 'Unknown Service',
      category: json['category'] ?? 'other', 
      genderCategory: json['genderCategory'] ?? 'Unisex',
      price: (json['price'] ?? 0).toDouble(),
      isActive: json['isActive'] ?? true, 
    );
  }
}

class VisitRecordModel {
  final String id;
  final String visitorName;
  final String visitorPhone;
  final List<ServiceModel> services; 
  final StaffModel? assignedStaff;
  final DateTime arrivalTime;
  final DateTime? endTime; 
  final String status;
  final double? finalPrice; 
  final String visitorGender;
  final double discountPercent; 
  final String? paymentMethod; 

  VisitRecordModel({
    required this.id, 
    required this.visitorName, 
    required this.visitorPhone,
    required this.services, 
    this.assignedStaff, 
    required this.arrivalTime, 
    this.endTime, 
    required this.status, 
    this.finalPrice,
    this.discountPercent = 0.0, // 🚀 ADDED
    this.paymentMethod, // 🚀 ADDED
    this.visitorGender = 'Unisex'
  });

  double get totalBasePrice {
    double total = 0;
    for (var s in services) { total += s.price; }
    return total;
  }

  String get serviceNamesString {
    if (services.isEmpty) return 'No Services';
    return services.map((s) => s.name).join(', ');
  }

 factory VisitRecordModel.fromJson(Map<String, dynamic> json) {
    List<ServiceModel> parsedServices = [];
    
    if (json['services'] != null && json['services'] is List) {
      parsedServices = (json['services'] as List).map((s) => ServiceModel.fromJson(s)).toList();
    } 
    else if (json['serviceId'] != null && json['serviceId'] is Map<String, dynamic>) {
      parsedServices.add(ServiceModel.fromJson(json['serviceId']));
    }

    return VisitRecordModel(
      id: json['_id'] ?? '',
      visitorName: (json['visitorId'] is Map) ? (json['visitorId']['name'] ?? 'Walk-In') : 'Walk-In', 
      visitorPhone: (json['visitorId'] is Map) ? (json['visitorId']['phone'] ?? '') : '',
      services: parsedServices, 
      assignedStaff: (json['assignedStaffId'] is Map<String, dynamic>) ? StaffModel.fromJson(json['assignedStaffId']) : null,
      arrivalTime: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      status: json['status'] ?? 'in_progress',
      visitorGender: (json['visitorId'] is Map) ? (json['visitorId']['gender'] ?? 'Unisex') : 'Unisex', // 🚀 NEW PARSING
      // 🚀 SAFELY PARSE THEM HERE
      finalPrice: json['finalPrice'] != null ? (json['finalPrice'] as num).toDouble() : null, 
      discountPercent: json['discountPercent'] != null ? (json['discountPercent'] as num).toDouble() : 0.0,
      paymentMethod: json['paymentMethod'], 
    );
  }
}
class DashboardQueueItem {
  final String id;
  final String visitorName;
  final String serviceName;
  final String staffName;
  final String status;

  DashboardQueueItem({
    required this.id,
    required this.visitorName,
    required this.serviceName,
    required this.staffName,
    required this.status,
  });

  factory DashboardQueueItem.fromJson(Map<String, dynamic> json) {
    return DashboardQueueItem(
      id: json['_id'] ?? '',
      // Safely dig into the populated Mongoose objects
      visitorName: json['visitorId']?['name'] ?? 'Walk-in Client',
      serviceName: json['serviceId']?['name'] ?? 'Standard Service',
      staffName: json['assignedStaffId']?['name'] ?? 'Unassigned',
      status: json['status'] ?? 'waiting',
    );
  }
}

class DashboardAlertItem {
  final String id;
  final String productName;
  final int currentStock;
  final int threshold;

  DashboardAlertItem({
    required this.id,
    required this.productName,
    required this.currentStock,
    required this.threshold,
  });

  factory DashboardAlertItem.fromJson(Map<String, dynamic> json) {
    return DashboardAlertItem(
      id: json['_id'] ?? '',
      productName: json['product']?['name'] ?? 'Unknown Product',
      currentStock: json['currentStock'] ?? 0,
      threshold: json['product']?['lowStockThreshold'] ?? 10,
    );
  }
}
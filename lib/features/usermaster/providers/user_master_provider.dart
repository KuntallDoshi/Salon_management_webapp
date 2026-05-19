import 'package:flutter/material.dart';

// --- MODEL ---
class StaffUser {
  final String id;
  final String name;
  final String email;
  final String role; // e.g., 'Receptionist', 'Manager'
  final List<String> accessibleRoutes; // e.g., ['/dashboard', '/inventory']

  StaffUser(
      {required this.id,
      required this.name,
      required this.email,
      required this.role,
      required this.accessibleRoutes});
}

// --- PROVIDER ---
class UserMasterProvider with ChangeNotifier {
  // Dummy existing staff
  List<StaffUser> staffUsers = [
    StaffUser(
        id: '1',
        name: 'Super Admin',
        email: 'admin@salon.com',
        role: 'Owner',
        accessibleRoutes: [
          '/dashboard',
          '/inventory',
          '/visitors',
          '/revenue',
          '/usermaster'
        ]),
    StaffUser(
        id: '2',
        name: 'Aman Sharma',
        email: 'aman@salon.com',
        role: 'Receptionist',
        accessibleRoutes: ['/visitors']), // Receptionist only sees visitors
  ];

  void addStaffUser(String name, String email, String password, String role,
      List<String> routes) {
    // In the future, this will send the 'password' to your API to create the auth credentials.
    staffUsers.add(StaffUser(
      id: DateTime.now().toString(),
      name: name,
      email: email,
      role: role,
      accessibleRoutes: routes,
    ));
    notifyListeners();
  }

  void removeStaffUser(String id) {
    staffUsers.removeWhere((user) => user.id == id);
    notifyListeners();
  }
}

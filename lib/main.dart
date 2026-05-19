import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:heric_webapp/features/not_found_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/providers/location_provider.dart';
import 'core/providers/navigation_provider.dart';
import 'shared/layouts/geofence_wrapper.dart';
import 'shared/layouts/main_layout.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/my_profile_screen.dart';
import 'features/dashboard/providers/dashboard_provider.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/inventory/provider/inventory_provider.dart';
import 'features/inventory/screens/inventory_screen.dart';
import 'features/visitors/providers/staff_visitor_provider.dart';
import 'features/visitors/screens/staff_visitor_screen.dart';
import 'features/admin/providers/admin_provider.dart';
import 'features/admin/screens/admin_settings_screen.dart';
import 'features/revenue/providers/revenue_provider.dart';
import 'features/revenue/screens/revenue_screen.dart';
import 'features/usermaster/providers/user_master_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); 

  final authProvider = AuthProvider();
  final locationProvider = LocationProvider();

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('jwt_token');
  final userDataString = prefs.getString('user_data');

  if (token != null && userDataString != null) {
    await authProvider.initializeAuth();
    // 🚀 THE FIX: Passed the branchId here too!
    locationProvider.startTracking(
      authProvider.userRole ?? 'STAFF', 
      authProvider.currentUser?.branchId
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: locationProvider),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
        ChangeNotifierProvider(create: (_) => StaffVisitorProvider()),
        ChangeNotifierProvider(create: (_) => UserMasterProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => RevenueProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ],
      child: const SalonWebApp(),
    ),
  );
}

class SalonWebApp extends StatelessWidget {
  const SalonWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AuthProvider>().currentUser != null;

    return MaterialApp(
      title: 'Herik Admin Panel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black87),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),

      initialRoute: isLoggedIn ? '/dashboard' : '/login',

      routes: {
        '/login': (context) => const LoginScreen(),
      },

      onGenerateRoute: (settings) {
        Widget page;
        int index = 0;

        switch (settings.name) {
          case '/dashboard':
            page = const DashboardScreen();
            index = 0;
            break;
          case '/inventory':
            page = const InventoryScreen();
            index = 1;
            break;
          case '/visitors':
            page = const StaffVisitorScreen();
            index = 2;
            break;
          case '/admin':
            page = const AdminSettingsScreen();
            index = 3;
            break;
          case '/revenue':
            page = const RevenueScreen();
            index = 4;
            break;
          case '/profile':
            page = const MyProfileScreen();
            index = 5;
            break;
          default:
            return null; 
        }

        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) {
            return GeofenceWrapper(
              child: MainLayout(
                currentIndex: index, 
                content: page,       
              ),
            );
          },
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        );
      },

     onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const NotFoundScreen(), 
        );
      },
    );
  }
}
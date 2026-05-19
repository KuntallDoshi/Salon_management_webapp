import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../../../core/api/api_service.dart'; 

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<dynamic>> _branchesFuture;
  
  static bool _hasShownLoanReminder = false;

  @override
  void initState() {
    super.initState();
    _branchesFuture = ApiService().getBranches(); 
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final branchId = authProvider.currentUser?.branchId;
      final role = authProvider.userRole; 
      
      if (branchId != null && role != null) {
        context.read<DashboardProvider>().fetchDashboardData(branchId, role);
      }

      final loanAmount = authProvider.currentUser?.loanRemaining ?? 0.0;
      if (role == 'STAFF' && loanAmount > 0 && !_hasShownLoanReminder) {
        _hasShownLoanReminder = true; 
        _showLoanReminder(loanAmount);
      }
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _showLoanReminder(double loanAmount) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 400, padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.account_balance_wallet, color: Colors.orange, size: 48)),
              const SizedBox(height: 24),
              const Text('Active Loan Reminder', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text('You currently have an active salon advance/loan of ₹${loanAmount.toStringAsFixed(0)}. This will be adjusted from your upcoming payroll.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('I UNDERSTAND', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold)),
                )
              )
            ],
          ),
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final dashboard = context.watch<DashboardProvider>();
    final size = MediaQuery.of(context).size;
    
    final isDesktop = size.width >= 1024;
    final isTablet = size.width >= 600 && size.width < 1024;
    final isMobile = size.width < 600;
    
    // 🚀 NEW: Fine-grained Role Checks
    final isGlobalAdmin = auth.userRole == 'ADMIN' || auth.userRole == 'OWNER';
    final isManager = auth.userRole == 'MANAGER';
    final isStaff = auth.userRole == 'STAFF';

    return Container(
      color: const Color(0xFFF8F9FA),
      child: dashboard.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16.0 : (isTablet ? 24.0 : 40.0)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── HEADER & FILTER ───
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_getGreeting()}, ${auth.currentUser?.name.split(' ')[0] ?? 'User'} 👋',
                              style: TextStyle(fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.w800, color: AppColors.primaryBlack),
                            ).animate().fade(duration: 500.ms).slideX(begin: -0.1),
                            
                            const SizedBox(height: 8),
                            
                            // Show Branch Name for Managers and Staff
                            if (!isGlobalAdmin && auth.currentUser?.branchId != null)
                              FutureBuilder<List<dynamic>>(
                                future: _branchesFuture,
                                builder: (context, snapshot) {
                                  String branchName = 'Loading Branch...';
                                  if (snapshot.hasData) {
                                    final branch = snapshot.data!.firstWhere((b) => b['_id'] == auth.currentUser!.branchId, orElse: () => null);
                                    if (branch != null) branchName = branch['name'];
                                  }
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(color: AppColors.primaryGold.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primaryGold.withOpacity(0.4))),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.storefront, size: 14, color: AppColors.primaryGold),
                                        const SizedBox(width: 6),
                                        Text(branchName, style: const TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                                      ],
                                    ),
                                  );
                                }
                              ).animate().fade(delay: 300.ms),

                            // Dynamic Subtitle
                            Text(
                              isGlobalAdmin ? 'System-wide performance and branch analytics.' : 
                              isManager ? 'Your branch performance and personal attendance.' : 
                              'Your personal performance and attendance.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: isMobile ? 14 : 16, letterSpacing: 0.5),
                            ).animate().fade(delay: 200.ms).slideX(begin: -0.1),
                          ],
                        ),
                      ),
                      
                      // 🚀 Managers AND Admins need the date filter!
                      if (isGlobalAdmin || isManager)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(color: AppColors.primaryBlack, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              dropdownColor: AppColors.primaryBlack,
                              value: dashboard.currentFilter,
                              icon: const Icon(Icons.calendar_month, color: AppColors.primaryGold, size: 18),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              items: const [
                                DropdownMenuItem(value: 'today', child: Text('Today')),
                                DropdownMenuItem(value: 'week', child: Text('This Week')),
                                DropdownMenuItem(value: 'month', child: Text('This Month')),
                                DropdownMenuItem(value: 'year', child: Text('This Year')),
                                DropdownMenuItem(value: 'custom', child: Text('Custom Date...')), 
                              ],
                              onChanged: (val) async {
                                if (val == 'custom') {
                                  DateTimeRange? pickedRange = await showDateRangePicker(
                                    context: context,
                                    firstDate: DateTime(2020), 
                                    lastDate: DateTime.now(), 
                                    builder: (context, child) => Theme(
                                      data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primaryBlack, onPrimary: AppColors.primaryGold, surface: Colors.white, onSurface: AppColors.primaryBlack)),
                                      child: child!,
                                    ),
                                  );

                                  if (pickedRange != null && context.mounted) {
                                    context.read<DashboardProvider>().fetchDashboardData(
                                      auth.currentUser!.branchId, auth.userRole!, filter: 'custom', start: pickedRange.start, end: pickedRange.end
                                    );
                                  }
                                } else if (val != null && context.mounted) {
                                  context.read<DashboardProvider>().fetchDashboardData(auth.currentUser!.branchId, auth.userRole!, filter: val);
                                }
                              },
                            ),
                          ),
                        ).animate().fade(delay: 400.ms).scale()
                      else if (!isMobile) 
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today, size: 16, color: AppColors.primaryGold),
                              const SizedBox(width: 8),
                              Text(DateTime.now().toLocal().toString().split(' ')[0], style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
                            ],
                          ),
                        ).animate().fade(delay: 400.ms).scale(),
                    ],
                  ),

                  SizedBox(height: isMobile ? 24 : 32),

                  // 🚀 ROUTE TO THE CORRECT DASHBOARD
                  if (isGlobalAdmin) 
                    _buildAdminDashboard(dashboard, isDesktop, isMobile)
                  else if (isManager)
                    _buildManagerDashboard(dashboard, isDesktop, isMobile)
                  else 
                    _buildStaffDashboard(dashboard, isDesktop, isMobile),
                ],
              ),
            ),
    );
  }

  // =========================================================================
  // 1. GLOBAL ADMIN VIEW 
  // =========================================================================
  Widget _buildAdminDashboard(DashboardProvider dashboard, bool isDesktop, bool isMobile) {
    int crossAxisCount = isDesktop ? 4 : (isMobile ? 1 : 2);
    double childAspectRatio = isDesktop ? 1.8 : (isMobile ? 2.5 : 2.0);

    return Column(
      children: [
        GridView.count(
          crossAxisCount: crossAxisCount, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 24, mainAxisSpacing: 24, childAspectRatio: childAspectRatio,
          children: [
            _PremiumStatCard(title: 'Filtered Revenue', value: '₹${dashboard.dailyRevenue.toStringAsFixed(0)}', icon: Icons.currency_rupee, delay: 300, isMoney: true, gradientColors: [Colors.green.shade50, Colors.white]),
            _PremiumStatCard(title: 'Visitors (Filtered)', value: '${dashboard.todayVisitors}', icon: Icons.people_alt, delay: 400, gradientColors: [Colors.blue.shade50, Colors.white]),
            _PremiumStatCard(title: 'All Branch Visitors', value: '${dashboard.allBranchVisitors}', icon: Icons.public, delay: 500, gradientColors: [Colors.purple.shade50, Colors.white]),
            _PremiumStatCard(title: 'Top Service', value: dashboard.mostUsedService, icon: Icons.star_border, delay: 600, isText: true, gradientColors: [AppColors.primaryGold.withOpacity(0.1), Colors.white]),
          ],
        ),
        const SizedBox(height: 32),
        
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: _RevenueChartCard(chartValues: dashboard.chartValues, chartLabels: dashboard.chartLabels, filterName: dashboard.currentFilter).animate().fade(delay: 700.ms).slideY(begin: 0.1)),
              const SizedBox(width: 24),
              Expanded(flex: 3, child: _BranchRevenueCard(revenues: dashboard.branchRevenues).animate().fade(delay: 800.ms).slideY(begin: 0.1)),
            ],
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RevenueChartCard(chartValues: dashboard.chartValues, chartLabels: dashboard.chartLabels, filterName: dashboard.currentFilter).animate().fade(delay: 700.ms).slideY(begin: 0.1),
              const SizedBox(height: 24),
              _BranchRevenueCard(revenues: dashboard.branchRevenues).animate().fade(delay: 800.ms).slideY(begin: 0.1),
            ],
          ),
      ],
    );
  }

  // =========================================================================
  // 2. MANAGER VIEW (Hybrid: Branch Stats + Personal Attendance)
  // =========================================================================
  Widget _buildManagerDashboard(DashboardProvider dashboard, bool isDesktop, bool isMobile) {
    int crossAxisCount = isDesktop ? 4 : (isMobile ? 1 : 2);
    double childAspectRatio = isDesktop ? 1.8 : (isMobile ? 2.5 : 2.0);

    int hours = (dashboard.totalMinutesWorked / 60).floor();
    int mins = dashboard.totalMinutesWorked % 60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: crossAxisCount, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 24, mainAxisSpacing: 24, childAspectRatio: childAspectRatio,
          children: [
            _PremiumStatCard(title: 'Branch Revenue', value: '₹${dashboard.dailyRevenue.toStringAsFixed(0)}', icon: Icons.store, delay: 300, isMoney: true, gradientColors: [Colors.green.shade50, Colors.white]),
            _PremiumStatCard(title: 'Branch Visitors', value: '${dashboard.todayVisitors}', icon: Icons.people_alt, delay: 400, gradientColors: [Colors.blue.shade50, Colors.white]),
            _PremiumStatCard(title: 'Top Service', value: dashboard.mostUsedService, icon: Icons.star_border, delay: 500, isText: true, gradientColors: [AppColors.primaryGold.withOpacity(0.1), Colors.white]),
            _PremiumStatCard(title: 'My Time Logged', value: '${hours}h ${mins}m', icon: Icons.access_time, delay: 600, gradientColors: [Colors.purple.shade50, Colors.white]),
          ],
        ),
        
        const SizedBox(height: 32),

        // Shared Attendance Widget
        _buildAttendanceStatusCard(dashboard, isMobile),

        const SizedBox(height: 32),

        // Branch Revenue Chart
        _RevenueChartCard(chartValues: dashboard.chartValues, chartLabels: dashboard.chartLabels, filterName: dashboard.currentFilter).animate().fade(delay: 700.ms).slideY(begin: 0.1),
      ],
    );
  }

  // =========================================================================
  // 3. STAFF VIEW (Personal Stats + Attendance)
  // =========================================================================
  Widget _buildStaffDashboard(DashboardProvider dashboard, bool isDesktop, bool isMobile) {
    int hours = (dashboard.totalMinutesWorked / 60).floor();
    int mins = dashboard.totalMinutesWorked % 60;
    int crossAxisCount = isDesktop ? 3 : (isMobile ? 1 : 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: crossAxisCount, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 24, mainAxisSpacing: 24, childAspectRatio: isDesktop ? 1.8 : 2.5,
          children: [
            _PremiumStatCard(title: 'My Revenue Today', value: '₹${dashboard.personalRevenue.toStringAsFixed(0)}', icon: Icons.account_balance_wallet, delay: 300, isMoney: true, gradientColors: [Colors.green.shade50, Colors.white]),
            _PremiumStatCard(title: 'Jobs Completed', value: '${dashboard.personalJobs}', icon: Icons.content_cut, delay: 400, gradientColors: [Colors.blue.shade50, Colors.white]),
            _PremiumStatCard(title: 'Time Logged Today', value: '${hours}h ${mins}m', icon: Icons.access_time, delay: 500, gradientColors: [Colors.purple.shade50, Colors.white]),
          ],
        ),
        
        const SizedBox(height: 32),

        // Shared Attendance Widget
        _buildAttendanceStatusCard(dashboard, isMobile),
      ],
    );
  }

  // =========================================================================
  // REUSABLE ATTENDANCE WIDGET (For Managers & Staff)
  // =========================================================================
  Widget _buildAttendanceStatusCard(DashboardProvider dashboard, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: dashboard.isClockedIn ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1), 
              shape: BoxShape.circle,
              boxShadow: dashboard.isClockedIn ? [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 12, spreadRadius: 2)] : [],
            ),
            child: Icon(dashboard.isClockedIn ? Icons.work : Icons.home, color: dashboard.isClockedIn ? Colors.green : Colors.orange, size: 32),
          )
          .animate(target: dashboard.isClockedIn ? 1 : 0) // PULSING EFFECT WHEN CLOCKED IN
          .scaleXY(end: 1.1, duration: 1000.ms, curve: Curves.easeInOutSine)
          .then(delay: 0.ms).scaleXY(end: 1.0/1.1, duration: 1000.ms, curve: Curves.easeInOutSine),

          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Status', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(dashboard.isClockedIn ? 'You are actively Clocked In' : 'You are currently Clocked Out', style: TextStyle(fontSize: isMobile ? 18 : 24, fontWeight: FontWeight.bold, color: dashboard.isClockedIn ? Colors.green.shade700 : AppColors.primaryBlack)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade(delay: 600.ms).slideY(begin: 0.1);
  }
}

// ---------------------------------------------------------
// WIDGET: UNIQUE BRANCH REVENUE PROGRESS BARS
// ---------------------------------------------------------
class _BranchRevenueCard extends StatelessWidget {
  final List<Map<String, dynamic>> revenues;
  const _BranchRevenueCard({required this.revenues});

  @override
  Widget build(BuildContext context) {
    double networkTotal = revenues.fold(0.0, (sum, branch) => sum + (branch['revenue'] ?? 0));
    if (networkTotal == 0) networkTotal = 1; 

    return Container(
      height: 400, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Branch Performance', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
          const SizedBox(height: 4),
          Text('Revenue Share & Contributions', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          const SizedBox(height: 24),
          Expanded(
            child: revenues.isEmpty
                ? Center(child: Text("No branch data available", style: TextStyle(color: Colors.grey.shade500)))
                : ListView.separated(
                    itemCount: revenues.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 20),
                    itemBuilder: (context, index) {
                      final branch = revenues[index];
                      double branchRev = (branch['revenue'] ?? 0).toDouble();
                      double percentage = branchRev / networkTotal;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(branch['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlack, fontSize: 14), overflow: TextOverflow.ellipsis)),
                              Text('₹${branchRev.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Stack(
                            children: [
                              Container(height: 8, width: double.infinity, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4))),
                              FractionallySizedBox(
                                widthFactor: percentage,
                                child: Container(height: 8, decoration: BoxDecoration(color: AppColors.primaryGold, borderRadius: BorderRadius.circular(4))),
                              ).animate().scaleX(begin: 0, duration: 1.seconds, curve: Curves.easeOutCubic, alignment: Alignment.centerLeft),
                            ],
                          )
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// WIDGET: Premium Gradient Stat Card
// ---------------------------------------------------------
class _PremiumStatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final int delay;
  final bool isMoney;
  final bool isText;
  final List<Color>? gradientColors;

  const _PremiumStatCard({required this.title, required this.value, required this.icon, required this.delay, this.isMoney = false, this.isText = false, this.gradientColors});

  @override
  State<_PremiumStatCard> createState() => _PremiumStatCardState();
}

class _PremiumStatCardState extends State<_PremiumStatCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), curve: Curves.easeOutBack,
        transform: Matrix4.translationValues(0, _isHovering ? -8 : 0, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(16),
          gradient: widget.gradientColors != null ? LinearGradient(colors: widget.gradientColors!, begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
          boxShadow: [BoxShadow(color: _isHovering ? AppColors.primaryGold.withOpacity(0.15) : Colors.black.withOpacity(0.04), blurRadius: _isHovering ? 25 : 15, offset: Offset(0, _isHovering ? 12 : 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primaryBlack, borderRadius: BorderRadius.circular(12)), child: Icon(widget.icon, color: AppColors.primaryGold, size: 20)),
                Icon(Icons.arrow_outward, color: _isHovering ? AppColors.primaryBlack : Colors.transparent, size: 18),
              ],
            ),
            const Spacer(),
            Text(widget.value, style: TextStyle(fontSize: widget.isText ? 20 : 28, fontWeight: FontWeight.w800, color: widget.isMoney ? Colors.green.shade800 : AppColors.primaryBlack), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(widget.title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5), overflow: TextOverflow.ellipsis),
          ],
        ),
      ).animate().fade(delay: widget.delay.ms, duration: 600.ms).slideY(begin: 0.1, curve: Curves.easeOut),
    );
  }
}

// ---------------------------------------------------------
// WIDGET: Revenue Chart
// ---------------------------------------------------------
class _RevenueChartCard extends StatelessWidget {
  final List<double> chartValues;
  final List<String> chartLabels;
  final String filterName;
  
  const _RevenueChartCard({required this.chartValues, required this.chartLabels, required this.filterName});

  @override
  Widget build(BuildContext context) {
    List<FlSpot> chartSpots = [];
    for (int i = 0; i < chartValues.length; i++) {
      chartSpots.add(FlSpot(i.toDouble(), chartValues[i]));
    }

    double maxY = 1000.0; 
    for (double val in chartValues) { if (val > maxY) maxY = val; }
    maxY = maxY * 1.2; 

   String titleTimeframe = 'Last 7 Days Trend'; // Fixed to 7 days

    return Container(
      height: 400, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('System Revenue Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
          const SizedBox(height: 4),
          Text(titleTimeframe, style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          const SizedBox(height: 32),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0, maxY: (chartValues.reduce((a, b) => a > b ? a : b) + 1000),
gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1000),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value == maxY) return const Text('');
                        return Text('₹${(value/1000).toStringAsFixed(0)}k', style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold));
                      }
                    )
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, reservedSize: 30, 
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < chartLabels.length) {
                          if (chartLabels.length == 30 && index % 5 != 0 && index != 29) return const Text('');
                          return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(chartLabels[index], style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: index == chartLabels.length - 1 ? FontWeight.bold : FontWeight.normal)));
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
             lineBarsData: [
  LineChartBarData(
    spots: chartSpots,
    isCurved: filterName != 'today', // 🚀 Disable curve for Today
    color: AppColors.primaryBlack, 
    barWidth: 4, 
    isStrokeCapRound: true, 
    // 🚀 Hide dots if it's just 'today' to make it look like a bar/flat line
    dotData: FlDotData(show: filterName != 'today'), 
    belowBarData: BarAreaData(
      show: true, 
      gradient: LinearGradient(
        colors: [AppColors.primaryGold.withOpacity(0.4), AppColors.primaryGold.withOpacity(0.0)], 
        begin: Alignment.topCenter, 
        end: Alignment.bottomCenter
      )
    ),
  ),
],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
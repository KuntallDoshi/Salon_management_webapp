import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/constants/app_colors.dart';
import '../providers/staff_visitor_provider.dart';
import '../models/visitor_models.dart';

class StaffProfileScreen extends StatefulWidget {
  final StaffModel staff;

  const StaffProfileScreen({super.key, required this.staff});

  @override
  State<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends State<StaffProfileScreen> {
  String _currentView = 'Work History'; // 🚀 Now uses Tabs
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StaffVisitorProvider>().fetchStaffProfile(widget.staff.id);
    });
  }

  List<T> _getPaginatedData<T>(List<T> source) {
    int startIndex = (_currentPage - 1) * _itemsPerPage;
    if (startIndex >= source.length) return [];
    int endIndex = startIndex + _itemsPerPage;
    if (endIndex > source.length) endIndex = source.length;
    return source.sublist(startIndex, endIndex);
  }

  // 🚀 FORMAT DATE HELPER (DD-MM-YYYY HH:MM)
  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    final localDate = date.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final year = localDate.year.toString();
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');
    return "$day-$month-$year $hour:$minute";
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StaffVisitorProvider>();
    final size = MediaQuery.of(context).size;
    
    // 🚀 Responsive Breakpoints
    final isDesktop = size.width >= 1024;
    final isMobile = size.width < 600;

    List<dynamic> currentDataList = _currentView == 'Work History' 
        ? provider.selectedStaffVisits 
        : provider.selectedStaffLogs;

    final totalPages = (currentDataList.length / _itemsPerPage).ceil();
    final paginatedData = _getPaginatedData(currentDataList);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryBlack),
        title: Text('${widget.staff.name}\'s Profile', style: const TextStyle(color: AppColors.primaryBlack, fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16.0 : 40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── PREMIUM PROFILE HEADER (RESPONSIVE) ───
            Container(
              padding: EdgeInsets.all(isMobile ? 24 : 32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryBlack, Color(0xFF2C2C2C)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20), 
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))]
              ),
              child: isMobile ? _buildMobileProfileHeader(provider) : _buildDesktopProfileHeader(provider),
            ).animate().fade(duration: 500.ms).slideY(begin: 0.1),

            const SizedBox(height: 32),

            // ─── UNIFIED CONTROL CENTER (TABS) ───
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))]),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _buildCustomTabBar(), // 🚀 Sleek Segmented Tabs
                    ),
                  ),
                ],
              ),
            ).animate().fade(delay: 200.ms).slideY(begin: 0.05),

            const SizedBox(height: 24),

            // ─── PREMIUM DATA TABLE WRAPPER ───
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 2))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (provider.isProfileLoading)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: size.width - (isDesktop ? 100 : 40)),
                        child: _buildShimmerTable(), // 🚀 SHIMMER EFFECT
                      ),
                    )
                  else if (currentDataList.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(80.0), 
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.folder_open, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('No $_currentView found.', style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        )
                      )
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: size.width - (isDesktop ? 100 : 40)),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.grey.shade200),
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
                            headingTextStyle: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
                            dataRowMaxHeight: 70, dataRowMinHeight: 60,
                            columns: _currentView == 'Work History' 
                              ? const [DataColumn(label: Text('DATE/TIME')), DataColumn(label: Text('CUSTOMER')), DataColumn(label: Text('SERVICES')), DataColumn(label: Text('REVENUE')), DataColumn(label: Text('STATUS'))]
                              : const [DataColumn(label: Text('DATE')), DataColumn(label: Text('FIRST IN')), DataColumn(label: Text('LAST OUT')), DataColumn(label: Text('HOURS WORKED')), DataColumn(label: Text('STATUS'))],
                            rows: paginatedData.map((item) => _buildTableRow(item)).toList(),
                          ),
                        ),
                      ),
                    ),

                  // ─── PAGINATION FOOTER ───
                  if (!provider.isProfileLoading && currentDataList.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (!isMobile)
                            Text('Showing ${(_currentPage - 1) * _itemsPerPage + 1} to ${(_currentPage * _itemsPerPage).clamp(0, currentDataList.length)} of ${currentDataList.length} entries', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
                          Row(
                            children: [
                              OutlinedButton(onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null, style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Prev')),
                              const SizedBox(width: 8),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: AppColors.primaryBlack, borderRadius: BorderRadius.circular(8)), child: Text('Page $_currentPage of ${totalPages == 0 ? 1 : totalPages}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              const SizedBox(width: 8),
                              OutlinedButton(onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null, style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Next')),
                            ],
                          )
                        ],
                      ),
                    ),
                ],
              ),
            ).animate().fade(delay: 400.ms).slideY(begin: 0.05),
          ],
        ),
      ),
    );
  }

  // ─── 🚀 THE NEW SLEEK TAB BAR ───
  Widget _buildCustomTabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['Work History', 'Attendance Logs'].map((tab) {
          final isActive = _currentView == tab;
          return GestureDetector(
            onTap: () => setState(() { _currentView = tab; _currentPage = 1; }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isActive ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : [],
              ),
              child: Text(tab, style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? AppColors.primaryBlack : Colors.grey.shade600)),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── RESPONSIVE HEADERS ───
  Widget _buildDesktopProfileHeader(StaffVisitorProvider provider) {
    return Row(
      children: [
        CircleAvatar(radius: 45, backgroundColor: AppColors.primaryGold, child: Text(widget.staff.name.isNotEmpty ? widget.staff.name[0] : '?', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.primaryBlack))),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.staff.name, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primaryGold.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Text(widget.staff.role.toUpperCase(), style: const TextStyle(color: AppColors.primaryGold, letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 12)),
              )
            ],
          ),
        ),
        if (!provider.isProfileLoading) ...[
          _buildStatBlock('Jobs Done', provider.selectedStaffVisits.length.toString(), false),
          Container(width: 1, height: 60, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 40)),
          _buildStatBlock('Revenue Generated', '₹${provider.selectedStaffTotalRevenue.toStringAsFixed(0)}', true),
        ]
      ],
    );
  }

  Widget _buildMobileProfileHeader(StaffVisitorProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(radius: 40, backgroundColor: AppColors.primaryGold, child: Text(widget.staff.name.isNotEmpty ? widget.staff.name[0] : '?', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primaryBlack))),
        const SizedBox(height: 16),
        Text(widget.staff.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: AppColors.primaryGold.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Text(widget.staff.role.toUpperCase(), style: const TextStyle(color: AppColors.primaryGold, letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 11)),
        ),
        const SizedBox(height: 24),
        if (!provider.isProfileLoading) ...[
          Container(height: 1, width: double.infinity, color: Colors.white24, margin: const EdgeInsets.only(bottom: 24)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatBlock('Jobs Done', provider.selectedStaffVisits.length.toString(), false, isCentered: true),
              _buildStatBlock('Revenue', '₹${provider.selectedStaffTotalRevenue.toStringAsFixed(0)}', true, isCentered: true),
            ],
          ),
        ]
      ],
    );
  }

  Widget _buildStatBlock(String label, String value, bool isMoney, {bool isCentered = false}) {
    return Column(
      crossAxisAlignment: isCentered ? CrossAxisAlignment.center : CrossAxisAlignment.end,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: isMoney ? Colors.greenAccent : Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
      ],
    );
  }

  // ─── SHIMMER LOADING EFFECT ───
  Widget _buildShimmerTable() {
    return Column(
      children: List.generate(6, (index) => Container(
        height: 60, width: 800,
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Expanded(flex: 2, child: Container(height: 16, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(width: 24),
            Expanded(flex: 1, child: Container(height: 16, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(width: 24),
            Expanded(flex: 1, child: Container(height: 16, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(width: 24),
            Expanded(flex: 1, child: Container(height: 16, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)))),
          ],
        ),
      )).animate(onPlay: (controller) => controller.repeat())
        .shimmer(duration: 1200.ms, color: Colors.white60), 
    );
  }

  DataRow _buildTableRow(dynamic item) {
    if (_currentView == 'Work History') {
      final v = item as VisitRecordModel;
      return DataRow(cells: [
        DataCell(Text(_formatDate(v.endTime), style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(Text(v.visitorName, style: const TextStyle(fontWeight: FontWeight.bold))),
        // 🚀 FIXED: Multi-Service text string implementation
        DataCell(Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)), 
          child: Text(v.serviceNamesString, overflow: TextOverflow.ellipsis, maxLines: 1, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey.shade700))
        )),
        // 🚀 FIXED: Multi-Service price calculation fallback
        DataCell(Text('+₹${v.finalPrice?.toStringAsFixed(0) ?? v.totalBasePrice.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 16))),
        DataCell(Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 18), const SizedBox(width: 6), Text('Done', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12))])),
      ]);
    } else {
      final log = item as Map<String, dynamic>;
      final sessions = log['sessions'] as List?;
      final firstIn = (sessions != null && sessions.isNotEmpty) ? DateTime.parse(sessions.first['clockInAt']).toLocal().toString().split(' ')[1].split('.')[0] : 'N/A';
      final lastSession = (sessions != null && sessions.isNotEmpty) ? sessions.last : null;
      final lastOut = (lastSession != null && lastSession['clockOutAt'] != null) ? DateTime.parse(lastSession['clockOutAt']).toLocal().toString().split(' ')[1].split('.')[0] : 'Still Working';
      final totalMins = log['totalMinutes'] ?? 0;
      
      DateTime? parsedDate;
      if (log['date'] != null) {
        try { parsedDate = DateTime.parse(log['date']); } catch (e) { parsedDate = null; }
      }
      
      return DataRow(cells: [
        DataCell(Text(parsedDate != null ? _formatDate(parsedDate).split(' ')[0] : (log['date'] ?? 'Unknown'), style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(firstIn, style: TextStyle(color: Colors.grey.shade700))),
        DataCell(Text(lastOut, style: TextStyle(color: Colors.grey.shade700))),
        DataCell(Text('${(totalMins / 60).floor()}h ${totalMins % 60}m', style: const TextStyle(fontWeight: FontWeight.w900))),
        DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(log['status']?.toString().toUpperCase() ?? 'PRESENT', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)))),
      ]);
    }
  }
}
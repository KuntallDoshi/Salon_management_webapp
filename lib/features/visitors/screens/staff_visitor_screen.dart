import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/staff_visitor_provider.dart';
import '../models/visitor_models.dart';
import '../../visitors/screens/staff_profile_screen.dart';

class StaffVisitorScreen extends StatefulWidget {
  const StaffVisitorScreen({super.key});

  @override
  State<StaffVisitorScreen> createState() => _StaffVisitorScreenState();
}

class _StaffVisitorScreenState extends State<StaffVisitorScreen> {
  String _currentView = 'Live Queue'; 
  String _searchQuery = '';
  int _currentPage = 1;
  final int _itemsPerPage = 10;
  
  // 🚀 ADDED DEBOUNCER FOR SEARCH
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final userBranchId = auth.currentUser?.branchId;
      final userRole = auth.userRole;
      
      final targetBranch = (userRole == 'ADMIN' || userRole == 'OWNER') ? 'all' : userBranchId;
      if (targetBranch != null) {
        context.read<StaffVisitorProvider>().fetchInitialData(targetBranch);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  List<T> _getPaginatedData<T>(List<T> source) {
    int startIndex = (_currentPage - 1) * _itemsPerPage;
    if (startIndex >= source.length) return [];
    int endIndex = startIndex + _itemsPerPage;
    if (endIndex > source.length) endIndex = source.length;
    return source.sublist(startIndex, endIndex);
  }

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
    final authProvider = context.watch<AuthProvider>();
    final size = MediaQuery.of(context).size;
    
    final isDesktop = size.width >= 1024;
    final isTablet = size.width >= 600 && size.width < 1024;
    final isMobile = size.width < 600;
    
    final isAdmin = authProvider.userRole == 'ADMIN' || authProvider.userRole == 'OWNER';

    // 🚀 USE LOCAL LIST FOR QUEUE, DB LIST FOR HISTORY
    List<VisitRecordModel> currentDataList = _currentView == 'Live Queue' 
        ? provider.activeVisits.where((v) => v.visitorName.toLowerCase().contains(_searchQuery.toLowerCase()) || v.visitorPhone.contains(_searchQuery)).toList()
        : provider.completedVisits; 

    // 🚀 ASSIGN PROPER PAGE COUNTS
    final totalPages = _currentView == 'Live Queue' ? provider.activeTotalPages : provider.historyTotalPages;
    final totalItems = _currentView == 'Live Queue' ? provider.activeTotalItems : provider.historyTotalItems;
    
    // 🚀 ONLY PAGINATE LOCALLY FOR LIVE QUEUE (History is already paginated by DB)
    final paginatedData = _currentView == 'Live Queue' ? _getPaginatedData(currentDataList) : currentDataList;

    return Container(
      color: const Color(0xFFF8F9FA),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16.0 : (isTablet ? 24.0 : 40.0)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Customer Management', style: TextStyle(fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.w800, color: AppColors.primaryBlack)).animate().fade(duration: 500.ms).slideX(begin: -0.1),
                      const SizedBox(height: 8),
                      Text('Manage the live queue, checkouts, and customer history.', style: TextStyle(color: Colors.grey.shade600, fontSize: isMobile ? 14 : 16)).animate().fade(delay: 200.ms).slideX(begin: -0.1),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: IconButton(
                    tooltip: 'Refresh Data',
                    icon: const Icon(Icons.refresh, color: AppColors.primaryBlack),
                    onPressed: () {
                      final branchId = provider.currentBranchId;
                      if (branchId != null) provider.fetchInitialData(branchId);
                    },
                  ),
                ).animate().fade().scale(),
              ],
            ),
            
            SizedBox(height: isMobile ? 24 : 32),

            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))]),
              child: isMobile 
                ? _buildMobileControls(provider, isAdmin, authProvider) 
                : _buildDesktopControls(provider, isAdmin, isDesktop, authProvider),
            ).animate().fade(delay: 300.ms).slideY(begin: 0.05),
            
            const SizedBox(height: 24),

            LayoutBuilder(
              builder: (context, constraints) {
                if (provider.isLoading) {
                  return _currentView == 'Live Queue' 
                    ? _buildShimmerGrid(isDesktop, isTablet) 
                    : _buildShimmerTable(constraints.maxWidth);
                } else if (_currentView == 'Live Queue') {
                  return _buildLiveQueueGrid(paginatedData, isDesktop, isTablet, provider);
                } else {
                  return _buildHistoryTable(paginatedData, totalItems, totalPages, isDesktop, constraints.maxWidth, provider); 
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['Live Queue', 'Visit History'].map((tab) {
          final isActive = _currentView == tab;
          return GestureDetector(
            onTap: () {
              setState(() { _currentView = tab; _currentPage = 1; _searchQuery = ''; });
              final provider = context.read<StaffVisitorProvider>();
              if (tab == 'Visit History') {
                provider.fetchVisitHistory(branchId: provider.currentBranchId ?? 'all', page: 1);
              } else {
                provider.fetchActiveQueue(branchId: provider.currentBranchId ?? 'all');
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

  Widget _buildMiniServiceChip(String text, {bool isMore = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isMore ? AppColors.primaryGold.withOpacity(0.2) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isMore ? AppColors.primaryGold.withOpacity(0.5) : Colors.grey.shade200)
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isMore ? AppColors.primaryGold : Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildDesktopControls(StaffVisitorProvider provider, bool isAdmin, bool isDesktop, AuthProvider auth) {
    return Wrap(
      spacing: 16, runSpacing: 16,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Wrap(
          spacing: 16, runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildCustomTabBar(),
            
            if (isAdmin && provider.branches.isNotEmpty)
              Container(
                height: 48, padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: provider.currentBranchId,
                    icon: const Icon(Icons.storefront, color: AppColors.primaryGold),
                    style: const TextStyle(color: AppColors.primaryBlack, fontWeight: FontWeight.bold),
                    items: [
                      const DropdownMenuItem<String>(value: 'all', child: Text('All Branches', style: TextStyle(fontWeight: FontWeight.bold))),
                      ...provider.branches.map((b) => DropdownMenuItem<String>(value: b['_id'], child: Text(b['name'], style: const TextStyle(fontWeight: FontWeight.bold))))
                    ],
                    onChanged: (val) { if (val != null && val != provider.currentBranchId) provider.fetchInitialData(val); },
                  ),
                ),
              ),
            Container(
              width: isDesktop ? 250 : 200, height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: TextField(
                onChanged: (val) {
                  setState(() { _searchQuery = val; _currentPage = 1; });
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 500), () {
                    final branch = provider.currentBranchId ?? 'all';
                    if (_currentView == 'Live Queue') provider.fetchActiveQueue(branchId: branch, search: val);
                    else provider.fetchVisitHistory(branchId: branch, search: val, page: 1);
                  });
                },
                decoration: const InputDecoration(icon: Icon(Icons.search, color: Colors.grey), hintText: 'Search name/phone...', border: InputBorder.none),
              ),
            ),
            if (_currentView == 'Visit History')
              Container(
                height: 48, width: 48,
                decoration: BoxDecoration(color: AppColors.primaryBlack, borderRadius: BorderRadius.circular(12)),
                child: IconButton(
                  tooltip: 'Advanced Filters',
                  icon: const Icon(Icons.tune, color: AppColors.primaryGold),
                  onPressed: () => _showFilterDialog(context, provider),
                ),
              ),
          ],
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, foregroundColor: AppColors.primaryGold, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () => _showNewWalkInDialog(context, provider, auth), 
          icon: const Icon(Icons.person_add_alt_1), label: const Text('NEW WALK-IN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
      ],
    );
  }

  Widget _buildMobileControls(StaffVisitorProvider provider, bool isAdmin, AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: _buildCustomTabBar()),
        const SizedBox(height: 12),
        if (isAdmin && provider.branches.isNotEmpty) ...[
          Container(
            height: 54, padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true, value: provider.currentBranchId,
                icon: const Icon(Icons.storefront, color: AppColors.primaryGold),
                style: const TextStyle(color: AppColors.primaryBlack, fontWeight: FontWeight.bold),
                items: [
                  const DropdownMenuItem<String>(value: 'all', child: Text('All Branches', style: TextStyle(fontWeight: FontWeight.bold))),
                  ...provider.branches.map((b) => DropdownMenuItem<String>(value: b['_id'], child: Text(b['name'], style: const TextStyle(fontWeight: FontWeight.bold))))
                ],
                onChanged: (val) { if (val != null && val != provider.currentBranchId) provider.fetchInitialData(val); },
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: Container(
                height: 54, padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                child: TextField(
                  onChanged: (val) {
                    setState(() { _searchQuery = val; _currentPage = 1; });
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(const Duration(milliseconds: 500), () {
                      final branch = provider.currentBranchId ?? 'all';
                      if (_currentView == 'Live Queue') provider.fetchActiveQueue(branchId: branch, search: val);
                      else provider.fetchVisitHistory(branchId: branch, search: val, page: 1);
                    });
                  },
                  decoration: const InputDecoration(icon: Icon(Icons.search, color: Colors.grey), hintText: 'Search name/phone...', border: InputBorder.none),
                ),
              ),
            ),
            if (_currentView == 'Visit History') ...[
              const SizedBox(width: 8),
              Container(
                height: 54, width: 54,
                decoration: BoxDecoration(color: AppColors.primaryBlack, borderRadius: BorderRadius.circular(12)),
                child: IconButton(icon: const Icon(Icons.tune, color: AppColors.primaryGold), onPressed: () => _showFilterDialog(context, provider)),
              ),
            ]
          ],
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, foregroundColor: AppColors.primaryGold, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () => _showNewWalkInDialog(context, provider, auth),
          icon: const Icon(Icons.person_add_alt_1), label: const Text('NEW WALK-IN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
      ],
    );
  }

  Widget _buildShimmerGrid(bool isDesktop, bool isTablet) {
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 3 : (isTablet ? 2 : 1), crossAxisSpacing: 24, mainAxisSpacing: 24, mainAxisExtent: 240,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(children: [Container(height: 40, width: 40, decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle)), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(height: 16, width: 100, color: Colors.grey.shade200), const SizedBox(height: 8), Container(height: 12, width: 80, color: Colors.grey.shade200)])]),
            const Spacer(),
            Container(height: 40, width: double.infinity, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8))),
          ],
        ),
      ).animate(onPlay: (controller) => controller.repeat()).shimmer(duration: 1200.ms, color: Colors.white60),
    );
  }

  Widget _buildShimmerTable(double maxWidth) {
    return SizedBox(
      width: maxWidth,
      child: Column(
        children: List.generate(6, (index) => Container(
          height: 60,
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100)), color: Colors.white),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(children: [Expanded(flex: 2, child: Container(height: 16, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)))), const SizedBox(width: 24), Expanded(flex: 1, child: Container(height: 16, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)))), const SizedBox(width: 24), Expanded(flex: 1, child: Container(height: 16, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)))), const SizedBox(width: 24), Expanded(flex: 1, child: Container(height: 16, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))))]),
        )).animate(onPlay: (controller) => controller.repeat()).shimmer(duration: 1200.ms, color: Colors.white60),
      ),
    );
  }

  Widget _buildLiveQueueGrid(List<VisitRecordModel> visits, bool isDesktop, bool isTablet, StaffVisitorProvider provider) {
    if (visits.isEmpty) return _buildEmptyState('Queue is Empty', 'No active visitors match your search.', Icons.event_seat_outlined);

    final authProvider = context.read<AuthProvider>();
    final isManager = authProvider.userRole == 'MANAGER';
    final isAdmin = authProvider.userRole == 'ADMIN' || authProvider.userRole == 'OWNER';
    
    final bool canEditLive = true; 
    final bool canDeleteLive = isAdmin || isManager;

    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 3 : (isTablet ? 2 : 1), 
        crossAxisSpacing: 24, mainAxisSpacing: 24, mainAxisExtent: 280, 
      ),
      itemCount: visits.length,
      itemBuilder: (context, index) {
        final visit = visits[index];
        final elapsedMinutes = DateTime.now().difference(visit.arrivalTime).inMinutes;

        List<String> serviceNames = visit.serviceNamesString.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        List<String> displayServices = serviceNames.take(2).toList();
        int remainingServices = serviceNames.length > 2 ? serviceNames.length - 2 : 0;

        return Container(
          padding: const EdgeInsets.all(20), 
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(height: 40, width: 40, decoration: BoxDecoration(color: AppColors.primaryGold.withOpacity(0.2), shape: BoxShape.circle), child: Center(child: Text(visit.visitorName.isNotEmpty ? visit.visitorName[0].toUpperCase() : '?', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlack, fontSize: 18)))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(visit.visitorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryBlack), overflow: TextOverflow.ellipsis),
                              Text(visit.visitorPhone, style: TextStyle(color: Colors.grey.shade500, fontSize: 12), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (canEditLive) IconButton(icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => _showEditVisitDialog(context, visit, provider, authProvider)),
                      if (canEditLive) const SizedBox(width: 8),
                      if (canDeleteLive) IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => _confirmDeleteVisit(context, visit.id, provider)),
                      if (canDeleteLive) const SizedBox(width: 8),
                      _buildBadge('In Progress', Colors.orange),
                    ],
                  ),
                ],
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()), 
              
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SERVICES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4, runSpacing: 4,
                            children: [
                              ...displayServices.map((s) => _buildMiniServiceChip(s)),
                              if (remainingServices > 0) _buildMiniServiceChip('+$remainingServices more', isMore: true),
                            ],
                          ),
                          const Spacer(), 
                          Text('₹${visit.totalBasePrice}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('STAFF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1)),
                          const SizedBox(height: 8),
                          Row(children: [const Icon(Icons.content_cut, size: 14, color: AppColors.primaryGold), const SizedBox(width: 4), Expanded(child: Text(visit.assignedStaff?.name ?? 'Unassigned', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis))]),
                          const Spacer(), 
                          Text('$elapsedMinutes mins ago', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16), 
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.green, elevation: 0, side: BorderSide(color: Colors.green.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () => _showCheckoutDialog(context, visit, provider),
                  child: const Text('CHECKOUT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              )
            ],
          ),
        ).animate().fade(delay: (50 * index).ms).scale(begin: const Offset(0.9, 0.9));
      },
    );
  }

  Widget _buildHistoryTable(List<VisitRecordModel> visits, int totalItems, int totalPages, bool isDesktop, double maxWidth, StaffVisitorProvider provider) {
    if (visits.isEmpty) return _buildEmptyState('No History', 'No past visits found.', Icons.history);

    final authProvider = context.read<AuthProvider>();
    final isAdmin = authProvider.userRole == 'ADMIN' || authProvider.userRole == 'OWNER';
    
    final bool canEditHistory = true; 
    final bool canDeleteHistory = isAdmin;

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: maxWidth), 
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.grey.shade200),
                child: DataTable(
                  columnSpacing: isDesktop ? 40 : 20, 
                  horizontalMargin: 24,
                  headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
                  headingTextStyle: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
                  dataRowMaxHeight: 70, dataRowMinHeight: 60,
                  columns: const [
                    DataColumn(label: Text('DATE & TIME')), 
                    DataColumn(label: Text('VISITOR')), 
                    DataColumn(label: Text('PHONE')), 
                    DataColumn(label: Text('SERVICES')), 
                    DataColumn(label: Text('SERVED BY')), 
                    DataColumn(label: Text('REVENUE & MODE')), 
                    DataColumn(label: Text('STATUS')), 
                    DataColumn(label: Text('ACTIONS')), 
                  ],
                  rows: visits.map((v) => DataRow(cells: [
                    DataCell(Text(_formatDate(v.endTime), style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(v.visitorName, style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text(v.visitorPhone, style: TextStyle(color: Colors.grey.shade600))),
                    DataCell(
                      InkWell(
                        onTap: () {
                          if (v.services.length > 1) {
                            _showServicesListDialog(context, v.services);
                          }
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), 
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade200)), 
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(v.services.isNotEmpty ? v.services.first.name : 'No Services', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade800)),
                              if (v.services.length > 1)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6.0),
                                  child: Text('+${v.services.length - 1} more', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppColors.primaryGold)),
                                )
                            ],
                          )
                        ),
                      )
                    ),
                    DataCell(Text(v.assignedStaff?.name ?? 'Unassigned')),
                    DataCell(Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('₹${v.finalPrice?.toStringAsFixed(0) ?? v.totalBasePrice}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                        if (v.paymentMethod != null && v.paymentMethod!.isNotEmpty) 
                          Text(v.paymentMethod!, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold))
                      ],
                    )),
                    DataCell(_buildBadge(v.status == 'cancelled' ? 'Cancelled' : 'Completed', v.status == 'cancelled' ? Colors.red : Colors.green)),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canEditHistory) IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue), onPressed: () => _showEditVisitDialog(context, v, provider, authProvider)),
                        if (canDeleteHistory) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _confirmDeleteVisit(context, v.id, provider)),
                      ],
                    )),
                  ])).toList(),
                ),
              ),
            ),
          ),
          
          // 🚀 SERVER-SIDE PAGINATION CONTROLS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (maxWidth > 500)
                  Text('Showing ${(_currentPage - 1) * _itemsPerPage + 1} to ${((_currentPage - 1) * _itemsPerPage + visits.length).clamp(0, totalItems)} of $totalItems entries', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _currentPage > 1 ? () {
                        setState(() => _currentPage--);
                        provider.fetchVisitHistory(branchId: provider.currentBranchId ?? 'all', search: _searchQuery, page: _currentPage);
                      } : null, 
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), 
                      child: const Text('Prev')
                    ),
                    const SizedBox(width: 8),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: AppColors.primaryBlack, borderRadius: BorderRadius.circular(8)), child: Text('Page $_currentPage of ${totalPages == 0 ? 1 : totalPages}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _currentPage < totalPages ? () {
                        setState(() => _currentPage++);
                        provider.fetchVisitHistory(branchId: provider.currentBranchId ?? 'all', search: _searchQuery, page: _currentPage);
                      } : null, 
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), 
                      child: const Text('Next')
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    ).animate().fade().slideY(begin: 0.05);
  }

  void _confirmDeleteVisit(BuildContext context, String visitId, StaffVisitorProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record?'),
        content: const Text('This will remove the visit from the dashboard and securely log the deletion in the backend audit system. Proceed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.black))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              String? err = await provider.deleteVisit(visitId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err ?? 'Visit deleted securely.'), backgroundColor: err == null ? Colors.green : Colors.red));
              }
            }, 
            child: const Text('Delete', style: TextStyle(color: Colors.white))
          ),
        ],
      )
    );
  }

  void _showEditVisitDialog(BuildContext context, VisitRecordModel visit, StaffVisitorProvider provider, AuthProvider auth) {
    final nameController = TextEditingController(text: visit.visitorName);
    final phoneController = TextEditingController(text: visit.visitorPhone);
    final discountController = TextEditingController(text: visit.discountPercent > 0 ? visit.discountPercent.toStringAsFixed(0) : '');
    
    TextEditingController? autoNameController;
    
    List<ServiceModel> selectedServices = List.from(visit.services); 
    StaffModel? selectedStaff = provider.staffList.firstWhere((s) => s.id == visit.assignedStaff?.id, orElse: () => provider.staffList.first);
    
    String selectedPaymentMethod = visit.paymentMethod ?? 'UPI'; 
    bool isProcessing = false; 
    bool isFetchingUser = false;
    String serviceSearchQuery = '';

    final bool isStaff = auth.userRole == 'STAFF';
    String lockedGender = visit.visitorGender.isNotEmpty ? visit.visitorGender : 'Unisex'; 

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        
        final size = MediaQuery.of(context).size;
        final isMobile = size.width < 600;
        final dialogWidth = isMobile ? size.width * 0.95 : 550.0;
        
        final availableStaff = provider.staffList;

        List<ServiceModel> sortedServices = provider.services
            .where((s) => s.name.toLowerCase().contains(serviceSearchQuery.toLowerCase()))
            .where((s) => s.genderCategory.toLowerCase() == lockedGender.toLowerCase() || s.genderCategory.toLowerCase() == 'unisex')
            .toList();

        sortedServices.sort((a, b) {
          final aSelected = selectedServices.any((s) => s.id == a.id);
          final bSelected = selectedServices.any((s) => s.id == b.id);
          if (aSelected && !bSelected) return -1;
          if (!aSelected && bSelected) return 1;
          return a.name.compareTo(b.name);
        });

        double currentBasePrice = selectedServices.fold(0.0, (sum, item) => sum + item.price);
        double currentDiscount = double.tryParse(discountController.text) ?? 0.0;
        double previewFinalPrice = visit.status == 'completed' 
            ? currentBasePrice - (currentBasePrice * (currentDiscount / 100))
            : currentBasePrice;

        return Dialog(
          insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40, vertical: isMobile ? 24 : 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isMobile ? 16 : 24)),
          backgroundColor: Colors.white,
          child: Container(
            width: dialogWidth, 
            padding: EdgeInsets.all(isMobile ? 20 : 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Icon(Icons.edit, color: AppColors.primaryGold, size: isMobile ? 24 : 28), 
                        const SizedBox(width: 8), 
                        Text('Edit Visit', style: TextStyle(fontSize: isMobile ? 20 : 22, fontWeight: FontWeight.bold))
                      ]),
                      IconButton(icon: const Icon(Icons.close), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => Navigator.pop(context))
                    ],
                  ),
                  SizedBox(height: isMobile ? 16 : 24),

                  TextField(
                    controller: phoneController, keyboardType: TextInputType.phone, maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Phone Number', 
                      prefixText: '+91 ',
                      prefixIcon: const Icon(Icons.phone, size: 20), 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: isFetchingUser 
                          ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGold)))
                          : null,
                    ),
                    onChanged: (val) async {
                      if (val.length == 10) {
                        setState(() => isFetchingUser = true);
                        try {
                          final returningVisitor = await provider.checkReturningVisitor(val);
                          if (context.mounted) {
                            setState(() {
                              isFetchingUser = false;
                              if (returningVisitor != null) {
                                nameController.text = returningVisitor['name'];
                                if (autoNameController != null) autoNameController!.text = returningVisitor['name'];
                                lockedGender = returningVisitor['gender'] ?? 'Unisex';
                                selectedServices.removeWhere((s) => s.genderCategory.toLowerCase() != lockedGender.toLowerCase() && s.genderCategory.toLowerCase() != 'unisex');
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer Found & Updated! 🎉', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
                              }
                            });
                          }
                        } catch (e) {
                          if (context.mounted) setState(() => isFetchingUser = false);
                        }
                      }
                    },
                  ),
                  SizedBox(height: isMobile ? 16 : 24),

                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: visit.visitorName),
                    optionsBuilder: (TextEditingValue textEditingValue) async {
                      if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                      final results = await provider.searchVisitors(textEditingValue.text);
                      return results.map((v) => "${v['name']} - ${v['phone']}").toList();
                    },
                    onSelected: (String selection) async {
                      final parts = selection.split(' - ');
                      nameController.text = parts[0];
                      if (parts.length > 1) { 
                        phoneController.text = parts[1]; 
                        final returningVisitor = await provider.checkReturningVisitor(parts[1]);
                        if (returningVisitor != null && context.mounted) {
                          setState(() {
                            lockedGender = returningVisitor['gender'] ?? 'Unisex';
                            selectedServices.removeWhere((s) => s.genderCategory.toLowerCase() != lockedGender.toLowerCase() && s.genderCategory.toLowerCase() != 'unisex');
                          });
                        }
                      }
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      if (autoNameController == null) {
                        autoNameController = textEditingController;
                        autoNameController!.addListener(() { nameController.text = autoNameController!.text; });
                      }
                      return TextField(
                        controller: textEditingController, 
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Visitor Name', 
                          prefixIcon: const Icon(Icons.person_outline, size: 20), 
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4, borderRadius: BorderRadius.circular(12), color: Colors.white,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: 200, maxWidth: isMobile ? size.width * 0.8 : 300),
                            child: ListView.separated(
                              padding: EdgeInsets.zero, shrinkWrap: true, itemCount: options.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (BuildContext context, int index) {
                                final String option = options.elementAt(index);
                                return InkWell(
                                  onTap: () => onSelected(option),
                                  child: Padding(padding: const EdgeInsets.all(16.0), child: Row(
                                    children: [
                                      const Icon(Icons.cloud_download_outlined, size: 16, color: Colors.blue),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(option, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                    ],
                                  )),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: isMobile ? 16 : 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Gender Category', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
                      const Text('Locked to Customer', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  IgnorePointer( 
                    ignoring: true, 
                    child: Opacity(
                      opacity: 0.6, 
                      child: Row(
                        children: [
                          Expanded(child: _buildGenderTile('Male', Icons.male, lockedGender.toLowerCase() == 'male', () {}, isMobile)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildGenderTile('Female', Icons.female, lockedGender.toLowerCase() == 'female', () {}, isMobile)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildGenderTile('Unisex', Icons.people, lockedGender.toLowerCase() == 'unisex', () {}, isMobile)),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: isMobile ? 16 : 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Select Services', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
                      Text('${selectedServices.length} Selected', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search (e.g. "Hair color")',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                      filled: true, fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                    ),
                    onChanged: (val) {
                      setState(() => serviceSearchQuery = val);
                    },
                  ),
                  const SizedBox(height: 8),

                  Container(
                    height: isMobile ? 180 : 250, 
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                    child: sortedServices.isEmpty 
                        ? Center(child: Text(serviceSearchQuery.isNotEmpty ? 'No services match.' : 'No services available for $lockedGender.', style: const TextStyle(color: Colors.grey, fontSize: 13)))
                        : ListView.builder(
                            itemCount: sortedServices.length,
                            itemBuilder: (context, index) {
                              final service = sortedServices[index];
                              final isSelected = selectedServices.any((s) => s.id == service.id);
                              return CheckboxListTile(
                                title: Text(service.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text('${service.category.toUpperCase()}  •  ₹${service.price}', style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                                value: isSelected,
                                activeColor: AppColors.primaryGold,
                                checkColor: AppColors.primaryBlack,
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                onChanged: (bool? val) {
                                  setState(() {
                                    if (val == true) selectedServices.add(service);
                                    else selectedServices.removeWhere((s) => s.id == service.id);
                                  });
                                },
                              );
                            },
                          ),
                  ),
                  SizedBox(height: isMobile ? 16 : 24),

                  const Text('Assign Staff Member', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 8),
                  
                  if (isStaff) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isMobile ? 12 : 16),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                      child: Row(
                        children: [
                          const Icon(Icons.lock, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text('${visit.assignedStaff?.name ?? auth.currentUser?.name} (Locked)', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 14)),
                        ],
                      ),
                    ),
                  ] else ...[
                    DropdownButtonFormField<StaffModel>(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: isMobile ? 12 : 16)
                      ),
                      isExpanded: true,
                      value: selectedStaff,
                      items: availableStaff.map((s) => DropdownMenuItem(value: s, child: Text('${s.name} (${s.role})', style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (val) => setState(() => selectedStaff = val),
                    ),
                  ],

                  if (visit.status == 'completed') ...[
                    SizedBox(height: isMobile ? 16 : 24),
                    
                    TextField(
                      controller: discountController, 
                      keyboardType: TextInputType.number, 
                      decoration: InputDecoration(labelText: 'Edit Discount (%)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.percent, color: Colors.grey)), 
                      onChanged: (val) => setState(() {}) 
                    ),
                    SizedBox(height: isMobile ? 16 : 24),

                    const Text('Update Payment Method', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildPaymentTile('UPI', Icons.qr_code_scanner, selectedPaymentMethod == 'UPI', () => setState(() => selectedPaymentMethod = 'UPI'))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildPaymentTile('Card', Icons.credit_card, selectedPaymentMethod == 'Card', () => setState(() => selectedPaymentMethod = 'Card'))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildPaymentTile('Cash', Icons.payments_outlined, selectedPaymentMethod == 'Cash', () => setState(() => selectedPaymentMethod = 'Cash'))),
                      ],
                    ),
                  ],

                  SizedBox(height: isMobile ? 24 : 32),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.2))),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Updated Total:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('₹${previewFinalPrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: Colors.green)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, padding: EdgeInsets.symmetric(vertical: isMobile ? 16 : 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: isProcessing ? null : () async {
                        
                        if (nameController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a name.'), backgroundColor: Colors.red));
                          return;
                        }
                        
                        if (phoneController.text.length != 10) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number must be exactly 10 digits.'), backgroundColor: Colors.red));
                          return;
                        }

                        if (selectedServices.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least 1 service.'), backgroundColor: Colors.red));
                          return;
                        }

                        setState(() => isProcessing = true); 
                        
                        String finalStaffId = isStaff 
                            ? (visit.assignedStaff?.id ?? auth.currentUser!.id) 
                            : selectedStaff!.id;

                        String? err = await provider.editVisit(
                          visit.id, nameController.text, phoneController.text, 
                          selectedServices.map((s) => s.id).toList(), finalStaffId, 
                          paymentMethod: visit.status == 'completed' ? selectedPaymentMethod : null,
                          discountPercent: visit.status == 'completed' ? currentDiscount : null,
                        );
                        
                        if (context.mounted) {
                          if (err == null) {
                             Navigator.pop(context);
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Visit updated successfully!'), backgroundColor: Colors.green));
                          } else {
                             setState(() => isProcessing = false);
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
                          }
                        }
                      },
                      child: isProcessing 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.primaryGold, strokeWidth: 2))
                        : const Text('UPDATE VISIT', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  void _showServicesListDialog(BuildContext context, List<ServiceModel> services) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.room_service, color: AppColors.primaryGold),
            SizedBox(width: 8),
            Text('Services Included', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: services.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('• ${s.name}', style: const TextStyle(fontWeight: FontWeight.w500))),
                Text('₹${s.price}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          )).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: Colors.black)))
        ],
      )
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(80.0),
      child: Center(
        child: Column(
          children: [
            Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle), child: Icon(icon, size: 64, color: Colors.grey.shade300)),
            const SizedBox(height: 24),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
            const SizedBox(height: 8),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
        child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)));
  }

  void _showFilterDialog(BuildContext context, StaffVisitorProvider provider) {
    String? selectedService;
    String? selectedStaff;
    String selectedStatus = 'All';
    final minController = TextEditingController();
    final maxController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: 400, padding: const EdgeInsets.all(32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Icon(Icons.tune, color: AppColors.primaryGold), SizedBox(width: 12), Text('Filter History', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 32),
                  
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: 'Filter by Service', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    value: selectedService, isExpanded: true,
                    items: provider.services.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                    onChanged: (val) => setState(() => selectedService = val),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: 'Served By (Staff)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    value: selectedStaff, isExpanded: true,
                    items: provider.staffList.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                    onChanged: (val) => setState(() => selectedStaff = val),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: 'Status', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    value: selectedStatus,
                    items: ['All', 'Completed', 'Cancelled'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) => setState(() => selectedStatus = val!),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(child: TextField(controller: minController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Min Rev', prefixIcon: const Icon(Icons.currency_rupee, size: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                      const SizedBox(width: 16),
                      Expanded(child: TextField(controller: maxController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Max Rev', prefixIcon: const Icon(Icons.currency_rupee, size: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                    ],
                  ),
                  const SizedBox(height: 40),
                  
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () {
                        Navigator.pop(context);
                        provider.fetchInitialData(provider.currentBranchId!); 
                      }, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('RESET', style: TextStyle(color: Colors.black)))),
                      const SizedBox(width: 16),
                      Expanded(child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () {
                          Navigator.pop(context);
                          double? minRev = double.tryParse(minController.text);
                          double? maxRev = double.tryParse(maxController.text);
                          
                          this.setState(() => _currentPage = 1);
                          provider.fetchVisitHistory(
                            branchId: provider.currentBranchId!, 
                            serviceId: selectedService, staffId: selectedStaff, status: selectedStatus, minRev: minRev, maxRev: maxRev, page: 1
                          );
                        },
                        child: const Text('APPLY', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold))
                      )),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  void _showNewWalkInDialog(BuildContext context, StaffVisitorProvider provider, AuthProvider auth) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    TextEditingController? autoNameController;
    
    String selectedGender = 'Unisex';
    String serviceSearchQuery = ''; 
    
    List<ServiceModel> selectedServices = []; 
    List<ServiceModel> availableServices = []; 
    StaffModel? selectedStaff;
    
    bool isProcessing = false; 
    bool isFetchingUser = false; 
    
    bool isSearchingServices = true; 
    bool isInit = false;
    Timer? debounceTimer;

    final bool isStaff = auth.userRole == 'STAFF';
    final bool isManager = auth.userRole == 'MANAGER';
    final bool isAdmin = auth.userRole == 'ADMIN' || auth.userRole == 'OWNER';
    
    String? selectedDialogBranch = (provider.currentBranchId != 'all') ? provider.currentBranchId : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        
        final size = MediaQuery.of(context).size;
        final isMobile = size.width < 600;
        final dialogWidth = isMobile ? size.width * 0.95 : 550.0;
        
        if (!isInit) {
          isInit = true;
          provider.searchLiveServices('', selectedGender).then((results) {
            if (context.mounted) {
              setState(() {
                availableServices = results;
                isSearchingServices = false;
              });
            }
          });
        }

        void triggerServiceSearch(String query, String gender) {
          setState(() => isSearchingServices = true); 
          if (debounceTimer?.isActive ?? false) debounceTimer!.cancel();
          debounceTimer = Timer(const Duration(milliseconds: 500), () async {
            final results = await provider.searchLiveServices(query, gender);
            if (context.mounted) {
              setState(() {
                availableServices = results;
                isSearchingServices = false; 
                selectedServices.removeWhere((s) => s.genderCategory.toLowerCase() != gender.toLowerCase() && s.genderCategory.toLowerCase() != 'unisex');
              });
            }
          });
        }
        
        final availableStaff = provider.getAvailableStaff().where((s) {
          if (selectedDialogBranch != null && s.branchId != selectedDialogBranch) return false;
          if (isManager && (s.role == 'ADMIN' || s.role == 'OWNER')) return false;
          return true;
        }).toList();

        return Dialog(
          insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40, vertical: isMobile ? 24 : 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isMobile ? 16 : 24)),
          backgroundColor: Colors.white,
          child: Container(
            width: dialogWidth, 
            padding: EdgeInsets.all(isMobile ? 20 : 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Icon(Icons.person_add, color: AppColors.primaryGold, size: isMobile ? 24 : 28), 
                        const SizedBox(width: 8), 
                        Text('New Walk-In', style: TextStyle(fontSize: isMobile ? 20 : 22, fontWeight: FontWeight.bold))
                      ]),
                      IconButton(
                        icon: const Icon(Icons.close), 
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(context)
                      )
                    ],
                  ),
                  SizedBox(height: isMobile ? 16 : 24),

                  if (isAdmin && provider.currentBranchId == 'all') ...[
                    Container(
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade300)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16), SizedBox(width: 8), Text('Global View Active', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))]),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                            hint: const Text('Select a specific branch for this Walk-In', style: TextStyle(fontSize: 13)),
                            value: selectedDialogBranch,
                            items: provider.branches.where((b) => b['_id'] != 'all').map((b) => DropdownMenuItem<String>(value: b['_id'], child: Text(b['name'], style: const TextStyle(fontSize: 14)))).toList(),
                            onChanged: (val) {
                              setState(() { selectedDialogBranch = val; selectedStaff = null; });
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isMobile ? 16 : 24),
                  ],

                  TextField(
                    controller: phoneController, 
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Phone Number', 
                      prefixText: '+91 ',
                      prefixStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                      prefixIcon: const Icon(Icons.phone, size: 20), 
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: isFetchingUser 
                          ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGold)))
                          : null,
                    ),
                    onChanged: (val) async {
                      if (val.length == 10) {
                        setState(() => isFetchingUser = true);
                        try {
                          final returningVisitor = await provider.checkReturningVisitor(val);
                          if (context.mounted) {
                            setState(() {
                              isFetchingUser = false;
                              if (returningVisitor != null) {
                                nameController.text = returningVisitor['name'];
                                autoNameController?.text = returningVisitor['name'];
                                selectedGender = returningVisitor['gender'] ?? 'Unisex';
                                triggerServiceSearch(serviceSearchQuery, selectedGender);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Returning Customer Found! 🎉', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
                              }
                            });
                          }
                        } catch (e) {
                          if (context.mounted) setState(() => isFetchingUser = false);
                        }
                      }
                    },
                  ),
                  SizedBox(height: isMobile ? 8 : 16),

                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) async {
                      if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                      final results = await provider.searchVisitors(textEditingValue.text);
                      return results.map((v) => "${v['name']} - ${v['phone']}").toList();
                    },
                    onSelected: (String selection) {
                      final parts = selection.split(' - ');
                      nameController.text = parts[0];
                      if (parts.length > 1) { phoneController.text = parts[1]; }
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      if (autoNameController == null) {
                        autoNameController = textEditingController;
                        autoNameController!.addListener(() { nameController.text = autoNameController!.text; });
                      }
                      return TextField(
                        controller: textEditingController, 
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'Visitor Name', 
                          prefixIcon: const Icon(Icons.person_outline, size: 20), 
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4, borderRadius: BorderRadius.circular(12), color: Colors.white,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: 200, maxWidth: isMobile ? size.width * 0.8 : 300),
                            child: ListView.separated(
                              padding: EdgeInsets.zero, shrinkWrap: true, itemCount: options.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (BuildContext context, int index) {
                                final String option = options.elementAt(index);
                                return InkWell(
                                  onTap: () => onSelected(option),
                                  child: Padding(padding: const EdgeInsets.all(16.0), child: Row(
                                    children: [
                                      const Icon(Icons.cloud_download_outlined, size: 16, color: Colors.blue),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(option, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                                    ],
                                  )),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: isMobile ? 16 : 24),

                  const Text('Gender Category', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildGenderTile('Male', Icons.male, selectedGender == 'Male', () { setState(() => selectedGender = 'Male'); triggerServiceSearch(serviceSearchQuery, 'Male'); }, isMobile)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildGenderTile('Female', Icons.female, selectedGender == 'Female', () { setState(() => selectedGender = 'Female'); triggerServiceSearch(serviceSearchQuery, 'Female'); }, isMobile)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildGenderTile('Unisex', Icons.people, selectedGender == 'Unisex', () { setState(() => selectedGender = 'Unisex'); triggerServiceSearch(serviceSearchQuery, 'Unisex'); }, isMobile)),
                    ],
                  ),
                  SizedBox(height: isMobile ? 16 : 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Select Services', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
                      Text('${selectedServices.length} Selected', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search (e.g. "Hair color")',
                      hintStyle: const TextStyle(fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                      filled: true, fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryGold)),
                    ),
                    onChanged: (val) {
                      serviceSearchQuery = val;
                      triggerServiceSearch(val, selectedGender); 
                    },
                  ),
                  const SizedBox(height: 8),

                  Container(
                    height: isMobile ? 180 : 250, 
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                    child: isSearchingServices 
                      ? ListView.builder(
                          itemCount: 5,
                          itemBuilder: (context, index) => ListTile(
                            leading: Container(width: 20, height: 20, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
                            title: Container(height: 12, width: double.infinity, color: Colors.grey.shade300),
                            subtitle: Container(height: 10, width: 80, color: Colors.grey.shade300),
                          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1.seconds, color: Colors.white60),
                        )
                      : availableServices.isEmpty 
                        ? Center(child: Text(serviceSearchQuery.isNotEmpty ? 'No services match.' : 'No services available.', style: const TextStyle(color: Colors.grey, fontSize: 13)))
                        : ListView.builder(
                            itemCount: availableServices.length,
                            itemBuilder: (context, index) {
                              final service = availableServices[index];
                              final isSelected = selectedServices.any((s) => s.id == service.id);
                              return CheckboxListTile(
                                title: Text(service.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text('${service.category.toUpperCase()}  •  ₹${service.price}', style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                                value: isSelected,
                                activeColor: AppColors.primaryGold,
                                checkColor: AppColors.primaryBlack,
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                onChanged: (bool? val) {
                                  setState(() {
                                    if (val == true) selectedServices.add(service);
                                    else selectedServices.removeWhere((s) => s.id == service.id);
                                  });
                                },
                              );
                            },
                          ),
                  ),
                  SizedBox(height: isMobile ? 16 : 24),

                  const Text('Assign Staff Member', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 8),
                  
                  if (isStaff) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isMobile ? 12 : 16),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                      child: Row(
                        children: [
                          const Icon(Icons.lock, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text('${auth.currentUser?.name} (You)', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 14)),
                        ],
                      ),
                    ),
                  ] else ...[
                    DropdownButtonFormField<StaffModel>(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: isMobile ? 12 : 16)
                      ),
                      isExpanded: true,
                      hint: Text(availableStaff.isEmpty ? (selectedDialogBranch == null ? 'Select branch first' : 'All staff busy!') : 'Choose available staff...', style: const TextStyle(fontSize: 13)),
                      value: selectedStaff,
                      items: availableStaff.map((s) => DropdownMenuItem(value: s, child: Text('${s.name} (${s.role})', style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (val) => setState(() => selectedStaff = val),
                    ),
                  ],

                  SizedBox(height: isMobile ? 24 : 40),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlack, 
                        padding: EdgeInsets.symmetric(vertical: isMobile ? 16 : 20), 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      onPressed: isProcessing ? null : () async {
                        if (isAdmin && provider.currentBranchId == 'all' && selectedDialogBranch == null) {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a specific branch for this Walk-In first.'), backgroundColor: Colors.red));
                           return;
                        }

                        String? finalAssignedStaffId;
                        if (isStaff) {
                          finalAssignedStaffId = auth.currentUser?.id;
                        } else if (selectedStaff != null) {
                          finalAssignedStaffId = selectedStaff!.id;
                        }

                        if (nameController.text.isNotEmpty && phoneController.text.length == 10 && selectedServices.isNotEmpty && finalAssignedStaffId != null) {
                          setState(() => isProcessing = true); 
                          
                          String? errorMessage = await provider.createNewVisit(
                            nameController.text, 
                            phoneController.text, 
                            selectedGender, 
                            selectedServices.map((s) => s.id).toList(), 
                            finalAssignedStaffId, 
                            branchId: selectedDialogBranch, 
                          );
                          
                          if (context.mounted) {
                            if (errorMessage == null) {
                               Navigator.pop(context);
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Visit started!'), backgroundColor: Colors.green));
                            } else {
                               setState(() => isProcessing = false);
                               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage, style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.red));
                            }
                          }
                        } else {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least 1 service, ensure a 10-digit phone, and assign staff.'), backgroundColor: Colors.red));
                        }
                      },
                      child: isProcessing 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.primaryGold, strokeWidth: 2))
                        : const Text('ASSIGN & START', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    ),
                  )
                ],
              ),
            ),
          ),
        ).animate().fade().scale(curve: Curves.easeOutBack, begin: const Offset(0.9, 0.9));
      }),
    );
  }
  
  Widget _buildGenderTile(String title, IconData icon, bool isSelected, VoidCallback onTap, bool isMobile) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
          decoration: BoxDecoration(color: isSelected ? AppColors.primaryBlack : Colors.white, border: Border.all(color: isSelected ? AppColors.primaryBlack : Colors.grey.shade300, width: 2), borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: isSelected ? AppColors.primaryGold : Colors.grey, size: isMobile ? 16 : 20),
            const SizedBox(width: 4),
            if (!isMobile || MediaQuery.of(context).size.width > 350)
              Flexible(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 11 : 14, color: isSelected ? Colors.white : Colors.grey), overflow: TextOverflow.ellipsis))
          ])),
    );
  }

  void _showCheckoutDialog(BuildContext context, VisitRecordModel visit, StaffVisitorProvider provider) {
    String selectedPaymentMethod = 'UPI'; 
    bool isProcessing = false; 
    final discountController = TextEditingController();
    List<String> serviceList = visit.serviceNamesString.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final dialogWidth = MediaQuery.of(context).size.width > 600 ? 450.0 : MediaQuery.of(context).size.width * 0.9;

    showDialog(
      context: context, barrierDismissible: false,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        
        double discountPercent = double.tryParse(discountController.text) ?? 0.0;
        double finalPrice = visit.totalBasePrice - (visit.totalBasePrice * (discountPercent / 100));

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          child: Container(
            width: dialogWidth, padding: const EdgeInsets.all(32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Row(children: [Icon(Icons.point_of_sale, color: Colors.green, size: 28), SizedBox(width: 12), Text('Checkout', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))]), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))]),
                  const SizedBox(height: 24),
                  
                  Container(
                    padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Customer', style: TextStyle(color: Colors.grey.shade600)), Expanded(child: Text(visit.visitorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis))]),
                        const SizedBox(height: 12),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Staff', style: TextStyle(color: Colors.grey.shade600)), Expanded(child: Text(visit.assignedStaff?.name ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right, overflow: TextOverflow.ellipsis))]),
                        
                        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
                        
                        Text('Services Included (${serviceList.length})', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: serviceList.map((serviceName) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle, size: 14, color: AppColors.primaryGold),
                                const SizedBox(width: 6),
                                Text(serviceName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          )).toList(),
                        ),
                        
                        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1)),
                        
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Amount', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text('₹${finalPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.green))]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  TextField(
                    controller: discountController, 
                    keyboardType: TextInputType.number, 
                    decoration: InputDecoration(labelText: 'Discount (%)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Icons.percent, color: Colors.grey)), 
                    onChanged: (val) => setState(() {}) 
                  ),
                  
                  const SizedBox(height: 24),
                  const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildPaymentTile('UPI', Icons.qr_code_scanner, selectedPaymentMethod == 'UPI', () => setState(() => selectedPaymentMethod = 'UPI'))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildPaymentTile('Card', Icons.credit_card, selectedPaymentMethod == 'Card', () => setState(() => selectedPaymentMethod = 'Card'))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildPaymentTile('Cash', Icons.payments_outlined, selectedPaymentMethod == 'Cash', () => setState(() => selectedPaymentMethod = 'Cash'))),
                    ],
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: isProcessing ? null : () async {
                        setState(() => isProcessing = true); 
                        
                        String? errorMessage = await provider.completeService(
                          visit.id, 
                          discountPercent: discountPercent,
                          paymentMethod: selectedPaymentMethod, 
                        );
                        
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage == null ? 'Payment received!' : 'Failed: $errorMessage'), backgroundColor: errorMessage == null ? Colors.green : Colors.red));
                        }
                      },
                      child: isProcessing 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.primaryGold, strokeWidth: 2))
                        : Text('COLLECT ₹${finalPrice.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPaymentTile(String title, IconData icon, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: isSelected ? Colors.green.withOpacity(0.1) : Colors.white, border: Border.all(color: isSelected ? Colors.green : Colors.grey.shade300, width: 2), borderRadius: BorderRadius.circular(12)),
        child: Column(children: [Icon(icon, color: isSelected ? Colors.green : Colors.grey, size: 24), const SizedBox(height: 4), Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isSelected ? Colors.green : Colors.grey))])
      ),
    );
  }
}
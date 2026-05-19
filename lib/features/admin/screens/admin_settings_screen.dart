import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/admin_provider.dart';
import '../../visitors/models/visitor_models.dart'; 
import '../../inventory/models/inventory_item.dart';
import '../../visitors/screens/staff_profile_screen.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  String _currentView = 'Services'; 
  String _searchQuery = '';
  int _currentPage = 1;
  final int _itemsPerPage = 8;
  Timer? _debounce; 

  @override
  void dispose() {
    _debounce?.cancel(); 
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final userRole = authProvider.userRole;
      final userBranchId = authProvider.currentUser?.branchId;
      
      final targetBranch = (userRole == 'ADMIN' || userRole == 'OWNER') ? 'all' : userBranchId;
      
      if (targetBranch != null) {
        context.read<AdminProvider>().fetchAdminData(targetBranch);
      }
    });
  }

  List<T> _getPaginatedData<T>(List<T> source) {
    int startIndex = (_currentPage - 1) * _itemsPerPage;
    if (startIndex >= source.length) return [];
    int endIndex = startIndex + _itemsPerPage;
    if (endIndex > source.length) endIndex = source.length;
    return source.sublist(startIndex, endIndex);
  }

  @override
  Widget build(BuildContext context) {
    final userRole = context.watch<AuthProvider>().userRole;
    if (userRole != 'ADMIN' && userRole != 'MANAGER' && userRole != 'OWNER') {
      return const Center(child: Text('Access Denied.', style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold)));
    }

    final provider = context.watch<AdminProvider>();
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1024;
    final isTablet = size.width >= 600 && size.width < 1024;
    final isMobile = size.width < 600;

    List<dynamic> currentDataList = [];
    
    // 🚀 PAGINATION AND FILTER DETERMINATION LOGIC
    if (_currentView == 'Services') {
      currentDataList = provider.services; 
    } 
    else if (_currentView == 'Customers') {
      currentDataList = provider.customersList; 
    }
    else if (_currentView == 'Staff Directory') {
      currentDataList = provider.branchStaff.where((s) {
        bool matchesSearch = s.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                             s.role.toLowerCase().contains(_searchQuery.toLowerCase());
        if (userRole == 'MANAGER' && (s.role == 'ADMIN' || s.role == 'OWNER')) {
          return false; 
        }
        return matchesSearch;
      }).toList();
    } 
    else if (_currentView == 'Product Catalog') {
      currentDataList = provider.masterProducts.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    } 
    else if (_currentView == 'Branches') {
      currentDataList = provider.branches.where((b) => b['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    // Determine totals based on server-side vs client-side tracking
    final totalPages = (_currentView == 'Customers')
        ? provider.customerTotalPages
        : (_currentView == 'Services')
            ? provider.serviceTotalPages
            : (currentDataList.length / _itemsPerPage).ceil();

    final totalItems = (_currentView == 'Customers')
        ? provider.customerTotalItems
        : (_currentView == 'Services')
            ? provider.serviceTotalItems
            : currentDataList.length;

    final paginatedData = (_currentView == 'Customers' || _currentView == 'Services')
        ? currentDataList 
        : _getPaginatedData(currentDataList);

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
                      Row(
                        children: [
                          const Icon(Icons.admin_panel_settings, color: AppColors.primaryGold, size: 32),
                          const SizedBox(width: 12),
                          Expanded(child: Text('System Management', style: TextStyle(fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.w800, color: AppColors.primaryBlack), overflow: TextOverflow.ellipsis)),
                        ],
                      ).animate().fade(duration: 500.ms).slideX(begin: -0.1),
                      const SizedBox(height: 8),
                      Text('Configure salon services, manage staff access, and control branch locations.', style: TextStyle(color: Colors.grey.shade600, fontSize: isMobile ? 14 : 16)).animate().fade(delay: 200.ms).slideX(begin: -0.1),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: IconButton(tooltip: 'Refresh Data', icon: const Icon(Icons.refresh, color: AppColors.primaryBlack), onPressed: () => provider.fetchAdminData(provider.currentBranchId ?? '')),
                ).animate().fade().scale(),
              ],
            ),
            
            SizedBox(height: isMobile ? 24 : 32),

            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))]),
              child: isMobile ? _buildMobileControls(provider) : _buildDesktopControls(provider, isDesktop),
            ).animate().fade(delay: 300.ms).slideY(begin: 0.05),
            
            const SizedBox(height: 24),

            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 2))]),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (provider.isLoading)
                        SizedBox(width: constraints.maxWidth, child: _buildShimmerTable())
                      else if (currentDataList.isEmpty)
                        _buildEmptyState('No records found.', 'Adjust your search or add new data.', Icons.folder_open)
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.grey.shade200),
                              child: DataTable(
                                columnSpacing: isDesktop ? 40 : 20, 
                                horizontalMargin: 24,
                                headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
                                headingTextStyle: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
                                dataRowMaxHeight: 70, dataRowMinHeight: 60,
                                columns: _getTableColumns(),
                                rows: paginatedData.map((item) => _buildTableRow(item, provider)).toList(),
                              ),
                            ),
                          ),
                        ),

                      if (!provider.isLoading && currentDataList.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (!isMobile)
                                Text('Showing ${(_currentPage - 1) * _itemsPerPage + 1} to ${(_currentPage * _itemsPerPage).clamp(0, totalItems)} of $totalItems entries', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
                              Row(
                                children: [
                                  OutlinedButton(
                                    onPressed: _currentPage > 1 ? () {
                                      setState(() => _currentPage--);
                                      if (_currentView == 'Customers') provider.fetchCustomers(search: _searchQuery, page: _currentPage);
                                      if (_currentView == 'Services') provider.fetchFilteredServices(search: _searchQuery, page: _currentPage);
                                    } : null, 
                                    style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), 
                                    child: const Text('Previous')
                                  ),
                                  const SizedBox(width: 8),
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: AppColors.primaryBlack, borderRadius: BorderRadius.circular(8)), child: Text('Page $_currentPage of ${totalPages == 0 ? 1 : totalPages}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: _currentPage < totalPages ? () {
                                      setState(() => _currentPage++);
                                      if (_currentView == 'Customers') provider.fetchCustomers(search: _searchQuery, page: _currentPage);
                                      if (_currentView == 'Services') provider.fetchFilteredServices(search: _searchQuery, page: _currentPage);
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
                  );
                }
              ),
            ).animate().fade(delay: 400.ms).slideY(begin: 0.05),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(6, (index) => Container(
        height: 60, 
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))), 
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(children: [Expanded(flex: 2, child: Container(height: 16, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)))), const SizedBox(width: 24), Expanded(flex: 1, child: Container(height: 16, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)))), const SizedBox(width: 24), Expanded(flex: 1, child: Container(height: 16, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)))), const SizedBox(width: 24), Expanded(flex: 1, child: Container(height: 16, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))))]),
      )).animate(onPlay: (controller) => controller.repeat()).shimmer(duration: 1200.ms, color: Colors.white60), 
    );
  }

  Widget _buildCustomTabBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['Services', 'Staff Directory', 'Product Catalog', 'Branches', 'Customers'].map((tab) {
          final isActive = _currentView == tab;
          return GestureDetector(
            onTap: () => setState(() { _currentView = tab; _currentPage = 1; _searchQuery = ''; }),
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

  Widget _buildDesktopControls(AdminProvider provider, bool isDesktop) {
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
            
            Container(
              width: isDesktop ? 300 : 200, height: 48, padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: TextField(
                decoration: const InputDecoration(icon: Icon(Icons.search, color: Colors.grey), hintText: 'Search records...', border: InputBorder.none),
                onChanged: (val) {
                  setState(() { _searchQuery = val; _currentPage = 1; });
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 500), () {
                    if (_currentView == 'Customers') {
                      provider.fetchCustomers(search: val, page: 1);
                    } else if (_currentView == 'Services') {
                      provider.fetchFilteredServices(search: val, page: 1);
                    } else if (_currentView == 'Staff Directory') {
                      provider.fetchFilteredStaff(search: val);
                    }
                  });
                }, 
              ),
            ),
            
            if (_currentView == 'Services')
              Container(height: 48, width: 48, decoration: BoxDecoration(color: AppColors.primaryBlack, borderRadius: BorderRadius.circular(12)), child: IconButton(tooltip: 'Filter Services', icon: const Icon(Icons.tune, color: AppColors.primaryGold), onPressed: () => _showServiceFilterDialog(context, provider))),
            if (_currentView == 'Staff Directory')
              Container(height: 48, width: 48, decoration: BoxDecoration(color: AppColors.primaryBlack, borderRadius: BorderRadius.circular(12)), child: IconButton(tooltip: 'Filter Staff', icon: const Icon(Icons.tune, color: AppColors.primaryGold), onPressed: () => _showStaffFilterDialog(context, provider))),
          ],
        ),
        
        if (_currentView != 'Customers')
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, foregroundColor: AppColors.primaryGold, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              if (_currentView == 'Services') _showAddServiceDialog(context, provider);
              if (_currentView == 'Staff Directory') _showAddStaffDialog(context, provider);
              if (_currentView == 'Product Catalog') _showAddProductDialog(context, provider);
              if (_currentView == 'Branches') _showAddBranchDialog(context, provider);
            },
            icon: const Icon(Icons.add_circle_outline),
            label: Text('NEW ${_currentView.split(' ').first.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
      ],
    );
  }

  Widget _buildMobileControls(AdminProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: _buildCustomTabBar()), 
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 54, padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                child: TextField(
                  decoration: const InputDecoration(icon: Icon(Icons.search, color: Colors.grey), hintText: 'Search records...', border: InputBorder.none),
                  onChanged: (val) {
                    setState(() { _searchQuery = val; _currentPage = 1; });
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(const Duration(milliseconds: 500), () {
                      if (_currentView == 'Customers') {
                        provider.fetchCustomers(search: val, page: 1);
                      } else if (_currentView == 'Services') {
                        provider.fetchFilteredServices(search: val, page: 1);
                      } else if (_currentView == 'Staff Directory') {
                        provider.fetchFilteredStaff(search: val);
                      }
                    });
                  }, 
                ),
              ),
            ),
            if (_currentView == 'Services') ...[
              const SizedBox(width: 8),
              Container(height: 54, width: 54, decoration: BoxDecoration(color: AppColors.primaryBlack, borderRadius: BorderRadius.circular(12)), child: IconButton(icon: const Icon(Icons.tune, color: AppColors.primaryGold), onPressed: () => _showServiceFilterDialog(context, provider))),
            ],
            if (_currentView == 'Staff Directory') ...[
              const SizedBox(width: 8),
              Container(height: 54, width: 54, decoration: BoxDecoration(color: AppColors.primaryBlack, borderRadius: BorderRadius.circular(12)), child: IconButton(icon: const Icon(Icons.tune, color: AppColors.primaryGold), onPressed: () => _showStaffFilterDialog(context, provider))),
            ]
          ],
        ),
        
        if (_currentView != 'Customers') ...[
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, foregroundColor: AppColors.primaryGold, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              if (_currentView == 'Services') _showAddServiceDialog(context, provider);
              if (_currentView == 'Staff Directory') _showAddStaffDialog(context, provider);
              if (_currentView == 'Product Catalog') _showAddProductDialog(context, provider);
              if (_currentView == 'Branches') _showAddBranchDialog(context, provider);
            },
            icon: const Icon(Icons.add_circle_outline),
            label: Text('NEW ${_currentView.split(' ').first.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ]
      ],
    );
  }

  List<DataColumn> _getTableColumns() {
    if (_currentView == 'Services') return const [DataColumn(label: Text('SERVICE NAME')), DataColumn(label: Text('GENDER / CAT')), DataColumn(label: Text('PRICE')), DataColumn(label: Text('STATUS')), DataColumn(label: Text('ACTIONS'))];
    if (_currentView == 'Staff Directory') return const [DataColumn(label: Text('STAFF NAME')), DataColumn(label: Text('ASSIGNED BRANCH')), DataColumn(label: Text('SYSTEM ROLE')), DataColumn(label: Text('WORK STATUS')), DataColumn(label: Text('LOGIN ACCESS')), DataColumn(label: Text('ACTIONS'))];
    if (_currentView == 'Product Catalog') return const [DataColumn(label: Text('PRODUCT NAME')), DataColumn(label: Text('CATEGORY')), DataColumn(label: Text('PRICE')), DataColumn(label: Text('ACTIONS'))];
    if (_currentView == 'Branches') return const [DataColumn(label: Text('BRANCH NAME')), DataColumn(label: Text('CITY')), DataColumn(label: Text('COORDINATES')), DataColumn(label: Text('ACTIONS'))];
    
    return const [
      DataColumn(label: Text('CUSTOMER INFO')), 
      DataColumn(label: Text('TOTAL VISITS')), 
      DataColumn(label: Text('LIFETIME SPENT')), 
      DataColumn(label: Text('LAST VISIT')),
      DataColumn(label: Text('ACTIONS')) 
    ];
  }

  DataRow _buildTableRow(dynamic item, AdminProvider provider) {
    if (_currentView == 'Services') {
      final s = item as ServiceModel;
      return DataRow(cells: [
        DataCell(Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
        DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)), child: Text('${s.genderCategory} / ${s.category}'.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey.shade700)))),
        DataCell(Text('₹${s.price}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
        DataCell(Switch(value: s.isActive, activeColor: AppColors.primaryGold, activeTrackColor: AppColors.primaryBlack, onChanged: (val) async {
          bool success = await provider.toggleService(s.id);
          if (context.mounted) _showFeedback(context, success, success ? 'Status updated!' : 'Failed to update.');
        })),
        DataCell(IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue), onPressed: () => _showEditServiceDialog(context, s, provider))),
      ]);
    } else if (_currentView == 'Staff Directory') {
      final s = item as StaffModel;
      String branchName = 'Unknown Branch';
      if (s.branchId != null) {
        final branchMatch = provider.branches.where((b) => b['_id'] == s.branchId).toList();
        if (branchMatch.isNotEmpty) branchName = branchMatch.first['name'];
      }

      return DataRow(cells: [
        DataCell(Row(children: [CircleAvatar(radius: 16, backgroundColor: AppColors.primaryGold.withOpacity(0.2), child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primaryBlack, fontWeight: FontWeight.bold))), const SizedBox(width: 12), Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold))])),
        DataCell(Text(branchName, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600))), 
        DataCell(Text(s.role.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(s.isBusy ? _buildBadge('Busy', Colors.red) : _buildBadge('Available', Colors.green)),
        DataCell(Switch(
          value: s.isActive, 
          activeColor: AppColors.primaryGold, 
          activeTrackColor: AppColors.primaryBlack, 
          onChanged: (val) async {
            bool success = await provider.toggleStaff(s.id);
            if (context.mounted) _showFeedback(context, success, success ? 'Login access updated!' : 'Failed to update access.');
          }
        )),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Manage Payroll & Loans',
              icon: const Icon(Icons.account_balance_wallet, color: Colors.purple),
              onPressed: () => _showStaffFinancialDashboard(context, s), 
            ),
            OutlinedButton.icon(icon: const Icon(Icons.analytics, size: 16), label: const Text('Profile & Logs'), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => StaffProfileScreen(staff: s)))),
            const SizedBox(width: 8),
            IconButton(tooltip: 'Transfer/Edit Staff', icon: const Icon(Icons.edit_location_alt, color: Colors.blue), onPressed: () => _showTransferStaffDialog(context, s, provider)),
          ],
        )),
      ]);
    } else if (_currentView == 'Product Catalog') {
      final p = item as ProductModel;
      return DataRow(cells: [
        DataCell(Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(p.category.toUpperCase().replaceAll('_', ' '), style: TextStyle(color: Colors.grey.shade600))),
        DataCell(const Text('Standard Price', style: TextStyle(color: Colors.grey))),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primaryBlack, side: BorderSide(color: Colors.grey.shade300), elevation: 0),
              icon: const Icon(Icons.storefront, size: 16), label: const Text('View Branch Stock'),
              onPressed: () => _showProductStockDialog(context, p, provider), 
            ),
            IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue), onPressed: () => _showEditProductDialog(context, p, provider)),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent), 
              onPressed: () async {
                String? err = await provider.removeMasterProduct(p.id);
                if (context.mounted) _showFeedback(context, err == null, err ?? 'Product Deleted Successfully!');
              }
            ),
          ],
        )),
      ]);
    } else if (_currentView == 'Branches') { 
      final b = item; 
      return DataRow(cells: [
        DataCell(Text(b['name'], style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(b['city'] ?? 'N/A')),
        DataCell(Text('${b['latitude']}, ${b['longitude']}', style: const TextStyle(color: Colors.blue, fontSize: 12))),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue), onPressed: () => _showEditBranchDialog(context, b, provider)),
            IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () async {
              String? errorMessage = await provider.deleteBranch(b['_id']);
              if (context.mounted) _showFeedback(context, errorMessage == null, errorMessage ?? 'Branch Deleted Successfully!');
            }),
          ],
        )),
      ]);
    } else { 
      final c = item; 
      
      String lastVisit = 'Never';
      if (c['lastVisitDate'] != null) {
        lastVisit = DateFormat('dd MMM yyyy').format(DateTime.parse(c['lastVisitDate']).toLocal());
      }

      return DataRow(cells: [
        DataCell(Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(c['phone'] ?? 'No Phone', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        )),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)), 
            child: Text('${c['totalVisits'] ?? 0} Visits', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))
          )
        ),
        DataCell(Text('₹${(c['totalSpent'] ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green))),
        DataCell(Text(lastVisit, style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlack, 
              foregroundColor: AppColors.primaryGold,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
            ),
            icon: const Icon(Icons.receipt_long, size: 16),
            label: const Text('View History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            onPressed: () => _showCustomerHistoryDialog(context, c), 
          )
        ),
      ]);
    }
  }

  void _showCustomerHistoryDialog(BuildContext context, dynamic customer) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final dialogWidth = isMobile ? size.width * 0.95 : 600.0;
    
    List<dynamic> history = customer['history'] ?? [];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Container(
          width: dialogWidth,
          height: size.height * 0.8, 
          padding: EdgeInsets.all(isMobile ? 20 : 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.primaryGold.withOpacity(0.15), shape: BoxShape.circle),
                          child: const Icon(Icons.person, color: AppColors.primaryGold, size: 28)
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(customer['name'] ?? 'Customer', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                              Text('${customer['phone'] ?? 'No Phone'} • Total Spent: ₹${(customer['totalSpent'] ?? 0).toStringAsFixed(0)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),

              const Text('Visit Timeline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
              const SizedBox(height: 16),

              Expanded(
                child: history.isEmpty 
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('No completed visits yet.', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold))
                        ],
                      )
                    )
                  : ListView.builder(
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final visit = history[index];
                        final dateStr = visit['date'] != null 
                            ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(visit['date']).toLocal()) 
                            : 'Unknown Date';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200)
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(dateStr, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                    child: Text('₹${visit['price']?.toStringAsFixed(0) ?? 0}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13))
                                  )
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.content_cut, size: 16, color: AppColors.primaryGold),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      visit['serviceCombo'] == null || visit['serviceCombo'].isEmpty 
                                          ? 'No Services Logged' 
                                          : visit['serviceCombo'], 
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.badge_outlined, size: 14, color: Colors.grey.shade500),
                                      const SizedBox(width: 6),
                                      Text('Served by: ${visit['staffName'] ?? 'Unknown'}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Icon(Icons.account_balance_wallet_outlined, size: 14, color: Colors.grey.shade500),
                                      const SizedBox(width: 6),
                                      Text('${visit['paymentMethod'] ?? 'UPI'}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              )
                            ],
                          ),
                        );
                      }
                    ),
              )
            ],
          ),
        ),
      ),
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
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))), child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)));
  }

  void _showFeedback(BuildContext context, bool success, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: success ? Colors.green.shade700 : Colors.redAccent.shade700, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  void _showServiceFilterDialog(BuildContext context, AdminProvider provider) {
    final nameController = TextEditingController();
    String gender = 'All';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: 400, padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.tune, color: AppColors.primaryGold), SizedBox(width: 12), Text('Filter Services', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))]),
                const SizedBox(height: 32),
                TextField(controller: nameController, decoration: InputDecoration(labelText: 'Search Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(decoration: InputDecoration(labelText: 'Gender', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), value: gender, items: ['All', 'Male', 'Female', 'Unisex'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(), onChanged: (val) => setState(() => gender = val!)),
                const SizedBox(height: 40),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () {
                      Navigator.pop(context);
                      provider.fetchAdminData(provider.currentBranchId!); 
                    }, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('RESET', style: TextStyle(color: Colors.black)))),
                    const SizedBox(width: 16),
                    Expanded(child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () {
                        Navigator.pop(context);
                        provider.fetchFilteredServices(search: nameController.text, page: 1);
                      },
                      child: const Text('APPLY', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold))
                    )),
                  ],
                )
              ],
            ),
          ),
        );
      }),
    );
  }

  void _showStaffFilterDialog(BuildContext context, AdminProvider provider) {
    final searchController = TextEditingController();
    String role = 'All';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: 400, padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.tune, color: AppColors.primaryGold), SizedBox(width: 12), Text('Filter Staff', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))]),
                const SizedBox(height: 32),
                TextField(controller: searchController, decoration: InputDecoration(labelText: 'Search Name/Email', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(decoration: InputDecoration(labelText: 'Role', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), value: role, items: ['All', 'STAFF', 'MANAGER', 'ADMIN'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(), onChanged: (val) => setState(() => role = val!)),
                const SizedBox(height: 40),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () {
                      Navigator.pop(context);
                      provider.fetchAdminData(provider.currentBranchId!); 
                    }, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('RESET', style: TextStyle(color: Colors.black)))),
                    const SizedBox(width: 16),
                    Expanded(child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () {
                        Navigator.pop(context);
                        provider.fetchFilteredStaff(search: searchController.text, role: role == 'All' ? null : role);
                      },
                      child: const Text('APPLY', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold))
                    )),
                  ],
                )
              ],
            ),
          ),
        );
      }),
    );
  }

  void _showAddBranchDialog(BuildContext context, AdminProvider provider) {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final mapsLinkCtrl = TextEditingController(); 
    final dialogWidth = MediaQuery.of(context).size.width > 600 ? 450.0 : MediaQuery.of(context).size.width * 0.9;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: dialogWidth, padding: const EdgeInsets.all(32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.add_location_alt, color: AppColors.primaryGold), SizedBox(width: 12), Text('New Branch', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))]),
                const SizedBox(height: 24),
                TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Branch Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 16),
                TextField(controller: cityCtrl, decoration: InputDecoration(labelText: 'City', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 16),
                TextField(controller: addrCtrl, decoration: InputDecoration(labelText: 'Full Address', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 16),
                TextField(controller: mapsLinkCtrl, decoration: InputDecoration(labelText: 'Google Maps Link (URL)', hintText: 'Paste the Google Maps URL here...', helperText: 'We auto-extract the GPS coordinates.', prefixIcon: const Icon(Icons.map, color: Colors.blue), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () async {
                      String url = mapsLinkCtrl.text.trim();
                      double lat = 0.0; double lng = 0.0;
                      RegExp regExpAt = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)');
                      RegExp regExpQuery = RegExp(r'[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)');
                      RegExp regExpPlace = RegExp(r'place\/.*?\/(-?\d+\.\d+),(-?\d+\.\d+)');
            
                      var matchAt = regExpAt.firstMatch(url);
                      var matchQuery = regExpQuery.firstMatch(url);
                      var matchPlace = regExpPlace.firstMatch(url);
            
                      if (matchAt != null) { lat = double.parse(matchAt.group(1)!); lng = double.parse(matchAt.group(2)!);
                      } else if (matchQuery != null) { lat = double.parse(matchQuery.group(1)!); lng = double.parse(matchQuery.group(2)!);
                      } else if (matchPlace != null) { lat = double.parse(matchPlace.group(1)!); lng = double.parse(matchPlace.group(2)!);
                      } else if (url.contains(',') && !url.contains('http')) {
                        var parts = url.split(',');
                        if(parts.length == 2) { lat = double.tryParse(parts[0].trim()) ?? 0.0; lng = double.tryParse(parts[1].trim()) ?? 0.0; }
                      }
            
                      if (lat == 0.0 || lng == 0.0) {
                        _showFeedback(context, false, "Could not extract coordinates. Use a full maps URL.");
                        return;
                      }
            
                      String? err = await provider.addBranch(nameCtrl.text, addrCtrl.text, cityCtrl.text, lat, lng);
                      if (context.mounted) {
                        if (err == null) { Navigator.pop(context); _showFeedback(context, true, "Branch Created! Coordinates: $lat, $lng");
                        } else { _showFeedback(context, false, err); }
                      }
                    },
                    child: const Text('CREATE BRANCH', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditBranchDialog(BuildContext context, dynamic branch, AdminProvider provider) {
    final nameCtrl = TextEditingController(text: branch['name']);
    final addrCtrl = TextEditingController(text: branch['address']);
    final cityCtrl = TextEditingController(text: branch['city']);
    final mapsLinkCtrl = TextEditingController(); 
    
    double currentLat = (branch['latitude'] ?? 0).toDouble();
    double currentLng = (branch['longitude'] ?? 0).toDouble();

    final dialogWidth = MediaQuery.of(context).size.width > 600 ? 450.0 : MediaQuery.of(context).size.width * 0.9;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: dialogWidth, padding: const EdgeInsets.all(32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 12), Text('Edit Branch', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))]),
                const SizedBox(height: 24),
                TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Branch Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 16),
                TextField(controller: cityCtrl, decoration: InputDecoration(labelText: 'City', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 16),
                TextField(controller: addrCtrl, decoration: InputDecoration(labelText: 'Full Address', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 16),
                
                TextField(
                  controller: mapsLinkCtrl, 
                  decoration: InputDecoration(
                    labelText: 'Google Maps Link (Optional)', 
                    hintText: 'Leave blank to keep existing location', 
                    helperText: 'Current GPS: $currentLat, $currentLng', 
                    prefixIcon: const Icon(Icons.map, color: Colors.blue), 
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                  )
                ),
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () async {
                      if (nameCtrl.text.isNotEmpty && cityCtrl.text.isNotEmpty) {
                        
                        double lat = currentLat; 
                        double lng = currentLng;
                        String url = mapsLinkCtrl.text.trim();
                        
                        if (url.isNotEmpty) {
                          RegExp regExpAt = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)');
                          RegExp regExpQuery = RegExp(r'[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)');
                          RegExp regExpPlace = RegExp(r'place\/.*?\/(-?\d+\.\d+),(-?\d+\.\d+)');
                
                          var matchAt = regExpAt.firstMatch(url);
                          var matchQuery = regExpQuery.firstMatch(url);
                          var matchPlace = regExpPlace.firstMatch(url);
                
                          if (matchAt != null) { lat = double.parse(matchAt.group(1)!); lng = double.parse(matchAt.group(2)!);
                          } else if (matchQuery != null) { lat = double.parse(matchQuery.group(1)!); lng = double.parse(matchQuery.group(2)!);
                          } else if (matchPlace != null) { lat = double.parse(matchPlace.group(1)!); lng = double.parse(matchPlace.group(2)!);
                          } else if (url.contains(',') && !url.contains('http')) {
                            var parts = url.split(',');
                            if(parts.length == 2) { lat = double.tryParse(parts[0].trim()) ?? currentLat; lng = double.tryParse(parts[1].trim()) ?? currentLng; }
                          }
                        }

                        String? err = await provider.editBranch(branch['_id'], nameCtrl.text, addrCtrl.text, cityCtrl.text, lat, lng);
                        if (context.mounted) {
                          Navigator.pop(context);
                          _showFeedback(context, err == null, err ?? "Branch Updated Successfully!");
                        }
                      }
                    },
                    child: const Text('UPDATE BRANCH', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddProductDialog(BuildContext context, AdminProvider provider) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final thresholdController = TextEditingController(text: '10');
    
    String? selectedBrand;
    String? selectedCategory;
    bool isProcessing = false; 
    final dialogWidth = MediaQuery.of(context).size.width > 600 ? 500.0 : MediaQuery.of(context).size.width * 0.9;

    List<String> brandNames = provider.brandsCatalog.map((b) => b['name'].toString()).toList();
    List<String> categoryNames = provider.categoriesCatalog.map((c) => c['name'].toString()).toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: dialogWidth, padding: const EdgeInsets.all(32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Icon(Icons.inventory_2, color: AppColors.primaryGold, size: 28), SizedBox(width: 12), Text('New Product', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 8),
                  Text('Add an item to the global catalog.', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  const SizedBox(height: 32),
                  
                  TextField(controller: nameController, decoration: InputDecoration(labelText: 'Product Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  const SizedBox(height: 16),
                  
                  if (dialogWidth < 400) ...[
                    _buildSearchableDropdown(label: 'Brand', hint: 'Select or type brand...', options: brandNames, onSelected: (val) => selectedBrand = val),
                    const SizedBox(height: 16),
                    _buildSearchableDropdown(label: 'Category', hint: 'Select or type category...', options: categoryNames, onSelected: (val) => selectedCategory = val),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(child: _buildSearchableDropdown(label: 'Brand', hint: 'Select or type brand...', options: brandNames, onSelected: (val) => selectedBrand = val)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildSearchableDropdown(label: 'Category', hint: 'Select or type category...', options: categoryNames, onSelected: (val) => selectedCategory = val)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(child: TextField(controller: priceController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Price (₹)', prefixIcon: const Icon(Icons.currency_rupee, size: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                      const SizedBox(width: 16),
                      Expanded(child: TextField(controller: thresholdController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Alert At (Qty)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                    ],
                  ),
                  const SizedBox(height: 40),
                 
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: isProcessing ? null : () async {
                        final name = nameController.text.trim();
                        final price = double.tryParse(priceController.text) ?? 0.0;
                        final threshold = int.tryParse(thresholdController.text) ?? 10;
                        
                        if (selectedBrand == null || selectedBrand!.isEmpty) selectedBrand = brandNames.isNotEmpty ? brandNames.first : 'Other';
                        if (selectedCategory == null || selectedCategory!.isEmpty) selectedCategory = categoryNames.isNotEmpty ? categoryNames.first : 'Other';

                        if (name.isNotEmpty && price > 0) {
                          setState(() => isProcessing = true);
                          final errorMessage = await provider.addMasterProduct(name, selectedBrand!, selectedCategory!, price, threshold);
                          if (context.mounted) {
                            Navigator.pop(context);
                            if (errorMessage == null) {
                               _showFeedback(context, true, "Product added to catalog!");
                            } else {
                               _showFeedback(context, false, errorMessage);
                            }
                          }
                        } else {
                          _showFeedback(context, false, "Please enter all details.");
                        }
                      },
                      child: isProcessing ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.primaryGold, strokeWidth: 2)) : const Text('CREATE PRODUCT', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, letterSpacing: 2))
                    )
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  void _showEditProductDialog(BuildContext context, ProductModel product, AdminProvider provider) {
    final nameController = TextEditingController(text: product.name);
    final priceController = TextEditingController(); 
    
    String? selectedBrand = product.brand;
    String? selectedCategory = product.category;
    bool isProcessing = false; 
    final dialogWidth = MediaQuery.of(context).size.width > 600 ? 500.0 : MediaQuery.of(context).size.width * 0.9;

    List<String> brandNames = provider.brandsCatalog.map((b) => b['name'].toString()).toList();
    List<String> categoryNames = provider.categoriesCatalog.map((c) => c['name'].toString()).toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: dialogWidth, padding: const EdgeInsets.all(32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Icon(Icons.edit, color: Colors.blue, size: 28), SizedBox(width: 12), Text('Edit Product', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 32),
                  
                  TextField(controller: nameController, decoration: InputDecoration(labelText: 'Product Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  const SizedBox(height: 16),
                  
                  if (dialogWidth < 400) ...[
                    _buildSearchableDropdown(label: 'Brand', hint: 'Select or type brand...', initialValue: selectedBrand, options: brandNames, onSelected: (val) => selectedBrand = val),
                    const SizedBox(height: 16),
                    _buildSearchableDropdown(label: 'Category', hint: 'Select or type category...', initialValue: selectedCategory, options: categoryNames, onSelected: (val) => selectedCategory = val),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(child: _buildSearchableDropdown(label: 'Brand', hint: 'Select or type brand...', initialValue: selectedBrand, options: brandNames, onSelected: (val) => selectedBrand = val)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildSearchableDropdown(label: 'Category', hint: 'Select or type category...', initialValue: selectedCategory, options: categoryNames, onSelected: (val) => selectedCategory = val)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  
                  TextField(controller: priceController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'New Base Price (₹)', hintText: 'Optional', prefixIcon: const Icon(Icons.currency_rupee, size: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  const SizedBox(height: 40),
                 
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: isProcessing ? null : () async {
                        final name = nameController.text.trim();
                        final price = double.tryParse(priceController.text) ?? 0.0;
                        
                        if (name.isNotEmpty) {
                          setState(() => isProcessing = true);
                          final errorMessage = await provider.editMasterProduct(product.id, name, selectedBrand!, selectedCategory!, price);
                          if (context.mounted) {
                            Navigator.pop(context);
                            if (errorMessage == null) {
                               _showFeedback(context, true, "Product Updated!");
                            } else {
                               _showFeedback(context, false, errorMessage);
                            }
                          }
                        }
                      },
                      child: isProcessing ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.primaryGold, strokeWidth: 2)) : const Text('UPDATE PRODUCT', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, letterSpacing: 2))
                    )
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  void _showProductStockDialog(BuildContext context, ProductModel product, AdminProvider provider) {
    final dialogWidth = MediaQuery.of(context).size.width > 600 ? 500.0 : MediaQuery.of(context).size.width * 0.9;
    String searchFilter = ''; 

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: dialogWidth, padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Inventory Distribution', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                ]),
                Text(product.name, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    hintText: 'Search branch...',
                    filled: true, fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                  ),
                  onChanged: (val) => setState(() => searchFilter = val.toLowerCase()),
                ),
                const SizedBox(height: 16),

                Container(
                  constraints: const BoxConstraints(minHeight: 150, maxHeight: 350),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                  child: FutureBuilder<List<dynamic>>(
                    future: provider.getProductDistribution(product.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primaryGold));
                      if (snapshot.hasError) return const Center(child: Text("Error loading inventory", style: TextStyle(color: Colors.red)));
                      
                      List<dynamic> data = snapshot.data ?? [];
                      if (searchFilter.isNotEmpty) {
                        data = data.where((item) => (item['branchName'] ?? '').toLowerCase().contains(searchFilter)).toList();
                      }

                      if (data.isEmpty) return const Center(child: Text("No stock found.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)));

                      return ListView.separated(
                        shrinkWrap: true, itemCount: data.length, separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final branchStock = data[index];
                          final branchName = branchStock['branchName'] ?? 'Unknown';
                          final stockLvl = branchStock['currentStock'] ?? 0;
                          Color badgeColor = stockLvl == 0 ? Colors.redAccent : (stockLvl < 10 ? Colors.orange : Colors.green);

                          return ListTile(
                            leading: const Icon(Icons.store, color: AppColors.primaryGold), 
                            title: Text(branchName, style: const TextStyle(fontWeight: FontWeight.bold)), 
                            trailing: _buildBadge('$stockLvl Units', badgeColor),
                          );
                        },
                      );
                    },
                  ),
                )
              ],
            ),
          ),
        );
      }),
    );
  }

  void _showAddServiceDialog(BuildContext context, AdminProvider provider) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    String gender = 'Unisex';
    
    List<String> categoryNames = provider.categoriesCatalog.map((c) => c['name'].toString()).toList();
    if (categoryNames.isEmpty) categoryNames = ['haircut', 'spa', 'other']; 
    String category = categoryNames.first;

    final dialogWidth = MediaQuery.of(context).size.width > 600 ? 450.0 : MediaQuery.of(context).size.width * 0.9;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: dialogWidth, padding: const EdgeInsets.all(32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Icon(Icons.content_cut, color: AppColors.primaryGold, size: 28), SizedBox(width: 12), Text('Create Service', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 32),
                  TextField(controller: nameController, decoration: InputDecoration(labelText: 'Service Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  const SizedBox(height: 16),
                  
                  if (dialogWidth < 400) ...[
                    DropdownButtonFormField<String>(decoration: InputDecoration(labelText: 'Target Gender', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), value: gender, items: ['Male', 'Female', 'Unisex'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(), onChanged: (val) => setState(() => gender = val!)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(decoration: InputDecoration(labelText: 'Category', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), value: category, items: categoryNames.map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase()))).toList(), onChanged: (val) => setState(() => category = val!)),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(child: DropdownButtonFormField<String>(decoration: InputDecoration(labelText: 'Target Gender', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), value: gender, items: ['Male', 'Female', 'Unisex'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(), onChanged: (val) => setState(() => gender = val!))),
                        const SizedBox(width: 16),
                        Expanded(child: DropdownButtonFormField<String>(decoration: InputDecoration(labelText: 'Category', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), value: category, items: categoryNames.map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase()))).toList(), onChanged: (val) => setState(() => category = val!))),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(controller: priceController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Price (₹)', prefixIcon: const Icon(Icons.currency_rupee, size: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () async {
                        if (nameController.text.isNotEmpty && priceController.text.isNotEmpty) {
                          Navigator.pop(context);
                          bool success = await provider.addService(nameController.text, category, gender, double.tryParse(priceController.text) ?? 0);
                          _showFeedback(context, success, success ? 'Service Created!' : 'Failed to create service.');
                        }
                      },
                      child: const Text('SAVE SERVICE', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      })
    );
  }

  void _showEditServiceDialog(BuildContext context, ServiceModel service, AdminProvider provider) {
    final nameController = TextEditingController(text: service.name);
    final priceController = TextEditingController(text: service.price.toStringAsFixed(0));
    String gender = ['Male', 'Female', 'Unisex'].contains(service.genderCategory) ? service.genderCategory : 'Unisex';
    
    List<String> categoryNames = provider.categoriesCatalog.map((c) => c['name'].toString()).toList();
    if (categoryNames.isEmpty) categoryNames = ['haircut', 'spa', 'other'];
    String category = categoryNames.contains(service.category) ? service.category : categoryNames.first;
    
    final dialogWidth = MediaQuery.of(context).size.width > 600 ? 450.0 : MediaQuery.of(context).size.width * 0.9;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: dialogWidth, padding: const EdgeInsets.all(32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Icon(Icons.edit, color: Colors.blue, size: 28), SizedBox(width: 12), Text('Edit Service', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 32),
                  TextField(controller: nameController, decoration: InputDecoration(labelText: 'Service Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  const SizedBox(height: 16),
                  
                  if (dialogWidth < 400) ...[
                    DropdownButtonFormField<String>(decoration: InputDecoration(labelText: 'Target Gender', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), value: gender, items: ['Male', 'Female', 'Unisex'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(), onChanged: (val) => setState(() => gender = val!)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(decoration: InputDecoration(labelText: 'Category', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), value: category, items: categoryNames.map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase()))).toList(), onChanged: (val) => setState(() => category = val!)),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(child: DropdownButtonFormField<String>(decoration: InputDecoration(labelText: 'Target Gender', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), value: gender, items: ['Male', 'Female', 'Unisex'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(), onChanged: (val) => setState(() => gender = val!))),
                        const SizedBox(width: 16),
                        Expanded(child: DropdownButtonFormField<String>(decoration: InputDecoration(labelText: 'Category', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), value: category, items: categoryNames.map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase()))).toList(), onChanged: (val) => setState(() => category = val!))),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),
                  TextField(controller: priceController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Price (₹)', prefixIcon: const Icon(Icons.currency_rupee, size: 18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () async {
                        if (nameController.text.isNotEmpty && priceController.text.isNotEmpty) {
                          Navigator.pop(context); 
                          bool success = await provider.updateService(service.id, nameController.text, category, gender, double.tryParse(priceController.text) ?? 0);
                          _showFeedback(context, success, success ? 'Service Updated!' : 'Failed to update service.');
                        }
                      },
                      child: const Text('UPDATE SERVICE', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      })
    );
  }

  void _showAddStaffDialog(BuildContext context, AdminProvider provider) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final passwordController = TextEditingController();
    final salaryController = TextEditingController();
    final loanController = TextEditingController();

    String selectedRole = 'STAFF';
    String? selectedBranch = provider.branches.isNotEmpty ? provider.branches.first['_id'] : null;

    List<String> assignedScreens = ['Inventory', 'Visitors'];

    bool isProcessing = false;
    
    String? inlineErrorMessage;
    String? inlineSuccessMessage;

    void updateRolePermissions(String role) {
      if (role == 'ADMIN') {
        assignedScreens = ['Inventory', 'Visitors', 'System Management', 'Revenue'];
      } else if (role == 'MANAGER') {
        assignedScreens = ['Inventory', 'Visitors', 'System Management'];
      } else {
        assignedScreens = ['Inventory', 'Visitors'];
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        
        final size = MediaQuery.of(context).size;
        final isMobile = size.width < 600;
        final isDesktop = size.width >= 600;
        final dialogWidth = isMobile ? size.width * 0.95 : (size.width > 700 ? 700.0 : size.width * 0.9);

        return Dialog(
          insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 40, vertical: isMobile ? 24 : 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isMobile ? 16 : 24)),
          backgroundColor: Colors.white,
          child: Container(
            width: dialogWidth,
            padding: EdgeInsets.all(isMobile ? 20 : 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppColors.primaryGold.withOpacity(0.15), shape: BoxShape.circle),
                            child: Icon(Icons.person_add_alt_1, color: AppColors.primaryGold, size: isMobile ? 24 : 28),
                          ),
                          SizedBox(width: isMobile ? 12 : 16),
                          Text('Register Employee', style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
                        ]
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey), 
                        padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                        onPressed: () => Navigator.pop(context)
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Add a new staff member and configure their access permissions.', style: TextStyle(color: Colors.grey.shade500, fontSize: isMobile ? 13 : 14)),
                  SizedBox(height: isMobile ? 24 : 32),

                  if (inlineErrorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 24), padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(inlineErrorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold))),
                      ]),
                    ).animate().fade().slideY(begin: -0.1),

                  if (inlineSuccessMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 24), padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
                      child: Row(children: [
                        const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(inlineSuccessMessage!, style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold))),
                      ]),
                    ).animate().fade().slideY(begin: -0.1),

                  const Text('Personal Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
                  const SizedBox(height: 12),
                  if (isDesktop) ...[
                    Row(children: [
                      Expanded(child: TextField(controller: nameController, decoration: InputDecoration(labelText: 'Full Name', prefixIcon: const Icon(Icons.person_outline), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200))))),
                      const SizedBox(width: 16),
                      Expanded(child: TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Phone Number', prefixIcon: const Icon(Icons.phone), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200))))),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Email Address', prefixIcon: const Icon(Icons.email_outlined), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200))))),
                      const SizedBox(width: 16),
                      Expanded(child: TextField(controller: addressController, decoration: InputDecoration(labelText: 'Home Address', prefixIcon: const Icon(Icons.home_outlined), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200))))),
                    ]),
                  ] else ...[
                     TextField(controller: nameController, decoration: InputDecoration(labelText: 'Full Name', prefixIcon: const Icon(Icons.person_outline), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)))),
                     const SizedBox(height: 12),
                     TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Phone Number', prefixIcon: const Icon(Icons.phone), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)))),
                     const SizedBox(height: 12),
                     TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Email Address', prefixIcon: const Icon(Icons.email_outlined), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)))),
                     const SizedBox(height: 12),
                     TextField(controller: addressController, decoration: InputDecoration(labelText: 'Home Address', prefixIcon: const Icon(Icons.home_outlined), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)))),
                  ],

                  SizedBox(height: isMobile ? 24 : 32),

                  const Text('Employment & Security', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
                  const SizedBox(height: 12),
                  if (isDesktop) ...[
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(labelText: 'Assign Branch', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200))),
                            value: selectedBranch,
                            items: provider.branches.map((b) => DropdownMenuItem<String>(value: b['_id'], child: Text(b['name'], overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (val) => setState(() => selectedBranch = val),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(labelText: 'System Role', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200))),
                            value: selectedRole,
                            items: ['STAFF', 'MANAGER', 'ADMIN'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                            onChanged: (val) {
                              setState(() {
                                selectedRole = val!;
                                updateRolePermissions(selectedRole); 
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: TextField(controller: salaryController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Monthly Salary (₹)', prefixIcon: const Icon(Icons.currency_rupee), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200))))),
                      const SizedBox(width: 16),
                      Expanded(child: TextField(controller: loanController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Initial Loan/Advance (₹)', prefixIcon: const Icon(Icons.account_balance_wallet), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200))))),
                    ]),
                  ] else ...[
                     DropdownButtonFormField<String>(
                        decoration: InputDecoration(labelText: 'Assign Branch', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200))),
                        value: selectedBranch,
                        items: provider.branches.map((b) => DropdownMenuItem<String>(value: b['_id'], child: Text(b['name'], overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) => setState(() => selectedBranch = val),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(labelText: 'System Role', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200))),
                        value: selectedRole,
                        items: ['STAFF', 'MANAGER', 'ADMIN'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedRole = val!;
                            updateRolePermissions(selectedRole); 
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(controller: salaryController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Monthly Salary (₹)', prefixIcon: const Icon(Icons.currency_rupee), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)))),
                      const SizedBox(height: 12),
                      TextField(controller: loanController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Initial Loan/Advance (₹)', prefixIcon: const Icon(Icons.account_balance_wallet), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)))),
                  ],
                  SizedBox(height: isMobile ? 12 : 16),
                  TextField(controller: passwordController, obscureText: true, decoration: InputDecoration(labelText: 'Temporary Password', prefixIcon: const Icon(Icons.lock_outline), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)))),

                  SizedBox(height: isMobile ? 24 : 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Screen Access', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
                      const Text('Read-Only (Auto Assigned)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                    child: Wrap(
                      spacing: 12, runSpacing: 12,
                      children: assignedScreens.map((screenName) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primaryGold)
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle, color: AppColors.primaryGold, size: 16),
                              const SizedBox(width: 8),
                              Text(screenName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: isMobile ? 24 : 40),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlack, 
                        padding: EdgeInsets.symmetric(vertical: isMobile ? 16 : 20), 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), 
                        elevation: 10, shadowColor: AppColors.primaryBlack.withOpacity(0.3)
                      ),
                      onPressed: (isProcessing || inlineSuccessMessage != null) ? null : () async {
                        
                        setState(() {
                          inlineErrorMessage = null;
                          inlineSuccessMessage = null;
                        });

                        if (nameController.text.isEmpty || emailController.text.isEmpty || addressController.text.isEmpty || passwordController.text.isEmpty || selectedBranch == null) {
                          setState(() => inlineErrorMessage = 'Please fill all required fields.');
                          return;
                        }

                        setState(() => isProcessing = true);
                        
                        double salary = double.tryParse(salaryController.text) ?? 0;
                        double loanAmount = double.tryParse(loanController.text) ?? 0;
                        
                        String? errorMessage = await provider.addStaff(nameController.text, selectedRole, emailController.text, phoneController.text, addressController.text, passwordController.text, selectedBranch!, assignedScreens, salary, loanAmount);
                        
                        if (context.mounted) {
                          if (errorMessage == null) {
                            setState(() {
                              isProcessing = false;
                              inlineSuccessMessage = 'Staff Registered! Login details sent to email.';
                            });
                            
                            Future.delayed(const Duration(seconds: 2), () {
                              if (context.mounted && Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                            });
                          } else {
                            setState(() {
                              isProcessing = false;
                              inlineErrorMessage = errorMessage;
                            });
                          }
                        }
                      },
                      child: isProcessing 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.primaryGold, strokeWidth: 2))
                        : const Text('REGISTER EMPLOYEE', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      })
    );
  }

  void _showTransferStaffDialog(BuildContext context, StaffModel staff, AdminProvider provider) {
    String selectedRole = staff.role;
    String? selectedBranch = provider.branches.isNotEmpty ? provider.branches.first['_id'] : null;
    final dialogWidth = MediaQuery.of(context).size.width > 600 ? 450.0 : MediaQuery.of(context).size.width * 0.9;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: dialogWidth, padding: const EdgeInsets.all(32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Transfer ${staff.name}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  const Text('New Branch Assignment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), value: selectedBranch, items: provider.branches.map((b) => DropdownMenuItem<String>(value: b['_id'], child: Text(b['name']))).toList(), onChanged: (val) => setState(() => selectedBranch = val)),
                  const SizedBox(height: 16),
                  const Text('Update Role', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), value: selectedRole.toUpperCase(), items: ['STAFF', 'MANAGER', 'ADMIN'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(), onChanged: (val) => setState(() => selectedRole = val!)),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () async {
                        if (selectedBranch != null) {
                          Navigator.pop(context);
                          String? errorMessage = await provider.transferStaff(staff.id, selectedBranch!, selectedRole);
                          if (context.mounted) {
                            if (errorMessage == null) {
                              _showFeedback(context, true, 'Staff Transferred successfully!');
                            } else {
                              _showFeedback(context, false, errorMessage);
                            }
                          }
                        }
                      },
                      child: const Text('CONFIRM TRANSFER', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold)),
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

  Widget _buildSearchableDropdown({
    required String label, required String hint, required List<String> options,
    required void Function(String) onSelected, String? initialValue, IconData? prefixIcon,
  }) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: initialValue ?? ''),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) return options;
        return options.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      onSelected: (String selection) {
        FocusManager.instance.primaryFocus?.unfocus(); 
        onSelected(selection);
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: textEditingController, focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label, hintText: hint, prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: Colors.grey) : null,
            suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryGold, width: 2)),
            filled: true, fillColor: Colors.white,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8, borderRadius: BorderRadius.circular(12), color: Colors.white,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250, maxWidth: 400),
              child: ListView.builder(
                padding: EdgeInsets.zero, shrinkWrap: true, itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(padding: const EdgeInsets.all(16.0), child: Text(option, style: const TextStyle(fontWeight: FontWeight.bold))),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showStaffFinancialDashboard(BuildContext context, dynamic initialStaff) {
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 800; 
    final dialogWidth = size.width > 1000 ? 900.0 : size.width * 0.95;
    
    int currentPage = 1;
    final int itemsPerPage = 4;

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 40, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFF1E1E1E),
        child: StatefulBuilder( 
          builder: (context, setState) {
            return Consumer<AdminProvider>(
              builder: (context, provider, child) {
                var staff;
                try {
                  staff = provider.staffList.firstWhere((s) => s.id == initialStaff.id);
                } catch(e) {
                  try {
                    staff = provider.branchStaff.firstWhere((s) => s.id == initialStaff.id);
                  } catch(e) {
                    staff = initialStaff;
                  }
                }
                
                final double remainingAmount = staff.loanRemaining;
                final double principalAmount = staff.loanPrincipal;
                final double paidAmount = principalAmount > 0 ? (principalAmount - remainingAmount) : 0.0;
                final double loanProgress = principalAmount > 0 ? (paidAmount / principalAmount) : 0.0;
                final List<dynamic> allRepayments = staff.repayments.reversed.toList();
                final double salary = staff.salary;

                final totalPages = (allRepayments.length / itemsPerPage).ceil();
                final int startIndex = (currentPage - 1) * itemsPerPage;
                final int endIndex = (startIndex + itemsPerPage > allRepayments.length) ? allRepayments.length : startIndex + itemsPerPage;
                final paginatedRepayments = allRepayments.isNotEmpty ? allRepayments.sublist(startIndex, endIndex) : [];

                return Container(
                  width: dialogWidth,
                  height: size.height * 0.9,
                  padding: EdgeInsets.all(isMobile ? 16 : 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                CircleAvatar(radius: isMobile ? 18 : 24, backgroundColor: AppColors.primaryGold.withOpacity(0.2), child: Text(staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, fontSize: isMobile ? 16 : 20))),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${staff.name}', style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
                                      const Text('Payroll & Loans', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(dialogContext)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      Expanded(
                        child: SingleChildScrollView(
                          child: Flex(
                            direction: isMobile ? Axis.vertical : Axis.horizontal,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: isMobile ? double.infinity : (dialogWidth * 0.5),
                                child: Column(
                                  children: [
                                    _buildFinancialStatCard('Monthly Salary', '₹${salary.toStringAsFixed(0)}', Icons.payments, Colors.blue),
                                    const SizedBox(height: 20),
                                    _buildDebtProgressCard(remainingAmount, principalAmount, paidAmount, loanProgress, staff, provider, salary, dialogContext),
                                  ],
                                ),
                              ),
                              
                              if (!isMobile) const SizedBox(width: 32),
                              if (isMobile) const SizedBox(height: 32),

                              Expanded(
                                flex: isMobile ? 0 : 1,
                                child: _buildRepaymentLedger(paginatedRepayments, allRepayments.length, totalPages, currentPage, (p) => setState(() => currentPage = p), staff, provider, dialogContext),
                              )
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
            );
          }
        ),
      ),
    );
  }

  Widget _buildFinancialStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: 8), Text(title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13))]),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildDebtProgressCard(double remaining, double principal, double paid, double progress, dynamic staff, AdminProvider provider, double salary, BuildContext context) {
    bool hasDebt = remaining > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hasDebt ? Colors.redAccent.withOpacity(0.05) : Colors.green.withOpacity(0.05), 
        borderRadius: BorderRadius.circular(20), 
        border: Border.all(color: hasDebt ? Colors.redAccent.withOpacity(0.2) : Colors.green.withOpacity(0.2))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(hasDebt ? 'Outstanding Debt' : 'Debt Free', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('₹${remaining.toStringAsFixed(0)}', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: hasDebt ? Colors.redAccent : Colors.green)),
          if (hasDebt) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Paid: ₹${paid.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                Text('Total: ₹${principal.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: Colors.white10, valueColor: const AlwaysStoppedAnimation<Color>(Colors.green)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGold, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => _showRepaymentDialog(context, staff.id, remaining, provider),
              child: const Text('LOG REPAYMENT', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ] else ...[
            const SizedBox(height: 20),
            OutlinedButton(
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => _showIssueLoanDialog(context, staff.id, provider, salary),
              child: const Text('ISSUE LOAN / UPDATE SALARY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildRepaymentLedger(List paginated, int totalItems, int totalPages, int current, Function(int) onPageChange, dynamic staff, AdminProvider provider, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Repayment Ledger', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 16),
        if (paginated.isEmpty) 
          const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('No history found', style: TextStyle(color: Colors.white24))))
        else
          ...paginated.map((rep) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.05))),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rep['note'] ?? 'Repayment', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                      Text(DateFormat('dd MMM yy').format(DateTime.parse(rep['date']).toLocal()), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
                Text('+₹${rep['amount']}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                  onPressed: () async {
                     bool? confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Reverse?'), content: const Text('This adds amount back to debt.'), actions: [TextButton(onPressed:()=>Navigator.pop(ctx), child: const Text('Cancel')), ElevatedButton(onPressed:()=>Navigator.pop(ctx,true), child: const Text('Yes'))]));
                     if(confirm == true) await provider.deleteRepayment(staff.id, rep['_id']);
                  },
                )
              ],
            ),
          )),
        const SizedBox(height: 12),
        if (totalPages > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(onPressed: current > 1 ? () => onPageChange(current - 1) : null, icon: const Icon(Icons.arrow_back_ios, size: 14, color: Colors.white)),
              Text('$current / $totalPages', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              IconButton(onPressed: current < totalPages ? () => onPageChange(current + 1) : null, icon: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white)),
            ],
          )
      ],
    );
  }

  void _showIssueLoanDialog(BuildContext context, String staffId, AdminProvider provider, double currentSalary) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final salaryController = TextEditingController(text: currentSalary.toStringAsFixed(0));
    final loanController = TextEditingController();
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: isMobile ? size.width : 400, 
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Update Financials', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  TextField(controller: salaryController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Base Salary (₹)', border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  TextField(controller: loanController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Add New Loan (₹)', helperText: 'Added to existing debt', border: OutlineInputBorder())),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, minimumSize: const Size(double.infinity, 50)),
                    onPressed: isProcessing ? null : () async {
                      setState(() => isProcessing = true);
                      final err = await provider.updateFinancials(staffId, double.tryParse(salaryController.text) ?? currentSalary, double.tryParse(loanController.text) ?? 0.0);
                      Navigator.pop(context);
                      _showFeedback(context, err == null, err ?? 'Updated!');
                    },
                    child: isProcessing ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white)) : const Text('SAVE', style: TextStyle(color: AppColors.primaryGold)),
                  )
                ],
              ),
            ),
          ),
        );
      })
    );
  }

  void _showRepaymentDialog(BuildContext context, String staffId, double maxAmount, AdminProvider provider) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final amountController = TextEditingController();
    final noteController = TextEditingController(text: "Salary Deduction");
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: isMobile ? size.width : 400, 
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Log Repayment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Debt Remaining: ₹${maxAmount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  const SizedBox(height: 24),
                  TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount Paid (₹)', border: OutlineInputBorder())),
                  const SizedBox(height: 16),
                  TextField(controller: noteController, decoration: const InputDecoration(labelText: 'Note / Reason', border: OutlineInputBorder())),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, minimumSize: const Size(double.infinity, 50)),
                    onPressed: isProcessing ? null : () async {
                      final amt = double.tryParse(amountController.text) ?? 0;
                      if (amt > 0 && amt <= maxAmount) {
                        setState(() => isProcessing = true);
                        final err = await provider.logRepayment(staffId, amt, noteController.text);
                        Navigator.pop(context);
                        _showFeedback(context, err == null, err ?? 'Repayment Logged!');
                      }
                    },
                    child: isProcessing ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white)) : const Text('CONFIRM PAYMENT', style: TextStyle(color: AppColors.primaryGold)),
                  )
                ],
              ),
            ),
          ),
        );
      })
    );
  }
}
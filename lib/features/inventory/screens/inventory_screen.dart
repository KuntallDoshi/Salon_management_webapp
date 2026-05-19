import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../admin/providers/admin_provider.dart';
import '../provider/inventory_provider.dart';
import '../models/inventory_item.dart';
import '../../visitors/providers/staff_visitor_provider.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  // ─── PAGINATION & VIEW STATE ───
  String _currentView = 'Live Stock';
  String _searchQuery = '';
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final userBranchId = authProvider.currentUser?.branchId;
      final userRole = authProvider.userRole;

      if (userBranchId != null) {
        context.read<InventoryProvider>().fetchInitialData(userBranchId);
        final targetBranch = (userRole == 'ADMIN' || userRole == 'OWNER') ? 'all' : userBranchId;
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

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final adminProvider = context.watch<AdminProvider>();
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1024;
    final isTablet = size.width >= 600 && size.width < 1024;
    final isMobile = size.width < 600;

    List<dynamic> currentDataList = [];
    if (_currentView == 'Live Stock') {
      currentDataList = provider.items;
    } else if (_currentView == 'Transfers') {
      currentDataList = provider.transfers;
    } else if (_currentView == 'Sales') {
      currentDataList = provider.sales;
    } else if (_currentView == 'Brands') {
      currentDataList = adminProvider.brandsCatalog.where((b) => b['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    } else if (_currentView == 'Categories') {
      currentDataList = adminProvider.categoriesCatalog.where((c) => c['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    final totalPages = (currentDataList.length / _itemsPerPage).ceil();
    final paginatedData = _getPaginatedData(currentDataList);

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
                      Text('Inventory Management', style: TextStyle(fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.w800, color: AppColors.primaryBlack)).animate().fade(duration: 500.ms).slideX(begin: -0.1),
                      const SizedBox(height: 8),
                      Text('Manage stocks, history, catalog, and brands.', style: TextStyle(color: Colors.grey.shade600, fontSize: isMobile ? 14 : 16)).animate().fade(delay: 200.ms).slideX(begin: -0.1),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: IconButton(
                    tooltip: 'Refresh Data',
                    icon: const Icon(Icons.refresh, color: AppColors.primaryBlack),
                    onPressed: () {
                      if (provider.selectedBranchId != null) provider.fetchInventoryForBranch(provider.selectedBranchId!);
                      adminProvider.fetchAdminData(provider.selectedBranchId ?? 'all');
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
                ? _buildMobileControls(context, provider, adminProvider)
                : _buildDesktopControls(context, provider, adminProvider, isDesktop),
            ).animate().fade(delay: 300.ms).slideY(begin: 0.05),
            
            const SizedBox(height: 24),

            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 2))]),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (provider.isLoading || adminProvider.isLoading)
                        SizedBox(width: constraints.maxWidth, child: _buildShimmerTable(constraints.maxWidth))
                      else if (currentDataList.isEmpty)
                        _buildEmptyState('No records found', 'No data matches your filters.')
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
                                rows: paginatedData.map((item) => _buildTableRow(context, item, provider, adminProvider)).toList(),
                              ),
                            ),
                          ),
                        ),

                      if (!provider.isLoading && !adminProvider.isLoading && currentDataList.isNotEmpty)
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
                  );
                }
              ),
            ).animate().fade(delay: 500.ms).slideY(begin: 0.05),
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
        children: ['Live Stock', 'Transfers', 'Sales', 'Brands', 'Categories'].map((tab) {
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

  Widget _buildDesktopControls(BuildContext context, InventoryProvider provider, AdminProvider adminProvider, bool isDesktop) {
    return Wrap(
      spacing: 16, runSpacing: 16,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Wrap(
          spacing: 12, runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildCustomTabBar(),
            Container(
              height: 48, padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: provider.selectedBranchId,
                  icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primaryBlack),
                  items: provider.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                  onChanged: (val) { if (val != null) provider.setBranch(val); },
                ),
              ),
            ),
            if (_currentView == 'Live Stock' || _currentView == 'Brands' || _currentView == 'Categories') ...[
              Container(
                width: isDesktop ? 250 : 200, height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                child: TextField(
                  onChanged: (val) { 
                    if (_currentView == 'Live Stock') { provider.setSearchQuery(val); } else { _searchQuery = val; }
                    setState(() => _currentPage = 1); 
                  },
                  decoration: const InputDecoration(icon: Icon(Icons.search, color: Colors.grey), hintText: 'Search...', border: InputBorder.none),
                ),
              ),
              if (_currentView == 'Live Stock')
                Container(
                  height: 48, width: 48,
                  decoration: BoxDecoration(color: AppColors.primaryBlack, borderRadius: BorderRadius.circular(12)),
                  child: IconButton(
                    tooltip: 'Advanced Filters',
                    icon: const Icon(Icons.tune, color: AppColors.primaryGold),
                    onPressed: () => _showFilterDialog(provider),
                  ),
                ),
            ]
          ],
        ),
        Wrap(
          spacing: 12, runSpacing: 12,
          children: [
            if (_currentView == 'Brands' || _currentView == 'Categories') ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, foregroundColor: AppColors.primaryGold, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), 
                icon: Icon(_currentView == 'Brands' ? Icons.branding_watermark : Icons.category, size: 20), 
                label: Text('New ${_currentView == 'Brands' ? 'Brand' : 'Category'}', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)), 
                onPressed: () => _showAddBrandCategoryDialog(adminProvider, isBrand: _currentView == 'Brands', isEdit: false)
              ),
            ] else ...[
              TextButton.icon(style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), foregroundColor: Colors.grey.shade700), icon: const Icon(Icons.remove_circle_outline, size: 20), label: const Text('Log Usage', style: TextStyle(fontWeight: FontWeight.bold)), onPressed: () => _showGlobalStockDialog(provider, isAdding: false)),
              OutlinedButton.icon(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), foregroundColor: AppColors.primaryBlack, side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: const Icon(Icons.add_box_outlined, size: 20), label: const Text('Add Stock', style: TextStyle(fontWeight: FontWeight.bold)), onPressed: () => _showGlobalStockDialog(provider, isAdding: true)),
              ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, foregroundColor: AppColors.primaryGold, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: const Icon(Icons.inventory_2, size: 20), label: const Text('New Product', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)), onPressed: () => _showCreateProductDialog(provider, adminProvider)),
            ]
          ],
        ),
      ],
    );
  }

  Widget _buildMobileControls(BuildContext context, InventoryProvider provider, AdminProvider adminProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, 
      children: [
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: _buildCustomTabBar()), 
        const SizedBox(height: 12),
        Container(
          height: 54, padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true, value: provider.selectedBranchId,
              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primaryBlack),
              items: provider.branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
              onChanged: (val) { if (val != null) provider.setBranch(val); },
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        if (_currentView == 'Live Stock' || _currentView == 'Brands' || _currentView == 'Categories') ...[
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 54, padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                  child: TextField(
                    onChanged: (val) { 
                      if (_currentView == 'Live Stock') { provider.setSearchQuery(val); } else { _searchQuery = val; }
                      setState(() => _currentPage = 1); 
                    },
                    decoration: const InputDecoration(icon: Icon(Icons.search, color: Colors.grey), hintText: 'Search...', border: InputBorder.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_currentView == 'Live Stock')
                Container(
                  height: 54, width: 54,
                  decoration: BoxDecoration(color: AppColors.primaryBlack, borderRadius: BorderRadius.circular(12)),
                  child: IconButton(icon: const Icon(Icons.tune, color: AppColors.primaryGold), onPressed: () => _showFilterDialog(provider)),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        
        if (_currentView == 'Brands' || _currentView == 'Categories') ...[
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, foregroundColor: AppColors.primaryGold, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), 
            icon: Icon(_currentView == 'Brands' ? Icons.branding_watermark : Icons.category, size: 20), 
            label: Text('New ${_currentView == 'Brands' ? 'Brand' : 'Category'}', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)), 
            onPressed: () => _showAddBrandCategoryDialog(adminProvider, isBrand: _currentView == 'Brands', isEdit: false)
          ),
        ] else ...[
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), foregroundColor: Colors.grey.shade800, side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: const Icon(Icons.remove_circle_outline, size: 18), label: const Text('Use', style: TextStyle(fontWeight: FontWeight.bold)), onPressed: () => _showGlobalStockDialog(provider, isAdding: false))),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), foregroundColor: AppColors.primaryBlack, side: BorderSide(color: AppColors.primaryBlack, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: const Icon(Icons.add_box_outlined, size: 18), label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)), onPressed: () => _showGlobalStockDialog(provider, isAdding: true))),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, foregroundColor: AppColors.primaryGold, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: const Icon(Icons.inventory_2, size: 20), label: const Text('New Product', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)), onPressed: () => _showCreateProductDialog(provider, adminProvider)),
        ]
      ],
    );
  }

  Widget _buildShimmerTable(double maxWidth) {
    return SizedBox(
      width: maxWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(6, (index) => Container(
          height: 60, decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100)), color: Colors.white), padding: const EdgeInsets.symmetric(horizontal: 24),
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
        )).animate(onPlay: (controller) => controller.repeat()).shimmer(duration: 1200.ms, color: Colors.white60),
      ),
    );
  }

  List<DataColumn> _getTableColumns() {
    if (_currentView == 'Brands' || _currentView == 'Categories') {
      return const [DataColumn(label: Text('NAME')), DataColumn(label: Text('DESCRIPTION')), DataColumn(label: Text('STATUS')), DataColumn(label: Text('ACTIONS'))];
    } else if (_currentView == 'Live Stock') {
      return const [DataColumn(label: Text('PRODUCT NAME')), DataColumn(label: Text('CATEGORY')), DataColumn(label: Text('PRICE')), DataColumn(label: Text('STOCK LVL')), DataColumn(label: Text('STATUS')), DataColumn(label: Text('ACTIONS'))];
    } else if (_currentView == 'Transfers') {
      return const [DataColumn(label: Text('DATE')), DataColumn(label: Text('TYPE')), DataColumn(label: Text('ITEM NAME')), DataColumn(label: Text('BRAND')), DataColumn(label: Text('QUANTITY'))];
    } else { 
      return const [DataColumn(label: Text('DATE')), DataColumn(label: Text('ITEM NAME')), DataColumn(label: Text('BRAND')), DataColumn(label: Text('QUANTITY')), DataColumn(label: Text('NOTES'))];
    }
  }

  DataRow _buildTableRow(BuildContext context, dynamic item, InventoryProvider provider, AdminProvider adminProvider) {
    if (_currentView == 'Brands' || _currentView == 'Categories') {
      final itemMap = item as Map<String, dynamic>;
      final isBrand = _currentView == 'Brands';
      return DataRow(cells: [
        DataCell(Text(itemMap['name'], style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(itemMap['description'] ?? 'No description', style: TextStyle(color: Colors.grey.shade600))),
        DataCell(_buildBadge(itemMap['isActive'] ? 'Active' : 'Inactive', itemMap['isActive'] ? Colors.green : Colors.red)),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue), onPressed: () => _showAddBrandCategoryDialog(adminProvider, isBrand: isBrand, isEdit: true, data: itemMap)),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent), 
              onPressed: () async {
                String? err = isBrand ? await adminProvider.removeBrand(itemMap['_id']) : await adminProvider.removeCategory(itemMap['_id']);
                if (mounted) _showFeedback(err == null, err ?? '${isBrand ? "Brand" : "Category"} Deleted!');
              }
            ),
          ],
        )),
      ]);
    } else if (_currentView == 'Live Stock') {
      final i = item as InventoryItem;
      return DataRow(cells: [
        DataCell(Text(i.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
        DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)), child: Text(i.category.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey.shade700)))),
        DataCell(Text('₹${i.price}', style: const TextStyle(fontWeight: FontWeight.w600))),
        DataCell(Text('${i.currentStock}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: i.isLowStock ? Colors.redAccent : AppColors.primaryBlack))),
        DataCell(i.isLowStock ? _buildBadge('Need ${i.neededStock}', Colors.redAccent) : _buildBadge('Healthy', Colors.green)),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(message: 'Transfer', child: IconButton(icon: const Icon(Icons.sync_alt, color: Colors.blue), onPressed: () => _showTransferDialog(i, provider))),
            const SizedBox(width: 8),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, foregroundColor: AppColors.primaryGold, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), onPressed: () => _showSellDialog(i, provider), child: const Text('SELL', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        )),
      ]);
    } else if (_currentView == 'Transfers') {
      final t = item as StockTransactionModel;
      final isIncoming = t.type == 'transfer_in';
      return DataRow(cells: [
        DataCell(Text(_formatDate(t.date), style: const TextStyle(fontWeight: FontWeight.bold))), 
        DataCell(Row(children: [Icon(isIncoming ? Icons.arrow_downward : Icons.arrow_upward, color: isIncoming ? Colors.green : Colors.blue, size: 16), const SizedBox(width: 8), Text(t.type.toUpperCase().replaceAll('_', ' '), style: TextStyle(color: isIncoming ? Colors.green : Colors.blue, fontWeight: FontWeight.bold))])),
        DataCell(Text(t.itemName, style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(t.brand, style: TextStyle(color: Colors.grey.shade600))),
        DataCell(Text('${t.quantity.abs()}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
      ]);
    } else { 
      final s = item as StockTransactionModel;
      return DataRow(cells: [
        DataCell(Text(_formatDate(s.date), style: const TextStyle(fontWeight: FontWeight.bold))), 
        DataCell(Text(s.itemName, style: const TextStyle(fontWeight: FontWeight.bold))),
        DataCell(Text(s.brand, style: TextStyle(color: Colors.grey.shade600))), 
        DataCell(Text('${s.quantity.abs()}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.orange))),
        DataCell(Text(s.note ?? 'Manual Usage', style: TextStyle(color: Colors.grey.shade600))),
      ]);
    }
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.all(80.0),
      child: Center(
        child: Column(
          children: [
            Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle), child: Icon(Icons.table_chart_outlined, size: 64, color: Colors.grey.shade300)),
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
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.3))), child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)));
  }

  // ======================================================================
  // 🚀 ALL DIALOG FUNCTIONS ARE FULLY UPGRADED TO PREMIUM UI
  // ======================================================================

  void _showFeedback(bool success, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: success ? Colors.green.shade700 : Colors.redAccent.shade700, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  // ─── FILTER DIALOG ───
  void _showFilterDialog(InventoryProvider provider) {
    final catController = TextEditingController();
    final brandController = TextEditingController();
    final minController = TextEditingController();
    final maxController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        final dialogWidth = MediaQuery.sizeOf(dialogContext).width > 600 ? 400.0 : MediaQuery.sizeOf(dialogContext).width * 0.9;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: dialogWidth, padding: const EdgeInsets.all(32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primaryGold.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.tune, color: AppColors.primaryGold)),
                        const SizedBox(width: 16),
                        const Text('Filter Inventory', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      ]),
                      IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(dialogContext)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Find exact products in stock.', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                  const SizedBox(height: 32),
                  
                  TextField(controller: catController, decoration: InputDecoration(labelText: 'Category (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  const SizedBox(height: 16),
                  TextField(controller: brandController, decoration: InputDecoration(labelText: 'Brand (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: minController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Min Price', prefixIcon: const Icon(Icons.currency_rupee, size: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                      const SizedBox(width: 16),
                      Expanded(child: TextField(controller: maxController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Max Price', prefixIcon: const Icon(Icons.currency_rupee, size: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                    ],
                  ),
                  const SizedBox(height: 40),
                  
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () {
                        Navigator.pop(dialogContext);
                        provider.fetchInventoryForBranch(provider.selectedBranchId!); 
                      }, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('RESET', style: TextStyle(color: Colors.black)))),
                      const SizedBox(width: 16),
                      Expanded(child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          double? minP = double.tryParse(minController.text);
                          double? maxP = double.tryParse(maxController.text);
                          provider.fetchInventoryForBranch(provider.selectedBranchId!, category: catController.text, brand: brandController.text, minPrice: minP, maxPrice: maxP);
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
      }
    );
  }

  // ─── ADD STOCK / LOG USAGE DIALOG ───
  void _showGlobalStockDialog(InventoryProvider provider, {required bool isAdding, String? initialProductName}) {
    final bool hasItems = isAdding ? provider.masterProducts.isNotEmpty : provider.items.isNotEmpty;
    if (!hasItems) {
      _showFeedback(false, isAdding ? "Global Catalog is empty." : "No inventory in this branch.");
      return;
    }
    
    String selectedProductId = isAdding ? provider.masterProducts.first.id : provider.items.first.productId;
    if (initialProductName != null && isAdding) {
      try {
        final newProd = provider.masterProducts.firstWhere((p) => p.name.toLowerCase().trim() == initialProductName.toLowerCase().trim());
        selectedProductId = newProd.id;
      } catch (e) {
        debugPrint("Auto-select failed");
      }
    }

    final qtyController = TextEditingController(text: '1');
    bool isProcessing = false; 
    
    Map<String, String> nameToIdMap = {};
    List<String> productNames = [];
    
    if (isAdding) {
      for (var p in provider.masterProducts) { nameToIdMap[p.name] = p.id; productNames.add(p.name); }
    } else {
      for (var i in provider.items) { nameToIdMap['${i.name} (Stock: ${i.currentStock})'] = i.productId; productNames.add('${i.name} (Stock: ${i.currentStock})'); }
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        final dialogWidth = MediaQuery.sizeOf(dialogContext).width > 600 ? 450.0 : MediaQuery.sizeOf(dialogContext).width * 0.9;
        
        return StatefulBuilder(builder: (context, setState) {
          int qty = int.tryParse(qtyController.text) ?? 1;
          int maxAvailable = 0;
          if (!isAdding) {
            final currentItem = provider.items.firstWhere((i) => i.productId == selectedProductId, orElse: () => provider.items.first);
            maxAvailable = currentItem.currentStock;
          }
          
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              width: dialogWidth, padding: const EdgeInsets.all(32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isAdding ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1), shape: BoxShape.circle), child: Icon(isAdding ? Icons.add_box_rounded : Icons.remove_circle_outline, color: isAdding ? Colors.green : Colors.orange)),
                            const SizedBox(width: 16),
                            Text(isAdding ? 'Add Stock' : 'Log Usage', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(dialogContext)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(isAdding ? 'Add inventory items to this branch.' : 'Log items used internally at the salon.', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                    const SizedBox(height: 32),
                    
                    _buildSearchableDropdown(
                      label: 'Search Product',
                      hint: 'Type to find a product...',
                      prefixIcon: Icons.search,
                      options: productNames,
                      initialValue: initialProductName, 
                      onSelected: (String selection) {
                        setState(() {
                          selectedProductId = nameToIdMap[selection]!;
                          if (!isAdding) qtyController.text = '1';
                        });
                      }
                    ),
                    
                    const SizedBox(height: 24),
                    Text(isAdding ? 'Quantity to Add' : 'Quantity Used (Max: $maxAvailable)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: InputDecoration(prefixIcon: const Icon(Icons.numbers, color: Colors.grey), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryGold, width: 2))), onChanged: (val) => setState(() {})),
                    if (!isAdding && qty > maxAvailable) Padding(padding: const EdgeInsets.only(top: 8.0), child: Text('Cannot exceed stock ($maxAvailable)', style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold))),
                    const SizedBox(height: 40),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: isProcessing ? null : () async {
                          if (qty > 0 && (isAdding || qty <= maxAvailable)) {
                            setState(() => isProcessing = true);
                            bool success; String? errorMessage;
                            
                            if (isAdding) {
                              errorMessage = await provider.addStock(selectedProductId, qty);
                              success = errorMessage == null;
                            } else {
                              success = await provider.logUsage(selectedProductId, qty, "Internal Salon Usage");
                              errorMessage = success ? null : "Operation failed.";
                            }
                
                            if (mounted) {
                              Navigator.pop(dialogContext);
                              _showFeedback(success, success ? "Operation successful!" : errorMessage!);
                            }
                          }
                        },
                        child: isProcessing ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.primaryGold, strokeWidth: 2)) : Text(isAdding ? 'CONFIRM ADDITION' : 'CONFIRM USAGE', style: const TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, letterSpacing: 2))
                      )
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      }
    );
  }

// ─── CREATE PRODUCT DIALOG (RESPONSIVE UPGRADE) ───
  void _showCreateProductDialog(InventoryProvider provider, AdminProvider adminProvider) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final thresholdController = TextEditingController(text: '10');
    
    String? selectedBrand;
    String? selectedCategory;
    String selectedUnit = 'pcs'; 
    bool isProcessing = false; 

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setState) {
          // 🚀 RESPONSIVE MATH
          final size = MediaQuery.of(context).size;
          final bool isMobile = size.width < 600;
          final dialogWidth = isMobile ? size.width * 0.95 : 550.0;

          return Dialog(
            // 🚀 Shrink margins on mobile
            insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 40, vertical: 24),
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
                    // ─── HEADER ───
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(isMobile ? 8 : 12),
                                decoration: BoxDecoration(color: AppColors.primaryGold.withOpacity(0.15), shape: BoxShape.circle),
                                child: Icon(Icons.inventory_2, color: AppColors.primaryGold, size: isMobile ? 20 : 28)
                              ),
                              const SizedBox(width: 12),
                              const Text('New Product', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey), 
                          onPressed: () => Navigator.pop(dialogContext),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ]
                    ),
                    const SizedBox(height: 8),
                    Text('Create a new item in the global catalog.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    const SizedBox(height: 24),
                    
                    // ─── PRODUCT NAME ───
                    const Text('Product Details', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController, 
                      decoration: InputDecoration(
                        labelText: 'Product Name', prefixIcon: const Icon(Icons.label_outline, size: 20),
                        filled: true, fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                      )
                    ),
                    const SizedBox(height: 16),
                    
                    // ─── BRAND & CATEGORY (STACKS ON MOBILE) ───
                    Flex(
                      direction: isMobile ? Axis.vertical : Axis.horizontal,
                      children: [
                        Expanded(
                          flex: isMobile ? 0 : 1,
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(labelText: 'Brand', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200))),
                            value: selectedBrand, hint: const Text('Select Brand', style: TextStyle(fontSize: 13)), isExpanded: true,
                            items: adminProvider.brandsCatalog.map((b) => DropdownMenuItem<String>(value: b['name'], child: Text(b['name'], style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (val) => setState(() => selectedBrand = val),
                          ),
                        ),
                        if (isMobile) const SizedBox(height: 16) else const SizedBox(width: 12),
                        Expanded(
                          flex: isMobile ? 0 : 1,
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(labelText: 'Category', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200))),
                            value: selectedCategory, hint: const Text('Select Category', style: TextStyle(fontSize: 13)), isExpanded: true,
                            items: adminProvider.categoriesCatalog.map((c) => DropdownMenuItem<String>(value: c['name'], child: Text(c['name'], style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (val) => setState(() => selectedCategory = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    const Text('Pricing & Inventory Rules', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
                    const SizedBox(height: 12),
                    
                    // ─── PRICE, ALERT, UNIT (STACKS ON MOBILE) ───
                    Flex(
                      direction: isMobile ? Axis.vertical : Axis.horizontal,
                      children: [
                        Expanded(
                          flex: isMobile ? 0 : 2,
                          child: TextField(controller: priceController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Unit Price', prefixIcon: const Icon(Icons.currency_rupee, size: 18), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                        ),
                        if (isMobile) const SizedBox(height: 16) else const SizedBox(width: 12),
                        Expanded(
                          flex: isMobile ? 0 : 2,
                          child: TextField(controller: thresholdController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Alert At Qty', prefixIcon: const Icon(Icons.warning_amber_rounded, size: 18), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                        ),
                        if (isMobile) const SizedBox(height: 16) else const SizedBox(width: 12),
                        Expanded(
                          flex: isMobile ? 0 : 1,
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(labelText: 'Unit', filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), 
                            value: selectedUnit, 
                            items: ['pcs', 'ml', 'gm', 'ltr', 'kg'].map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13)))).toList(), 
                            onChanged: (val) => setState(() => selectedUnit = val!)
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    // ─── SUBMIT BUTTON ───
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, padding: EdgeInsets.symmetric(vertical: isMobile ? 16 : 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: isProcessing ? null : () async {
                          final name = nameController.text.trim();
                          final price = double.tryParse(priceController.text) ?? 0.0;
                          final threshold = int.tryParse(thresholdController.text) ?? 10;
                          
                          if (name.isNotEmpty && selectedBrand != null && selectedCategory != null && price > 0) {
                            setState(() => isProcessing = true);
                            final errorMessage = await provider.createNewMasterProduct(name, selectedBrand!, selectedCategory!, price, threshold);
                            
                            if (mounted) {
                              Navigator.pop(dialogContext); 
                              if (errorMessage == null) {
                                 _showSuccessPrompt(name, provider); // Custom Success Dialog
                              } else {
                                 _showFeedback(false, errorMessage);
                              }
                            }
                          } else {
                            _showFeedback(false, "Please fill all details.");
                          }
                        },
                        child: isProcessing 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.primaryGold, strokeWidth: 2)) 
                          : const Text('CREATE PRODUCT', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, letterSpacing: 1.5))
                      )
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      }
    );
  }

  // 🚀 Helper to show the success prompt after creation
  void _showSuccessPrompt(String name, InventoryProvider provider) {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (BuildContext successContext) {
        final isMobile = MediaQuery.of(successContext).size.width < 600;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 20 : 32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.check_circle, color: Colors.green, size: 48)),
                const SizedBox(height: 20),
                Text('Product Created!', style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Text('"$name" is now in the catalog. Add stock to your branch?', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () {
                      Navigator.pop(successContext);
                      _showGlobalStockDialog(provider, isAdding: true, initialProductName: name);
                    },
                    child: const Text('ADD STOCK NOW', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold)),
                  )
                ),
                TextButton(onPressed: () => Navigator.pop(successContext), child: const Text('Maybe Later', style: TextStyle(color: Colors.grey)))
              ]
            )
          )
        );
      }
    );
  }

  // ─── SELL PRODUCT DIALOG ───
  // ─── SELL PRODUCT DIALOG (RESPONSIVE UPGRADE) ───
  void _showSellDialog(InventoryItem item, InventoryProvider provider) {
    final nameController = TextEditingController(); 
    final phoneController = TextEditingController(); 
    final qtyController = TextEditingController(text: '1');
    final discountController = TextEditingController(text: '0');
    
    TextEditingController? autoNameController;
    bool isProcessing = false; 
    bool isFetchingUser = false; 

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (context, setState) {
          // 🚀 RESPONSIVE MATH
          final size = MediaQuery.of(context).size;
          final bool isMobile = size.width < 600;
          final dialogWidth = isMobile ? size.width * 0.95 : 550.0;

          int qty = int.tryParse(qtyController.text) ?? 1;
          double discount = double.tryParse(discountController.text) ?? 0.0;
          double finalPrice = (item.price * qty) - ((item.price * qty) * (discount / 100));

          return Dialog(
            // 🚀 Fix: Ensure dialog doesn't look like a tiny column on mobile
            insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 40, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isMobile ? 16 : 24)),
            child: Container(
              width: dialogWidth,
              padding: EdgeInsets.all(isMobile ? 20 : 32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── HEADER ───
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.all(10), 
                              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle), 
                              child: Icon(Icons.point_of_sale, color: Colors.green, size: isMobile ? 22 : 28)
                            ),
                            const SizedBox(width: 12),
                            Text('Direct Sale', style: TextStyle(fontSize: isMobile ? 18 : 22, fontWeight: FontWeight.bold)),
                          ]),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close), 
                          onPressed: () => Navigator.pop(dialogContext),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ─── ITEM PREVIEW CARD ───
                    Container(
                      padding: const EdgeInsets.all(16), 
                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start, 
                              children: [
                                Text(item.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 14 : 16), overflow: TextOverflow.ellipsis), 
                                Text('Stock: ${item.currentStock} units', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))
                              ]
                            )
                          ),
                          Text('₹${item.price}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ─── CUSTOMER PHONE ───
                    const Text('Customer Info', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController, keyboardType: TextInputType.phone, maxLength: 10,
                      decoration: InputDecoration(
                        labelText: 'Phone (Optional)', prefixText: '+91 ', 
                        counterText: '', prefixIcon: const Icon(Icons.phone, size: 20),
                        filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: isFetchingUser ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGold))) : null,
                      ),
                      onChanged: (val) async {
                        if (val.length == 10) {
                          setState(() => isFetchingUser = true);
                          try {
                            final staffVisitorProvider = Provider.of<StaffVisitorProvider>(context, listen: false);
                            final returningVisitor = await staffVisitorProvider.checkReturningVisitor(val);
                            if (mounted) {
                              setState(() {
                                isFetchingUser = false;
                                if (returningVisitor != null) {
                                  nameController.text = returningVisitor['name'];
                                  autoNameController?.text = returningVisitor['name'];
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Customer Found! 🎉'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
                                }
                              });
                            }
                          } catch (e) { if (mounted) setState(() => isFetchingUser = false); }
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // ─── CUSTOMER NAME (AUTOCOMPLETE) ───
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue val) async {
                        if (val.text.isEmpty) return const Iterable<String>.empty();
                        final staffVisitorProvider = Provider.of<StaffVisitorProvider>(context, listen: false);
                        final results = await staffVisitorProvider.searchVisitors(val.text);
                        return results.map((v) => "${v['name']} - ${v['phone']}").toList();
                      },
                      onSelected: (String selection) {
                        final parts = selection.split(' - ');
                        nameController.text = parts[0];
                        if (parts.length > 1) phoneController.text = parts[1];
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        if (autoNameController == null) {
                          autoNameController = textEditingController;
                          autoNameController!.addListener(() { nameController.text = autoNameController!.text; });
                        }
                        return TextField(
                          controller: textEditingController, focusNode: focusNode,
                          decoration: InputDecoration(labelText: 'Customer Name', prefixIcon: const Icon(Icons.person_outline, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // ─── QTY & DISCOUNT (STACKS ON MOBILE) ───
                    Flex(
                      direction: isMobile ? Axis.vertical : Axis.horizontal,
                      children: [
                        Expanded(
                          flex: isMobile ? 0 : 1,
                          child: TextField(
                            controller: qtyController, keyboardType: TextInputType.number, 
                            decoration: InputDecoration(labelText: 'Qty (Max: ${item.currentStock})', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), 
                            onChanged: (val) => setState(() {})
                          ),
                        ),
                        if (isMobile) const SizedBox(height: 12) else const SizedBox(width: 12),
                        Expanded(
                          flex: isMobile ? 0 : 1,
                          child: TextField(
                            controller: discountController, keyboardType: TextInputType.number, 
                            decoration: InputDecoration(labelText: 'Discount (%)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), 
                            onChanged: (val) => setState(() {})
                          ),
                        ),
                      ],
                    ),
                    
                    if (qty > item.currentStock) 
                      Padding(padding: const EdgeInsets.only(top: 8), child: Text('⚠️ Not enough stock', style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold))),

                    const SizedBox(height: 24),
                    const Divider(),
                    
                    // ─── TOTAL PRICE ───
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                        children: [
                          const Text('Total to Pay:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey)),
                          Text('₹${finalPrice.toStringAsFixed(0)}', style: TextStyle(fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.w900, color: Colors.green)),
                        ]
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ─── SUBMIT BUTTON ───
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, padding: EdgeInsets.symmetric(vertical: isMobile ? 16 : 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: isProcessing ? null : () async {
                          if (qty > 0 && qty <= item.currentStock && nameController.text.trim().isNotEmpty) {
                            setState(() => isProcessing = true);
                            String savedName = phoneController.text.isNotEmpty ? "${nameController.text.trim()} (${phoneController.text})" : nameController.text.trim();
                            bool success = await provider.sellToVisitor(item.productId, savedName, qty, discount);
                            if (mounted) {
                              Navigator.pop(dialogContext);
                              _showFeedback(success, success ? "Sale completed!" : "Sale failed.");
                            }
                          } else {
                            _showFeedback(false, "Please provide customer name and valid quantity.");
                          }
                        },
                        child: isProcessing 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.primaryGold, strokeWidth: 2)) 
                          : const Text('CONFIRM DIRECT SALE', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, letterSpacing: 1.5))
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      }
    );
  }

  // ─── TRANSFER DIALOG ───
  void _showTransferDialog(InventoryItem item, InventoryProvider provider) {
    final qtyController = TextEditingController(text: '1');
    String? targetBranchId;
    bool isProcessing = false; 

    showDialog(
      context: context,
      builder: (dialogContext) {
        final dialogWidth = MediaQuery.sizeOf(dialogContext).width > 600 ? 450.0 : MediaQuery.sizeOf(dialogContext).width * 0.9;

        return StatefulBuilder(builder: (context, setState) {
          int qty = int.tryParse(qtyController.text) ?? 1;
          final availableBranches = provider.branches.where((b) => b.id != item.branchId).toList();
          if (availableBranches.isNotEmpty && targetBranchId == null) targetBranchId = availableBranches.first.id;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              width: dialogWidth, padding: const EdgeInsets.all(32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.sync_alt, color: Colors.blue)),
                            const SizedBox(width: 16),
                            const Text('Transfer Stock', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(dialogContext)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Move stock securely to another branch.', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                    const SizedBox(height: 24),
                    
                    Container(
                      padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                      child: Row(
                        children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis), Text('Current Stock: ${item.currentStock}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13))])),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: 'Destination Branch', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      value: targetBranchId, isExpanded: true,
                      items: availableBranches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (val) => setState(() => targetBranchId = val),
                    ),
                    const SizedBox(height: 16),
                    TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Quantity (Max: ${item.currentStock})', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), onChanged: (val) => setState(() {})),
                    
                    if (qty > item.currentStock) Padding(padding: const EdgeInsets.only(top: 8.0), child: Text('Cannot exceed available stock (${item.currentStock})', style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold))),
                    const SizedBox(height: 32),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: isProcessing ? null : () async {
                          if (qty > 0 && targetBranchId != null && qty <= item.currentStock) {
                            setState(() => isProcessing = true);
  
                            String? errorMessage = await provider.transferStock(item.productId, targetBranchId!, qty);
                            
                            if (mounted) {
                              Navigator.pop(dialogContext); 
                              if (errorMessage == null) {
                                _showFeedback(true, "Transfer successful!");
                              } else {
                                _showFeedback(false, "Failed: $errorMessage");
                              }
                            }
                          } else {
                            _showFeedback(false, "Invalid quantity.");
                          }
                        },
                        child: isProcessing ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.primaryGold, strokeWidth: 2)) : const Text('CONFIRM TRANSFER', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, letterSpacing: 1)))),
                  ],
                ),
              ),
            ),
          );
        });
      }
    );
  }

  // ─── ADD/EDIT BRAND OR CATEGORY DIALOG ───
  void _showAddBrandCategoryDialog(AdminProvider provider, {required bool isBrand, required bool isEdit, Map<String, dynamic>? data}) {
    final nameCtrl = TextEditingController(text: isEdit ? data!['name'] : '');
    final descCtrl = TextEditingController(text: isEdit ? (data!['description'] ?? '') : '');
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        final dialogWidth = MediaQuery.sizeOf(dialogContext).width > 600 ? 400.0 : MediaQuery.sizeOf(dialogContext).width * 0.9;

        return StatefulBuilder(builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              width: dialogWidth, padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primaryGold.withOpacity(0.1), shape: BoxShape.circle), child: Icon(isEdit ? Icons.edit : (isBrand ? Icons.branding_watermark : Icons.category), color: AppColors.primaryGold)), 
                        const SizedBox(width: 16), 
                        Text('${isEdit ? "Edit" : "New"} ${isBrand ? "Brand" : "Category"}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))
                      ]),
                      IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(dialogContext)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Define a new grouping for the catalog.', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                  const SizedBox(height: 24),
                  
                  TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  const SizedBox(height: 16),
                  TextField(controller: descCtrl, decoration: InputDecoration(labelText: 'Description (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  const SizedBox(height: 32),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: isProcessing ? null : () async {
                        if (nameCtrl.text.isNotEmpty) {
                          setState(() => isProcessing = true);
                          String? err;
                          if (isEdit) {
                              err = isBrand ? await provider.editBrand(data!['_id'], nameCtrl.text, descCtrl.text) : await provider.editCategory(data!['_id'], nameCtrl.text, descCtrl.text);
                          } else {
                              err = isBrand ? await provider.addBrand(nameCtrl.text, descCtrl.text) : await provider.addCategory(nameCtrl.text, descCtrl.text);
                          }
                          
                          if (mounted) {
                            Navigator.pop(dialogContext);
                            _showFeedback(err == null, err ?? '${isBrand ? "Brand" : "Category"} ${isEdit ? "Updated" : "Created"}!');
                          }
                        }
                      },
                      child: isProcessing ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.primaryGold, strokeWidth: 2)) : Text(isEdit ? 'UPDATE ${isBrand ? "BRAND" : "CATEGORY"}' : 'SAVE ${isBrand ? "BRAND" : "CATEGORY"}', style: const TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          );
        });
      }
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
              constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300),
              child: ListView.separated(
                padding: EdgeInsets.zero, shrinkWrap: true, itemCount: options.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return InkWell(onTap: () => onSelected(option), child: Padding(padding: const EdgeInsets.all(16.0), child: Text(option, style: const TextStyle(fontWeight: FontWeight.bold))));
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
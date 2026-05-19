import 'dart:async'; // 🚀 Needed for Debouncer
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/revenue_provider.dart';

class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  String? _selectedBranchId; 
  int _currentPage = 1;
  final int _itemsPerPage = 10;
  
  Map<String, bool> _gstStates = {}; 

  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<RevenueProvider>().fetchInitialData(auth.userRole ?? 'STAFF', auth.currentUser?.branchId ?? '');
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      final auth = context.read<AuthProvider>();
      final isAdmin = auth.userRole == 'ADMIN' || auth.userRole == 'MANAGER' || auth.userRole == 'OWNER';
      String targetBranch = isAdmin ? (_selectedBranchId ?? 'all') : (auth.currentUser?.branchId ?? '');
      
      setState(() => _currentPage = 1);
      context.read<RevenueProvider>().fetchRevenueData(targetBranch, search: query, page: 1);
    });
  }

  void _showTopSnackbar(BuildContext context, String message, bool isSuccess) {
    final size = MediaQuery.of(context).size;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isSuccess ? Icons.check_circle : Icons.info, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green.shade700 : AppColors.primaryBlack,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: size.height - 120, 
          left: 24, 
          right: size.width > 400 ? size.width - 350 : 24, 
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
        elevation: 10,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RevenueProvider>();
    final auth = context.watch<AuthProvider>();
    final size = MediaQuery.of(context).size;
    
    final isDesktop = size.width >= 1024;
    final isTablet = size.width >= 600 && size.width < 1024;
    final isMobile = size.width < 600;
    
    final isAdmin = auth.userRole == 'ADMIN' || auth.userRole == 'MANAGER' || auth.userRole == 'OWNER';

    // 🚀 FIXED: Render directly from the API source (since it's already paginated to 10 items)
    final paginatedData = provider.transactions;

    return Container(
      color: const Color(0xFFF8F9FA),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16.0 : (isTablet ? 24.0 : 40.0)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── HEADER ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Financial Reports', style: TextStyle(fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.w800, color: AppColors.primaryBlack)).animate().fade(duration: 500.ms).slideX(begin: -0.1),
                      const SizedBox(height: 8),
                      Text('Track revenue, download invoices, and export accounting data.', style: TextStyle(color: Colors.grey.shade600, fontSize: isMobile ? 14 : 16)).animate().fade(delay: 200.ms).slideX(begin: -0.1),
                    ],
                  ),
                ),
                if (!isMobile) const SizedBox(width: 16),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200), boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_balance_wallet, color: Colors.green, size: isMobile ? 20 : 24),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Page Revenue', style: TextStyle(fontSize: isMobile ? 10 : 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                          Text('₹${provider.totalRevenue.toStringAsFixed(0)}', style: TextStyle(fontSize: isMobile ? 16 : 20, fontWeight: FontWeight.w900, color: Colors.green)),
                        ],
                      ),
                    ],
                  ),
                ).animate().fade().scale(),
              ],
            ),
            
            SizedBox(height: isMobile ? 24 : 32),

            // ─── UNIFIED CONTROL CENTER ───
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))]),
              child: isMobile 
                ? _buildMobileControls(provider, isAdmin, auth)
                : _buildDesktopControls(provider, isAdmin, isDesktop, auth),
            ).animate().fade(delay: 300.ms).slideY(begin: 0.05),
            
            const SizedBox(height: 24),

            // ─── DATA TABLE WRAPPER ───
            Container(
              width: double.infinity, 
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 2))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  
                  if (provider.isLoading)
                    _buildShimmerTable()
                  else if (provider.transactions.isEmpty)
                    _buildEmptyState('No transactions found.', 'Adjust your dates or service filters.', Icons.receipt_long)
                  else
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.grey.shade200),
                      child: DataTable(
                        columnSpacing: isDesktop ? 20 : 10, 
                        horizontalMargin: 16,
                        headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
                        headingTextStyle: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                        dataRowMaxHeight: 70, dataRowMinHeight: 60,
                        columns: const [
                          DataColumn(label: Text('DATE')),
                          DataColumn(label: Text('INVOICE #')),
                          DataColumn(label: Text('CUSTOMER')),
                          DataColumn(label: Text('AMOUNT')),
                          DataColumn(label: Text('APPLY GST')), 
                          DataColumn(label: Text('ACTIONS')), 
                        ],
                        rows: paginatedData.map((t) => DataRow(cells: [
                          DataCell(Text("${t.date.day.toString().padLeft(2,'0')}-${t.date.month.toString().padLeft(2,'0')}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                          DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(t.invoiceNumber, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11)))),
                          DataCell(SizedBox(width: isDesktop ? 120 : 80, child: Text(t.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis))),
                          DataCell(Text('₹${t.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green))),
                          
                          DataCell(
                            Switch(
                              value: _gstStates[t.id] ?? false,
                              activeColor: AppColors.primaryGold, activeTrackColor: AppColors.primaryBlack,
                              onChanged: (val) => setState(() => _gstStates[t.id] = val),
                            )
                          ),

                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tooltip(
                                  message: 'Download PDF',
                                  child: IconButton(
                                    icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 20),
                                    onPressed: () async {
                                      _showTopSnackbar(context, 'Downloading Invoice...', true);
                                      await provider.downloadInvoice(t, _gstStates[t.id] ?? false);
                                    },
                                  ),
                                ),
                                Tooltip(
                                  message: 'Print Invoice',
                                  child: IconButton(
                                    icon: const Icon(Icons.print, color: Colors.blue, size: 20),
                                    onPressed: () async {
                                      _showTopSnackbar(context, 'Preparing Print...', true);
                                      await provider.printInvoice(t, _gstStates[t.id] ?? false); 
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ])).toList(),
                      ),
                    ),

                  // ─── PAGINATION FOOTER ───
                  if (!provider.isLoading && provider.transactions.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (!isMobile)
                            Text('Showing ${(_currentPage - 1) * _itemsPerPage + 1} to ${((_currentPage - 1) * _itemsPerPage + provider.transactions.length)} of ${provider.totalItems} transactions', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
                          
                          Row(
                            children: [
                              // 🚀 PREVIOUS BUTTON (CALLS API)
                              OutlinedButton(
                                onPressed: _currentPage > 1 ? () {
                                  setState(() => _currentPage--);
                                  final targetBranch = isAdmin ? (_selectedBranchId ?? 'all') : (auth.currentUser?.branchId ?? '');
                                  provider.fetchRevenueData(targetBranch, search: _searchController.text, page: _currentPage);
                                } : null, 
                                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), 
                                child: const Text('Prev')
                              ),
                              const SizedBox(width: 8),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: AppColors.primaryBlack, borderRadius: BorderRadius.circular(8)), child: Text('Page $_currentPage of ${provider.totalPages == 0 ? 1 : provider.totalPages}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              const SizedBox(width: 8),
                              
                              // 🚀 NEXT BUTTON (CALLS API)
                              OutlinedButton(
                                onPressed: _currentPage < provider.totalPages ? () {
                                  setState(() => _currentPage++);
                                  final targetBranch = isAdmin ? (_selectedBranchId ?? 'all') : (auth.currentUser?.branchId ?? '');
                                  provider.fetchRevenueData(targetBranch, search: _searchController.text, page: _currentPage);
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
            ).animate().fade().slideY(begin: 0.05),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopControls(RevenueProvider provider, bool isAdmin, bool isDesktop, AuthProvider auth) {
    return Wrap(
      spacing: 16, runSpacing: 16,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Wrap(
          spacing: 16, runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (isAdmin)
              Container(
                height: 48, padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedBranchId,
                    hint: const Text("All Branches"),
                    icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primaryBlack),
                    items: [
                      const DropdownMenuItem<String>(value: 'all', child: Text('All Branches', style: TextStyle(fontWeight: FontWeight.bold))),
                      ...provider.branches.map((b) => DropdownMenuItem<String>(value: b['_id'], child: Text(b['name'], style: const TextStyle(fontWeight: FontWeight.bold))))
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() { _selectedBranchId = val; _currentPage = 1; });
                        provider.fetchRevenueData(val, search: _searchController.text, page: 1);
                      }
                    },
                  ),
                ),
              ),

            Container(
              width: isDesktop ? 300 : 200, height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged, 
                decoration: const InputDecoration(icon: Icon(Icons.search, color: Colors.grey), hintText: 'Search Invoice/Name...', border: InputBorder.none),
              ),
            ),
            
            Container(
              height: 48, width: 48,
              decoration: BoxDecoration(color: AppColors.primaryBlack, borderRadius: BorderRadius.circular(12)),
              child: IconButton(
                tooltip: 'API Date & Service Filters',
                icon: const Icon(Icons.tune, color: AppColors.primaryGold),
                onPressed: () => _showFilterDialog(context, provider, auth),
              ),
            ),
          ],
        ),
        
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () async {
            _showTopSnackbar(context, 'Excel Download Started!', true);
            await provider.exportToExcel();
          },
          icon: const Icon(Icons.table_view),
          label: const Text('EXPORT DATA', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
      ],
    );
  }

  Widget _buildMobileControls(RevenueProvider provider, bool isAdmin, AuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isAdmin) ...[
          Container(
            height: 54, padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true, 
                value: _selectedBranchId,
                hint: const Text("All Branches"),
                icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primaryBlack),
                items: [
                  const DropdownMenuItem<String>(value: 'all', child: Text('All Branches', style: TextStyle(fontWeight: FontWeight.bold))),
                  ...provider.branches.map((b) => DropdownMenuItem<String>(value: b['_id'], child: Text(b['name'], style: const TextStyle(fontWeight: FontWeight.bold))))
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() { _selectedBranchId = val; _currentPage = 1; });
                    provider.fetchRevenueData(val, search: _searchController.text, page: 1);
                  }
                },
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
                  controller: _searchController,
                  onChanged: _onSearchChanged, 
                  decoration: const InputDecoration(icon: Icon(Icons.search, color: Colors.grey), hintText: 'Search Invoice...', border: InputBorder.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 54, width: 54,
              decoration: BoxDecoration(color: AppColors.primaryBlack, borderRadius: BorderRadius.circular(12)),
              child: IconButton(icon: const Icon(Icons.tune, color: AppColors.primaryGold), onPressed: () => _showFilterDialog(context, provider, auth)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () async {
            _showTopSnackbar(context, 'Excel Download Started!', true);
            await provider.exportToExcel();
          },
          icon: const Icon(Icons.table_view),
          label: const Text('EXPORT DATA', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
      ],
    );
  }

  void _showFilterDialog(BuildContext context, RevenueProvider provider, AuthProvider auth) {
    DateTime? startDate;
    DateTime? endDate;
    final serviceController = TextEditingController();
    
    String? selectedFilterBranchId; 
    final isAdmin = auth.userRole == 'ADMIN' || auth.userRole == 'MANAGER' || auth.userRole == 'OWNER';

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
                  const Row(children: [Icon(Icons.date_range, color: AppColors.primaryGold), SizedBox(width: 12), Text('Filter Revenue', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 32),
                  
                  if (isAdmin && provider.branches.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: 'Filter by Branch (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      value: selectedFilterBranchId,
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('All Branches')),
                        ...provider.branches.map((b) => DropdownMenuItem<String>(value: b['_id'], child: Text(b['name']))).toList(),
                      ],
                      onChanged: (val) => setState(() => selectedFilterBranchId = val == 'all' ? null : val),
                    ),
                    const SizedBox(height: 16),
                  ],

                  TextField(controller: serviceController, decoration: InputDecoration(labelText: 'Service ID (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  const SizedBox(height: 16),

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16), side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(Icons.calendar_today, color: AppColors.primaryBlack),
                    label: Text(startDate == null ? 'Select Date Range' : '${startDate!.toLocal().toString().split(' ')[0]} to ${endDate!.toLocal().toString().split(' ')[0]}', style: const TextStyle(color: AppColors.primaryBlack)),
                    onPressed: () async {
                      DateTimeRange? picked = await showDateRangePicker(
                        context: context, firstDate: DateTime(2020), lastDate: DateTime.now(),
                        builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppColors.primaryBlack, onPrimary: AppColors.primaryGold)), child: child!),
                      );
                      if (picked != null) {
                        setState(() { startDate = picked.start; endDate = picked.end; });
                      }
                    },
                  ),
                  
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () {
                        Navigator.pop(context);
                        String targetBranch = isAdmin ? (_selectedBranchId ?? 'all') : (auth.currentUser?.branchId ?? '');
                        this.setState(() => _currentPage = 1);
                        provider.fetchRevenueData(targetBranch, page: 1); 
                      }, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('RESET', style: TextStyle(color: Colors.black)))),
                      const SizedBox(width: 16),
                      Expanded(child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () {
                          Navigator.pop(context);
                          
                          String targetBranch = 'all';
                          if (isAdmin) {
                            if (selectedFilterBranchId != null && selectedFilterBranchId != 'all') {
                              targetBranch = selectedFilterBranchId!;
                            } else {
                              targetBranch = _selectedBranchId ?? 'all';
                            }
                          } else {
                            targetBranch = auth.currentUser?.branchId ?? '';
                          }

                          this.setState(() => _currentPage = 1);
                          provider.fetchRevenueData(
                            targetBranch,
                            startDate: startDate?.toIso8601String(),
                            endDate: endDate?.toIso8601String(),
                            serviceId: serviceController.text.isNotEmpty ? serviceController.text : null,
                            search: _searchController.text,
                            page: 1
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

  Widget _buildShimmerTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(6, (index) => Container(
        height: 60, width: double.infinity, decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))), padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(children: [Expanded(flex: 1, child: Container(height: 16, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)))), const SizedBox(width: 24), Expanded(flex: 2, child: Container(height: 16, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)))), const SizedBox(width: 24), Expanded(flex: 2, child: Container(height: 16, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)))), const SizedBox(width: 24), Expanded(flex: 1, child: Container(height: 16, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))))]),
      )).animate(onPlay: (controller) => controller.repeat()).shimmer(duration: 1200.ms, color: Colors.white60), 
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Padding(padding: const EdgeInsets.all(80.0), child: Center(child: Column(children: [Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle), child: Icon(icon, size: 64, color: Colors.grey.shade300)), const SizedBox(height: 24), Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)), const SizedBox(height: 8), Text(subtitle, style: TextStyle(color: Colors.grey.shade500))])));
  }
}
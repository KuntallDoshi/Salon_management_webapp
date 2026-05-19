import 'package:flutter/material.dart';
import 'package:heric_webapp/core/api/api_service.dart';
import 'package:heric_webapp/shared/widget/toast_helper.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart'; // 🚀 Required for Date Formatting

import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../admin/providers/admin_provider.dart'; 
import '../models/user_model.dart'; // 🚀 Import UserModel

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  final TextEditingController _emailController = TextEditingController(); 

  bool _isProcessing = false;
  bool _isSendingResetEmail = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    
    _nameController = TextEditingController(text: auth.currentUser?.name ?? '');
    _phoneController = TextEditingController(text: auth.currentUser?.phone ?? '');
    _emailController.text = auth.currentUser?.email ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (auth.currentUser != null) {
        context.read<AdminProvider>().fetchStaffProfile(auth.currentUser!.id);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ─── SAFE DATE PARSING HELPER ───
  DateTime? _parseDateSafely(dynamic rawDate) {
    if (rawDate == null) return null;
    try {
      return DateTime.parse(rawDate.toString()).toLocal();
    } catch (e) {
      return null;
    }
  }

  // ─── TIME FORMATTER (12-hour AM/PM) ───
  String _formatTime(DateTime time) {
    final h = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final m = time.minute.toString().padLeft(2, '0');
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    return "$h:$m $ampm";
  }

  // ─── DATE FORMATTER (DD/MM/YYYY) ───
  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final admin = context.watch<AdminProvider>(); 
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isDesktop = size.width > 1000;
    return Container(
      color: const Color(0xFFF8F9FA),
      height: double.infinity,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16.0 : 40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── PAGE HEADER ───
            Row(
              children: [
               IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.primaryBlack),
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushReplacementNamed(context, '/dashboard');
                    }
                  },
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Profile', style: TextStyle(fontSize: isMobile ? 24 : 32, fontWeight: FontWeight.w800, color: AppColors.primaryBlack)),
                    Text('Manage your account and view performance.', style: TextStyle(color: Colors.grey.shade600, fontSize: isMobile ? 14 : 16)),
                  ],
                ),
              ],
            ).animate().fade().slideX(begin: -0.1),
            
            const SizedBox(height: 32),

            // ─── RESPONSIVE LAYOUT WRAPPER ───
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isDesktop ? 1000 : 600),
                child: isDesktop 
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5, 
                          child: Column(
                            children: [
                              _buildPersonalInfoCard(auth),
                              const SizedBox(height: 24),
                              _buildSecurityCard(auth),
                            ],
                          )
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 5, 
                          child: Column(
                          children: [
                            _buildFinancialsCard(auth.currentUser, admin, auth.userRole),
                            const SizedBox(height: 24),
                            _buildPerformanceCard(admin),
                            const SizedBox(height: 24),
                            _buildAttendanceCard(admin),
                          ],
                        )),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPersonalInfoCard(auth),
                        const SizedBox(height: 24),
                        _buildFinancialsCard(auth.currentUser, admin, auth.userRole),
                        const SizedBox(height: 24),
                        _buildPerformanceCard(admin),
                        const SizedBox(height: 24),
                        _buildAttendanceCard(admin),
                        const SizedBox(height: 24),
                        _buildSecurityCard(auth),
                      ],
                    ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
// 🚀 SMART FINANCIALS CARD (Adapts to Admin vs Staff)
  Widget _buildFinancialsCard(UserModel? user, AdminProvider adminProvider, String? role) {
    if (user == null) return const SizedBox();

    final bool isGlobalAdmin = role == 'ADMIN' || role == 'OWNER';

    // ─── ADMIN / OWNER VIEW (GLOBAL COMPANY LOANS) ───
    if (isGlobalAdmin) {
      // Calculate totals across all staff members
      double totalIssued = adminProvider.branchStaff.fold(0.0, (sum, staff) => sum + staff.loanPrincipal);
      double totalOutstanding = adminProvider.branchStaff.fold(0.0, (sum, staff) => sum + staff.loanRemaining);
      double totalRecovered = totalIssued - totalOutstanding;

      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))]),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [Icon(Icons.corporate_fare, color: AppColors.primaryGold), SizedBox(width: 8), Text('Network Loan Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
            const SizedBox(height: 8),
            Text('Track total staff advances and recovery across the company.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blue.withOpacity(0.1))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Issued', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('₹${totalIssued.toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primaryBlack)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.green.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green.withOpacity(0.1))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Recovered', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('₹${totalRecovered.toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.green)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.redAccent.withOpacity(0.1))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Outstanding Debt', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('₹${totalOutstanding.toStringAsFixed(0)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.redAccent)),
                ],
              ),
            ),
          ],
        ),
      ).animate().fade(delay: 250.ms).slideY(begin: 0.1);
    }

    // ─── MANAGER / STAFF VIEW (PERSONAL FINANCIALS) ───
    final double salary = user.salary;
    final double remainingAmount = user.loanRemaining;
    final int trustScore = user.trustScore;
    final List<dynamic> repayments = user.repayments;

    Color scoreColor = Colors.green;
    String scoreText = "Excellent Standing";
    if (trustScore < 500) { scoreColor = Colors.redAccent; scoreText = "Action Required"; } 
    else if (trustScore < 700) { scoreColor = Colors.orange; scoreText = "Good Standing"; }
    
    double scorePercentage = (trustScore - 300) / 600.0;
    if (scorePercentage < 0) scorePercentage = 0;
    if (scorePercentage > 1) scorePercentage = 1;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.account_balance_wallet, color: AppColors.primaryGold), SizedBox(width: 8), Text('My Financials & Trust Score', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Internal Trust Score', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$trustScore', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: scoreColor, height: 1.0)),
                          const Padding(padding: EdgeInsets.only(bottom: 6.0, left: 4.0), child: Text('/ 900', style: TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(scoreText, style: TextStyle(color: scoreColor, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('300', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          Text('${(scorePercentage * 100).toInt()}% Reliability', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const Text('900', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(value: scorePercentage, minHeight: 12, backgroundColor: Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(scoreColor)),
                      ).animate().scaleX(begin: 0.0, end: 1.0, duration: 1500.ms, curve: Curves.easeOutBack),
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.blue.withOpacity(0.1))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Base Salary', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('₹${salary.toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primaryBlack)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: remainingAmount > 0 ? Colors.redAccent.withOpacity(0.05) : Colors.green.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: remainingAmount > 0 ? Colors.redAccent.withOpacity(0.1) : Colors.green.withOpacity(0.1))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(remainingAmount > 0 ? 'Active Loan Balance' : 'Debt Free', style: TextStyle(color: remainingAmount > 0 ? Colors.redAccent : Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('₹${remainingAmount.toStringAsFixed(0)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: remainingAmount > 0 ? Colors.redAccent : Colors.green)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          if (repayments.isNotEmpty) ...[
            const SizedBox(height: 32),
            const Text('Recent Repayments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            ...repayments.reversed.take(3).map((rep) {
              final date = DateTime.parse(rep['date']).toLocal();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.green, size: 16)),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rep['note'] ?? 'Payment', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                    Text('+ ₹${rep['amount']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900)),
                  ],
                ),
              );
            }),
          ]
        ],
      ),
    ).animate().fade(delay: 250.ms).slideY(begin: 0.1);
  }
  // 🚀 DIALOG FOR "SEE ALL" REPAYMENTS
  void _showAllRepaymentsDialog(BuildContext context, List<dynamic> allRepayments) {
    final reversedRepayments = allRepayments.reversed.toList();
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 500,
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(children: [
                    Icon(Icons.history, color: Colors.blue, size: 28), 
                    SizedBox(width: 12), 
                    Text('All Repayments', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))
                  ]),
                  IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: reversedRepayments.length,
                  itemBuilder: (context, index) {
                    final rep = reversedRepayments[index];
                    final date = DateTime.parse(rep['date']).toLocal();
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200)
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(rep['note'] ?? 'Repayment', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(DateFormat('dd MMM yyyy, hh:mm a').format(date), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                          Text('+ ₹${rep['amount']}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w900, fontSize: 16)),
                        ],
                      ),
                    );
                  }
                ),
              )
            ],
          ),
        ),
      )
    );
  }

  // =========================================================================
  // CARD 1: PERSONAL INFO
  // =========================================================================
  Widget _buildPersonalInfoCard(AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.primaryGold.withOpacity(0.2),
                child: Text(
                  auth.currentUser?.name.isNotEmpty == true ? auth.currentUser!.name[0].toUpperCase() : '?', 
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.primaryBlack)
                ),
              ),
              Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: AppColors.primaryBlack, shape: BoxShape.circle), child: const Icon(Icons.edit, color: AppColors.primaryGold, size: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(color: AppColors.primaryGold.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primaryGold.withOpacity(0.3))),
            child: Text((auth.userRole ?? 'STAFF').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 12, color: AppColors.primaryGold)),
          ),
          const SizedBox(height: 40),

          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: 'Full Name', prefixIcon: const Icon(Icons.person_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          ),
          const SizedBox(height: 20),
          
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: 'Phone Number', prefixText: '+91 ', prefixStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16), prefixIcon: const Icon(Icons.phone), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          ),
          const SizedBox(height: 20),

          TextField(
            controller: _emailController,
            readOnly: true,
            decoration: InputDecoration(labelText: 'Email Address (Locked)', prefixIcon: const Icon(Icons.email_outlined), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, padding: const EdgeInsets.symmetric(vertical: 20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _isProcessing ? null : () async {
                if (_nameController.text.isNotEmpty && _phoneController.text.isNotEmpty) {
                  setState(() => _isProcessing = true);
                  String? err = await auth.updateProfile(_nameController.text, _phoneController.text, ''); 
                  setState(() => _isProcessing = false);
                  
                  if (err == null) {
                      ToastHelper.show(context, 'Profile Updated Successfully!', isSuccess: true);
                  } else {
                      ToastHelper.show(context, err, isSuccess: false);
                  }
                } else {
                  ToastHelper.show(context, 'Fields cannot be empty!', isSuccess: false);
                }
              },
              child: _isProcessing 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.primaryGold, strokeWidth: 2))
                : const Text('SAVE CHANGES', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold, letterSpacing: 2))
            ),
          ),
        ],
      ),
    ).animate().fade(delay: 200.ms).slideY(begin: 0.1);
  }

  // =========================================================================
  // CARD 2: PERFORMANCE
  // =========================================================================
  Widget _buildPerformanceCard(AdminProvider admin) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.trending_up, color: Colors.blue), SizedBox(width: 8), Text('My Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
          const SizedBox(height: 20),
          
          if (admin.isProfileLoading)
            const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: AppColors.primaryGold)))
          else 
            Row(
              children: [
                Expanded(child: _buildStatBox('Jobs Done', '${admin.selectedStaffVisits.length}', Icons.content_cut, Colors.blue)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatBox('Total Revenue', '₹${admin.selectedStaffTotalRevenue.toStringAsFixed(0)}', Icons.currency_rupee, Colors.green)),
              ],
            ),
        ],
      ),
    ).animate().fade(delay: 300.ms).slideY(begin: 0.1);
  }

  Widget _buildStatBox(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }

  // =========================================================================
  // CARD 3: ATTENDANCE
  // =========================================================================
  Widget _buildAttendanceCard(AdminProvider admin) {
    final now = DateTime.now();
    
    // Filter only TODAY'S logs
    List<dynamic> todaysLogs = admin.selectedStaffLogs.where((log) {
      DateTime? clockIn = _parseDateSafely(log['clockInTime'] ?? log['createdAt']);
      if (clockIn == null) return false;
      return clockIn.year == now.year && clockIn.month == now.month && clockIn.day == now.day;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(children: [Icon(Icons.access_time_filled, color: Colors.orange), SizedBox(width: 8), Text('Today\'s Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
              TextButton(
                onPressed: admin.isProfileLoading ? null : () => _showAttendanceHistoryDialog(context, admin.selectedStaffLogs), 
                child: const Text('See History', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))
              )
            ],
          ),
          const SizedBox(height: 16),
          
          if (admin.isProfileLoading)
            const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: AppColors.primaryGold)))
          else if (todaysLogs.isEmpty)
            Container(
              width: double.infinity, padding: const EdgeInsets.all(24), 
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)), 
              child: const Text('You haven\'t clocked in today yet.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))
            )
          else 
            ListView.separated(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              itemCount: todaysLogs.length, 
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return _buildLogTile(todaysLogs[index]);
              },
            ),
        ],
      ),
    ).animate().fade(delay: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildLogTile(dynamic log) {
    DateTime? clockIn = _parseDateSafely(log['clockInTime'] ?? log['createdAt']);
    DateTime? clockOut = _parseDateSafely(log['clockOutTime']);

    String clockInStr = clockIn != null ? _formatTime(clockIn) : "Unknown";
    String clockOutStr = clockOut != null ? _formatTime(clockOut) : "Active";
    
    String durationStr = "";
    if (clockIn != null && clockOut != null) {
      Duration diff = clockOut.difference(clockIn);
      int hours = diff.inHours;
      int mins = diff.inMinutes.remainder(60);
      durationStr = " (${hours}h ${mins}m)";
    }

    bool isWorking = clockOut == null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: isWorking ? Colors.green.withOpacity(0.1) : Colors.grey.shade100, shape: BoxShape.circle), 
        child: Icon(isWorking ? Icons.work : Icons.check, color: isWorking ? Colors.green : Colors.grey, size: 20)
      ),
      title: Text('In: $clockInStr', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: durationStr.isNotEmpty ? Text(durationStr, style: const TextStyle(fontSize: 12, color: Colors.blue)) : null,
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: isWorking ? Colors.green.withOpacity(0.1) : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
        child: Text(isWorking ? 'Working...' : 'Out: $clockOutStr', style: TextStyle(color: isWorking ? Colors.green : Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 12))
      ),
    );
  }

  void _showAttendanceHistoryDialog(BuildContext context, List<dynamic> allLogs) {
    Map<String, List<dynamic>> groupedLogs = {};
    for (var log in allLogs) {
      DateTime? clockIn = _parseDateSafely(log['clockInTime'] ?? log['createdAt']);
      if (clockIn != null) {
        String dateKey = _formatDate(clockIn);
        if (!groupedLogs.containsKey(dateKey)) {
          groupedLogs[dateKey] = [];
        }
        groupedLogs[dateKey]!.add(log);
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        final dialogWidth = MediaQuery.sizeOf(dialogContext).width > 600 ? 500.0 : MediaQuery.sizeOf(dialogContext).width * 0.9;
        
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: dialogWidth,
            height: MediaQuery.sizeOf(dialogContext).height * 0.8,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(children: [
                      Icon(Icons.history, color: Colors.blue, size: 28), 
                      SizedBox(width: 12), 
                      Text('Attendance History', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))
                    ]),
                    IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(dialogContext)),
                  ],
                ),
                const SizedBox(height: 16),
                
                Expanded(
                  child: groupedLogs.isEmpty
                    ? const Center(child: Text("No attendance history available.", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: groupedLogs.keys.length,
                        itemBuilder: (context, index) {
                          String dateKey = groupedLogs.keys.elementAt(index);
                          List<dynamic> dailyLogs = groupedLogs[dateKey]!;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                                    border: Border(bottom: BorderSide(color: Colors.grey.shade200))
                                  ),
                                  child: Text(dateKey, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlack)),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Column(
                                    children: dailyLogs.map((log) => _buildLogTile(log)).toList(),
                                  ),
                                )
                              ],
                            ),
                          );
                        },
                      ),
                )
              ],
            ),
          ),
        );
      }
    );
  }

  // =========================================================================
  // CARD 4: SECURITY (PASSWORD RESET)
  // =========================================================================
  Widget _buildSecurityCard(AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.red.shade100), boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.security, color: Colors.redAccent), SizedBox(width: 8), Text('Security', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
          const SizedBox(height: 8),
          const Text('Send a secure link to your email to reset your password.', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 20),
          
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: BorderSide(color: Colors.red.shade200), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              icon: _isSendingResetEmail 
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2))
                  : const Icon(Icons.lock_reset, color: Colors.red),
              label: Text(_isSendingResetEmail ? 'SENDING EMAIL...' : 'RESET PASSWORD', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onPressed: _isSendingResetEmail ? null : () async {
                setState(() => _isSendingResetEmail = true);
                String? err = await ApiService().sendPasswordResetOTP(auth.currentUser!.email);
                setState(() => _isSendingResetEmail = false);

                if (err == null) {
                  ToastHelper.show(context, 'Check your email for the OTP!', isSuccess: true);
                  if (context.mounted) _showOTPValidationDialog(context); 
                } else {
                  ToastHelper.show(context, 'Failed: $err', isSuccess: false);
                }
              },
            ),
          ),
        ],
      ),
    ).animate().fade(delay: 500.ms).slideY(begin: 0.1);
  }

  void _showOTPValidationDialog(BuildContext context) {
    final otpController = TextEditingController();
    final newPasswordController = TextEditingController();
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: 400, padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.mark_email_read, color: AppColors.primaryGold, size: 28), SizedBox(width: 12), Text('Verify OTP', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))]),
                const SizedBox(height: 8),
                const Text('Enter the code sent to your email and choose a new password.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 24),
                
                TextField(controller: otpController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: '6-Digit OTP', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 16),
                TextField(controller: newPasswordController, obscureText: true, decoration: InputDecoration(labelText: 'New Password', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 32),
                
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: isProcessing ? null : () => Navigator.pop(context), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('CANCEL', style: TextStyle(color: Colors.black)))),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlack, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: isProcessing ? null : () async {
                          if (otpController.text.isNotEmpty && newPasswordController.text.isNotEmpty) {
                            setState(() => isProcessing = true);
                            String? err = await ApiService().resetPasswordWithOTP(otpController.text, newPasswordController.text);
                            
                            if (context.mounted) {
                              if (err == null) {
                                Navigator.pop(context); 
                                ToastHelper.show(context, 'Password changed successfully!', isSuccess: true);
                              } else {
                                setState(() => isProcessing = false);
                                ToastHelper.show(context, err, isSuccess: false);
                              }
                            }
                          } else {
                            ToastHelper.show(context, 'Please fill all fields', isSuccess: false);
                          }
                        },
                        child: isProcessing ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.primaryGold, strokeWidth: 2)) : const Text('CONFIRM', style: TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold))
                      )
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      })
    );
  }
}
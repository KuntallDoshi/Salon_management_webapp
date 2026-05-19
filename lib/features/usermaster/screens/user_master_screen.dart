import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/user_master_provider.dart';

class UserMasterScreen extends StatelessWidget {
  const UserMasterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserMasterProvider>();
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Container(
      color: const Color(0xFFF8F9FA),
      child: SingleChildScrollView(
        // FIXED: Mobile padding
        padding: EdgeInsets.all(isDesktop ? 40.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FIXED: Responsive header
            if (isDesktop)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _buildHeaderContent(context, provider),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ..._buildHeaderContent(context, provider),
                ],
              ),

            SizedBox(height: isDesktop ? 48 : 24),

            // FIXED: Mobile-friendly Staff Table
            Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 15,
                        offset: const Offset(0, 5))
                  ]),
              child: Column(
                children: [
                  if (isDesktop)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      decoration: const BoxDecoration(
                          color: AppColors.primaryBlack,
                          borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16))),
                      child: Row(
                        children: [
                          Expanded(
                              flex: 2,
                              child: Text('STAFF DETAILS',
                                  style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1))),
                          Expanded(
                              flex: 3,
                              child: Text('ACCESSIBLE SCREENS',
                                  style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1))),
                          const SizedBox(width: 80),
                        ],
                      ),
                    ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: provider.staffUsers.length,
                    separatorBuilder: (context, index) =>
                        Divider(color: Colors.grey.shade100, height: 1),
                    itemBuilder: (context, index) {
                      final user = provider.staffUsers[index];
                      return isDesktop
                          ? _buildDesktopRow(user, provider)
                          : _buildMobileRow(user, provider);
                    },
                  ),
                ],
              ),
            ).animate().fade(delay: 600.ms).slideY(begin: 0.1),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildHeaderContent(
      BuildContext context, UserMasterProvider provider) {
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Staff Access & Logins',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryBlack))
              .animate()
              .fade(duration: 500.ms)
              .slideX(begin: -0.1),
          const SizedBox(height: 8),
          Text('Create credentials and manage screen permissions.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16))
              .animate()
              .fade(delay: 200.ms)
              .slideX(begin: -0.1),
        ],
      ),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGold,
            foregroundColor: AppColors.primaryBlack,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
        onPressed: () => _showAddStaffDialog(context, provider),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('CREATE LOGIN',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      ).animate().fade(delay: 400.ms).slideY(begin: -0.2),
    ];
  }

  Widget _buildDesktopRow(StaffUser user, UserMasterProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primaryBlack)),
                Text('${user.role} • ${user.email}',
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: user.accessibleRoutes
                  .map((route) => _buildPermissionTag(route))
                  .toList(),
            ),
          ),
          SizedBox(
            width: 80,
            child: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => provider.removeStaffUser(user.id)),
          ),
        ],
      ),
    );
  }

  // FIXED: Explicit Mobile Layout for Staff Row
  Widget _buildMobileRow(StaffUser user, UserMasterProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Text(user.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.primaryBlack))),
              IconButton(
                  icon:
                      const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => provider.removeStaffUser(user.id)),
            ],
          ),
          Text('${user.role} • ${user.email}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: user.accessibleRoutes
                .map((route) => _buildPermissionTag(route))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTag(String route) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: AppColors.primaryGold.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primaryGold.withOpacity(0.3))),
      child: Text(route.replaceAll('/', '').toUpperCase(),
          style: const TextStyle(
              color: AppColors.primaryBlack,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5)),
    );
  }

  void _showAddStaffDialog(BuildContext context, UserMasterProvider provider) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final roleController = TextEditingController();
    Map<String, bool> screenAccess = {
      '/dashboard': false,
      '/inventory': false,
      '/visitors': false,
      '/revenue': false
    };

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        final isDesktop = MediaQuery.of(context).size.width > 600;

        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Container(
            // FIXED: Responsive constraints to fit small phones
            width: MediaQuery.of(context).size.width * 0.95,
            constraints: const BoxConstraints(maxWidth: 550),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Create Staff Login',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // FIXED: Fields stack on mobile!
                  Flex(
                    direction: isDesktop ? Axis.horizontal : Axis.vertical,
                    children: [
                      Expanded(
                          flex: isDesktop ? 1 : 0,
                          child: TextField(
                              controller: nameController,
                              decoration: InputDecoration(
                                  labelText: 'Full Name',
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(10))))),
                      if (isDesktop)
                        const SizedBox(width: 16)
                      else
                        const SizedBox(height: 16),
                      Expanded(
                          flex: isDesktop ? 1 : 0,
                          child: TextField(
                              controller: roleController,
                              decoration: InputDecoration(
                                  labelText: 'Role (e.g., Stylist)',
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(10))))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                          labelText: 'Email Address (Login ID)',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 16),
                  TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                          labelText: 'Temporary Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)))),

                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Divider()),

                  const Text('Assign Screen Access',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Toggle the switches to grant this user access.',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),

                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: screenAccess.keys.map((route) {
                      bool hasAccess = screenAccess[route]!;
                      return InkWell(
                        onTap: () =>
                            setState(() => screenAccess[route] = !hasAccess),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          // FIXED: Toggles take full width on phones, 220px on desktop
                          width: isDesktop ? 220 : double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: hasAccess
                                  ? AppColors.primaryGold.withOpacity(0.1)
                                  : Colors.grey.shade50,
                              border: Border.all(
                                  color: hasAccess
                                      ? AppColors.primaryGold
                                      : Colors.grey.shade300,
                                  width: 2),
                              borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(route.replaceAll('/', '').toUpperCase(),
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: hasAccess
                                          ? AppColors.primaryBlack
                                          : Colors.grey.shade600)),
                              Icon(
                                  hasAccess
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  color: hasAccess
                                      ? AppColors.primaryBlack
                                      : Colors.grey.shade400),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlack,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          onPressed: () {
                            if (nameController.text.isNotEmpty &&
                                emailController.text.isNotEmpty) {
                              List<String> allowedRoutes = screenAccess.entries
                                  .where((e) => e.value)
                                  .map((e) => e.key)
                                  .toList();
                              provider.addStaffUser(
                                  nameController.text,
                                  emailController.text,
                                  passwordController.text,
                                  roleController.text,
                                  allowedRoutes);
                              Navigator.pop(context);
                            }
                          },
                          child: const Text('SAVE CREDENTIALS',
                              style: TextStyle(
                                  color: AppColors.primaryGold,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2)))),
                ],
              ),
            ),
          ),
        )
            .animate()
            .fade(duration: 300.ms)
            .scale(curve: Curves.easeOutBack, begin: const Offset(0.9, 0.9));
      }),
    );
  }
}

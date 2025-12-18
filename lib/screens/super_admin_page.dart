import 'package:attendance_system/components/pages/admins_page.dart';
import 'package:flutter/material.dart';
import '../components/sidebars/admin_sidebar.dart';
import '../components/admin_stats_grid.dart';
import 'login_screen.dart';
import 'package:attendance_system/components/pages/faculties_page.dart';
import 'package:attendance_system/components/pages/lecturer_page.dart';
import 'package:attendance_system/components/pages/Admin_user_handling_page.dart';
import 'package:attendance_system/components/popup/logout_confirmation_popup.dart';
import 'package:attendance_system/components/charts/bar_chart.dart';
import 'package:attendance_system/components/charts/pie_chart.dart';

// ---- Logout confirmation popup matching your design ----
// Use reusable popup from components/popup/logout_confirmation_popup.dart

class SuperAdminPage extends StatefulWidget {
  const SuperAdminPage({super.key});

  @override
  State<SuperAdminPage> createState() => _SuperAdminPageState();
}

class _SuperAdminPageState extends State<SuperAdminPage> {
  int _selectedIndex = 0;
  bool _collapsed = true;

  final List<Widget> _pages = [
    Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            "Dashboard",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: const [
                  AdminDashboardStatsGrid(),
                  SizedBox(height: 24),
                  _ChartsSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    FacultiesPage(),
    TeachersPage(),
    AdminsPage(),
    UserHandlingPage(),
  ];

  // --- This method now shows the confirmation popup before logging out ---
  void _logout(BuildContext context) async {
    try {
      final confirmed = await showLogoutConfirmationPopup(context);
      if (confirmed == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      print("Logout failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final sidebarColor = const Color(0xFF3B4B9B);

    return Scaffold(
      appBar: isMobile
          ? AppBar(
              title: const Text('Admin Panel'),
              backgroundColor: Colors.indigo.shade100,
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Logout',
                  onPressed: () => _logout(context),
                ),
              ],
            )
          : null,
      drawer: isMobile
          ? Drawer(
              child: AdminSidebar(
                selectedIndex: _selectedIndex,
                onItemSelected: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                  Navigator.pop(context);
                },
                collapsed: false,
              ),
            )
          : null,
      body: Stack(
        children: [
          Row(
            children: [
              if (!isMobile)
                Container(
                  color: sidebarColor,
                  child: Column(
                    children: [
                      if (_collapsed)
                        Container(
                          color: sidebarColor,
                          width: 60,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Align(
                              alignment: Alignment.center,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.menu,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _collapsed = false;
                                  });
                                },
                                tooltip: 'Expand menu',
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                      if (!_collapsed || _collapsed)
                        Expanded(
                          child: AdminSidebar(
                            selectedIndex: _selectedIndex,
                            onItemSelected: (index) {
                              setState(() {
                                _selectedIndex = index;
                                _collapsed = true;
                              });
                            },
                            collapsed: _collapsed,
                          ),
                        ),
                    ],
                  ),
                ),
              if (!isMobile) const VerticalDivider(thickness: 1, width: 1),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    if (!_collapsed) {
                      setState(() {
                        _collapsed = true;
                      });
                    }
                  },
                  child: _pages[_selectedIndex],
                ),
              ),
            ],
          ),
          // --- Logout Button in Top Right for desktop/tablet ---
          if (!isMobile)
            Positioned(
              top: 16,
              right: 24,
              child: IconButton(
                icon: const Icon(Icons.logout, color: Colors.black87),
                tooltip: 'Logout',
                onPressed: () => _logout(context),
              ),
            ),
        ],
      ),
    );
  }
}

// --- Charts section for Super Admin dashboard ---
class _ChartsSection extends StatelessWidget {
  const _ChartsSection();

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool stackCharts = width < 1000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stackCharts) ...[
          const _Card(
            title: 'Qaybinta ardayda (qeybo %)',
            height: 240,
            child: UsersPieChart(),
          ),
          const SizedBox(height: 16),
          const _Card(
            title: 'Students per Department',
            height: 240,
            child: StudentsPerDepartmentBarChart(),
          ),
        
        ] else ...[
          Row(
            children: const [
              Expanded(
                child: _Card(
                  title: 'Qaybinta ardayda (qeybo %)',
                  height: 240,
                  child: UsersPieChart(),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _Card(
                  title: 'Students per Department',
                  height: 240,
                  child: StudentsPerDepartmentBarChart(),
                ),
              ),
            ],
          ),
 
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  final double? height;

  const _Card({required this.title, required this.child, this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SizedBox(height: height ?? 240, child: child),
        ],
      ),
    );
  }
}

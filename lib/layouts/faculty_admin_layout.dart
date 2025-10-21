import 'package:flutter/material.dart';
import '../components/sidebars/faculty_admin_sidebar.dart';
import '../components/popup/logout_confirmation_popup.dart';
import '../screens/login_screen.dart';
import '../components/faculty_dashboard_stats_grid.dart';

class FacultyAdminLayout extends StatefulWidget {
  final List<Widget>? customPages;
  final String displayName;
  const FacultyAdminLayout({
    super.key,
    this.customPages,
    this.displayName = '',
  });

  @override
  State<FacultyAdminLayout> createState() => _FacultyAdminLayoutState();
}

class _FacultyAdminLayoutState extends State<FacultyAdminLayout> {
  int _selectedIndex = 0;
  bool _collapsed = true;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages =
        widget.customPages ??
        [
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Dashboard',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 32),
                Expanded(child: DashboardStatsGrid()),
              ],
            ),
          ),
          Center(child: Text('Departments')),
          Center(child: Text('Students')),
          Center(child: Text('Subjects')),
          Center(child: Text('Classes')),
          Center(child: Text('Attendance')),
          Center(child: Text('TimeTable')),
          Center(child: Text('User Handling')),
        ];
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final sidebarColor = const Color(0xFF3B4B9B);

    return Scaffold(
      appBar: isMobile
          ? AppBar(
              title: const Text('Faculty Admin Panel'),
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
                  onPressed: () async {
                    try {
                      final shouldLogout = await showLogoutConfirmationPopup(
                        context,
                      );
                      if (shouldLogout == true) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      }
                    } catch (e) {
                      print("Logout failed: $e");
                    }
                  },
                ),
              ],
            )
          : null,
      drawer: isMobile
          ? Drawer(
              child: FacultyAdminSidebar(
                selectedIndex: _selectedIndex,
                onItemSelected: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                  Navigator.pop(context);
                },
                collapsed: false,
                adminName: widget.displayName,
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
                          child: FacultyAdminSidebar(
                            selectedIndex: _selectedIndex,
                            onItemSelected: (index) {
                              setState(() {
                                _selectedIndex = index;
                                _collapsed = true;
                              });
                            },
                            collapsed: _collapsed,
                            adminName: widget.displayName,
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
                onPressed: () async {
                  try {
                    final shouldLogout = await showLogoutConfirmationPopup(
                      context,
                    );
                    if (shouldLogout == true) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    }
                  } catch (e) {
                    print("Logout failed: $e");
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

// Use reusable popup from components/popup/logout_confirmation_popup.dart

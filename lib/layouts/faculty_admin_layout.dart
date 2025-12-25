import 'package:flutter/material.dart';
import '../components/sidebars/faculty_admin_sidebar.dart';
import '../components/popup/logout_confirmation_popup.dart';
import '../screens/login_screen.dart';
import '../components/faculty_dashboard_stats_grid.dart';
import '../theme/super_admin_theme.dart';
import '../services/theme_controller.dart';

class FacultyAdminLayout extends StatefulWidget {
  final List<Widget>? customPages;
  const FacultyAdminLayout({super.key, this.customPages});

  @override
  State<FacultyAdminLayout> createState() => _FacultyAdminLayoutState();
}

class _FacultyAdminLayoutState extends State<FacultyAdminLayout> {
  int _selectedIndex = 0;
  bool _collapsed = true;

  List<Widget> _buildDefaultPages(Color headerColor) {
    return [
      Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Dashboard',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: headerColor,
              ),
            ),
            const SizedBox(height: 32),
            Expanded(child: DashboardStatsGrid()),
          ],
        ),
      ),
      const Center(child: Text('Departments')),
      const Center(child: Text('Classes')),
      const Center(child: Text('Students')),
      const Center(child: Text('Courses')),
      const Center(child: Text('Attendance')),
      const Center(child: Text('TimeTable')),
      const Center(child: Text('User Handling')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = Theme.of(context).extension<SuperAdminColors>();
    final sidebarColor =
        palette?.sidebarColor ??
        (isDark ? const Color(0xFF0E1A60) : const Color(0xFF3B4B9B));
    final headerColor = palette?.textPrimary ?? Colors.black87;
    final scaffoldBg = palette?.scaffold;
    final pages = widget.customPages ?? _buildDefaultPages(headerColor);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: isMobile
          ? AppBar(
              title: const Text('Faculty Admin Panel'),
              backgroundColor: palette?.surface ?? Colors.indigo.shade100,
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                  tooltip: isDark
                      ? 'Switch to light mode'
                      : 'Switch to dark mode',
                  onPressed: () {
                    final next = isDark ? ThemeMode.light : ThemeMode.dark;
                    ThemeController.setThemeMode(next);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Logout',
                  onPressed: () async {
                    try {
                      final shouldLogout = await showLogoutConfirmationPopup(
                        context,
                      );
                      if (shouldLogout == true) {
                        // Reset theme to light mode on logout
                        ThemeController.setThemeMode(ThemeMode.light);
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
                  child: pages[_selectedIndex],
                ),
              ),
            ],
          ),
          // --- Logout Button in Top Right for desktop/tablet ---
          if (!isMobile)
            Positioned(
              top: 16,
              right: 24,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                    tooltip: isDark
                        ? 'Switch to light mode'
                        : 'Switch to dark mode',
                    onPressed: () {
                      final next = isDark ? ThemeMode.light : ThemeMode.dark;
                      ThemeController.setThemeMode(next);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: 'Logout',
                    onPressed: () async {
                      try {
                        final shouldLogout = await showLogoutConfirmationPopup(
                          context,
                        );
                        if (shouldLogout == true) {
                          // Reset theme to light mode on logout
                          ThemeController.setThemeMode(ThemeMode.light);
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
              ),
            ),
        ],
      ),
    );
  }
}

// Use reusable popup from components/popup/logout_confirmation_popup.dart

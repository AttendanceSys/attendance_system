import 'package:flutter/material.dart';
import '../components/sidebars/faculty_admin_sidebar.dart';
import '../components/popup/logout_confirmation_popup.dart';
import '../components/pages/admin_anomalies_page.dart';
import '../components/pages/admin_profile_page.dart';
import '../screens/login_screen.dart';
import '../components/faculty_dashboard_stats_grid.dart';
import '../theme/super_admin_theme.dart';
import '../services/theme_controller.dart';
import '../services/session.dart';
import 'package:google_fonts/google_fonts.dart';

class FacultyAdminLayout extends StatefulWidget {
  final List<Widget>? customPages;
  const FacultyAdminLayout({super.key, this.customPages});

  @override
  State<FacultyAdminLayout> createState() => _FacultyAdminLayoutState();
}

class _FacultyAdminLayoutState extends State<FacultyAdminLayout> {
  int _selectedIndex = 0;

  List<Widget> _buildDefaultPages(Color headerColor) {
    return [
      Padding(
        padding: const EdgeInsets.all(11.0),
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
            const SizedBox(height: 48),
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
      // Faculty "Anomalies" page at index 8
      const AdminAnomaliesPage(),
      // Profile page at index 9
      const AdminProfilePage(roleFilter: 'admin', roleLabel: 'Faculty Admin'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = Theme.of(context).extension<SuperAdminColors>();
    final headerColor = palette?.textPrimary ?? Colors.black87;
    final scaffoldBg = palette?.scaffold;
    final pages = widget.customPages ?? _buildDefaultPages(headerColor);
    final displayName =
        (Session.name != null && Session.name!.trim().isNotEmpty)
        ? Session.name!.trim()
        : (Session.username != null && Session.username!.trim().isNotEmpty)
        ? Session.username!.trim()
        : 'Admin';

    Widget themeToggle({Color? color}) {
      final iconColor = color ?? (isDark ? Colors.white : Colors.black87);
      final bgColor = isDark ? const Color(0xFF2E3545) : Colors.white;
      return Container(
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(
            isDark ? Icons.light_mode : Icons.dark_mode,
            color: iconColor,
          ),
          tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          onPressed: () {
            final next = isDark ? ThemeMode.light : ThemeMode.dark;
            ThemeController.setThemeMode(next);
          },
        ),
      );
    }

    Widget profileName() {
      final textColor = isDark
          ? const Color(0xFF3BAA7A)
          : const Color(0xFF7A4CE0);
      final avatarBg = isDark
          ? const Color(0xFF4234A4)
          : const Color(0xFF8372FE);
      final initial = displayName.isNotEmpty
          ? displayName[0].toUpperCase()
          : 'A';
      return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _selectedIndex = 9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: avatarBg,
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.playfairDisplay(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final safeIndex = (_selectedIndex >= 0 && _selectedIndex < pages.length)
        ? _selectedIndex
        : 0;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: isMobile
          ? AppBar(
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
              titleSpacing: 0,
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              actions: [
                themeToggle(),
                const SizedBox(width: 8),
                profileName(),
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Logout',
                  onPressed: () async {
                    try {
                      final shouldLogout = await showLogoutConfirmationPopup(
                        context,
                      );
                      if (shouldLogout == true) {
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
                enableHoverExpand: false,
                forceExpanded: true,
              ),
            )
          : null,
      body: Stack(
        children: [
          Row(
            children: [
              if (!isMobile)
                Column(
                  children: [
                    Expanded(
                      child: FacultyAdminSidebar(
                        selectedIndex: _selectedIndex,
                        onItemSelected: (index) {
                          setState(() {
                            _selectedIndex = index;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              if (!isMobile) const VerticalDivider(thickness: 1, width: 1),
              Expanded(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: pages[safeIndex],
                ),
              ),
            ],
          ),
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
                  const SizedBox(width: 8),
                  profileName(),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: 'Logout',
                    onPressed: () async {
                      try {
                        final shouldLogout = await showLogoutConfirmationPopup(
                          context,
                        );
                        if (shouldLogout == true) {
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

//super admin page

import 'package:attendance_system/components/pages/admins_page.dart';
import 'package:flutter/material.dart';
import '../components/sidebars/admin_sidebar.dart';
import '../components/admin_stats_grid.dart';
import 'login_screen.dart';
import 'package:attendance_system/components/pages/faculties_page.dart';
import 'package:attendance_system/components/pages/lecturer_page.dart';
import 'package:attendance_system/components/pages/Admin_user_handling_page.dart';
import 'package:attendance_system/components/popup/logout_confirmation_popup.dart';
import '../services/theme_controller.dart';
import '../theme/super_admin_theme.dart';
// Removed global theme controller usage to keep dark mode local to Super Admin

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
  // Removed local dark mode state and logic. Use global ThemeController only.

  ThemeData _superAdminDarkTheme(ThemeData base) {
    const scaffold = Color(0xFF1F2431);
    const surface = Color(0xFF262C3A);
    const surfaceHigh = Color(0xFF323746);
    const inputFill = Color(0xFF2B303D);
    const border = Color(0xFF3A404E);
    const textPrimary = Color(0xFFE6EAF1);
    const textSecondary = Color(0xFF9EA5B5);
    const icon = Color(0xFFE6EAF1);
    const accent = Color(0xFF0A1E90);
    const overlay = Color(0x1AFFFFFF);

    return base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: scaffold,
      canvasColor: scaffold,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        surface: surface,
        primary: accent,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      extensions: <ThemeExtension<dynamic>>[SuperAdminColors.dark()],
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      iconTheme: IconThemeData(color: icon),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        hintStyle: TextStyle(color: textSecondary),
        labelStyle: TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: border),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: border),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white70),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all<Color>(accent),
          foregroundColor: WidgetStateProperty.all<Color>(Colors.white),
          overlayColor: WidgetStateProperty.all<Color>(overlay),
          shape: WidgetStateProperty.all(
            const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(surfaceHigh),
        dataRowColor: WidgetStateProperty.all(scaffold),
        headingTextStyle: const TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        dataTextStyle: const TextStyle(color: textPrimary),
        dividerThickness: 0.8,
        headingRowHeight: 48,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surfaceHigh,
        contentTextStyle: TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  final List<Widget> _pages = [
    Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            "Dashboard",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: null,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(child: AdminDashboardStatsGrid()),
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
    final baseTheme = Theme.of(context);
    final isDark =
        ThemeController.themeMode.value ==
        ThemeMode.dark; // use global theme controller
    final isMobile = MediaQuery.of(context).size.width < 600;
    final sidebarColor = isDark
        ? const Color(0xFF0E1A60)
        : const Color(0xFF3B4B9B);

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
            ThemeController.setThemeMode(
              isDark ? ThemeMode.light : ThemeMode.dark,
            );
          },
        ),
      );
    }

    final scaffold = Scaffold(
      appBar: isMobile
          ? AppBar(
              title: const Text('Admin Panel'),
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              actions: [
                // Let icon color be determined by local dark flag or theme after wrapping
                themeToggle(),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  themeToggle(),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: 'Logout',
                    onPressed: () => _logout(context),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    if (isDark) {
      return Theme(data: _superAdminDarkTheme(baseTheme), child: scaffold);
    }
    return scaffold;
  }
}

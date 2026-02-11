//super admin page

import 'package:attendance_system/components/pages/admins_page.dart';
import 'package:flutter/material.dart';
import '../components/sidebars/admin_sidebar.dart';
import '../components/admin_stats_grid.dart';
import 'login_screen.dart';
import 'package:attendance_system/components/pages/faculties_page.dart';
import 'package:attendance_system/components/pages/lecturer_page.dart';
import 'package:attendance_system/components/pages/Admin_user_handling_page.dart';
import 'package:attendance_system/components/pages/admin_profile_page.dart';
import 'package:attendance_system/components/popup/logout_confirmation_popup.dart';
import '../services/theme_controller.dart';
import '../services/session.dart';
import '../theme/super_admin_theme.dart';
import 'package:google_fonts/google_fonts.dart';
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
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textPrimary,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
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
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      // Keep dashboard clear of the floating top-right controls.
      padding: const EdgeInsets.fromLTRB(32.0, 44.0, 32.0, 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
    const AdminProfilePage(
      roleFilter: 'Super admin',
      roleLabel: 'Super Admin',
    ),
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
            ThemeController.setThemeMode(
              isDark ? ThemeMode.light : ThemeMode.dark,
            );
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
        onTap: () => setState(() => _selectedIndex = 5),
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
                  style: TextStyle(
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

    final scaffold = Scaffold(
      appBar: isMobile
          ? AppBar(
              title: const Text('Admin Panel'),
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              actions: [
                // Let icon color be determined by local dark flag or theme after wrapping
                themeToggle(),
                const SizedBox(width: 8),
                profileName(),
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
                      child: AdminSidebar(
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
              Expanded(child: _pages[_selectedIndex]),
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
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: profileName(),
                  ),
                  const SizedBox(width: 8),
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

import 'package:flutter/material.dart';
import '../components/sidebars/teacher_sidebar.dart';
import '../components/pages/teacher_qr_generation_page.dart';
import '../components/pages/teacher_attendance_page.dart';
import '../components/popup/logout_confirmation_popup.dart'; // <-- reusable popup
import 'login_screen.dart';
import '../services/theme_controller.dart';
import '../theme/teacher_theme.dart';

class TeacherMainPage extends StatefulWidget {
  const TeacherMainPage({super.key});

  @override
  State<TeacherMainPage> createState() => _TeacherMainPageState();
}

class _TeacherMainPageState extends State<TeacherMainPage> {
  int selectedIndex = 0;
  bool collapsed = true;
  // Removed local dark mode state, use global ThemeController

  final List<Widget> pages = const [
    TeacherQRGenerationPage(),
    TeacherAttendancePage(),
  ];

  void onSidebarItemSelected(int index) {
    setState(() {
      selectedIndex = index;
      collapsed = true; // collapse sidebar after selection (desktop behavior)
    });
  }

  void onCollapseToggle() {
    setState(() {
      collapsed = !collapsed;
    });
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showLogoutConfirmationPopup(context);
    if (confirmed == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sidebarColor = isDark
        ? const Color(0xFF0E1A60)
        : const Color(0xFF3B4B9B);

    Widget themeSwitchButton({Color? color}) {
      return Builder(
        builder: (context) {
          final palette = Theme.of(context).extension<TeacherThemeColors>();
          return ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.themeMode,
            builder: (context, mode, _) {
              final isDark = mode == ThemeMode.dark;
              final icon = isDark ? Icons.light_mode : Icons.dark_mode;
              final tooltip = isDark
                  ? 'Switch to light mode'
                  : 'Switch to dark mode';
              final iconColor = isDark
                  ? Colors.white
                  : (color ?? palette?.iconColor ?? Colors.black87);
              return IconButton(
                icon: Icon(icon, color: iconColor),
                tooltip: tooltip,
                onPressed: () {
                  ThemeController.setThemeMode(
                    isDark ? ThemeMode.light : ThemeMode.dark,
                  );
                },
              );
            },
          );
        },
      );
    }

    final scaffold = Scaffold(
      appBar: isMobile
          ? AppBar(
              title: const Text('Teacher Panel'),
              backgroundColor: Colors.indigo.shade100,
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              actions: [
                Builder(
                  builder: (context) {
                    final palette = Theme.of(
                      context,
                    ).extension<TeacherThemeColors>();
                    final iconColor = palette?.iconColor ?? Colors.black87;
                    return Row(
                      children: [
                        themeSwitchButton(color: iconColor),
                        ValueListenableBuilder<ThemeMode>(
                          valueListenable: ThemeController.themeMode,
                          builder: (context, mode, _) {
                            final isDark = mode == ThemeMode.dark;
                            final logoutIconColor = isDark
                                ? Colors.white
                                : iconColor;
                            return IconButton(
                              icon: Icon(Icons.logout, color: logoutIconColor),
                              tooltip: 'Logout',
                              onPressed: () => _logout(context),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ],
            )
          : null,
      drawer: isMobile
          ? Drawer(
              child: TeacherSidebar(
                selectedIndex: selectedIndex,
                onItemSelected: (index) {
                  setState(() {
                    selectedIndex = index;
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
                  width: collapsed ? 60 : 220,
                  child: Column(
                    children: [
                      if (collapsed)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Align(
                            alignment: Alignment.center,
                            child: IconButton(
                              icon: const Icon(Icons.menu, color: Colors.white),
                              onPressed: onCollapseToggle,
                              tooltip: 'Expand menu',
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      Expanded(
                        child: TeacherSidebar(
                          selectedIndex: selectedIndex,
                          onItemSelected: onSidebarItemSelected,
                          collapsed: collapsed,
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
                    // If the sidebar is expanded (collapsed == false), collapse it when
                    // the user taps the main content / blank area.
                    if (!collapsed) {
                      setState(() {
                        collapsed = true;
                      });
                    }
                  },
                  child: pages[selectedIndex],
                ),
              ),
            ],
          ),
          // Desktop/Tablet theme switch and logout button
          if (!isMobile)
            Positioned(
              top: 16,
              right: 24,
              child: Builder(
                builder: (context) {
                  final palette = Theme.of(
                    context,
                  ).extension<TeacherThemeColors>();
                  final iconColor = palette?.iconColor ?? Colors.black87;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      themeSwitchButton(color: iconColor),
                      ValueListenableBuilder<ThemeMode>(
                        valueListenable: ThemeController.themeMode,
                        builder: (context, mode, _) {
                          final isDark = mode == ThemeMode.dark;
                          final logoutIconColor = isDark
                              ? Colors.white
                              : iconColor;
                          return IconButton(
                            icon: Icon(Icons.logout, color: logoutIconColor),
                            tooltip: 'Logout',
                            onPressed: () => _logout(context),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );

    // Use only global ThemeController for theme
    return scaffold;
  }
}

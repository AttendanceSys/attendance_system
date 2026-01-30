import 'package:flutter/material.dart';
import '../components/sidebars/teacher_sidebar.dart';
import '../services/theme_controller.dart';
import '../components/popup/logout_confirmation_popup.dart';
import '../screens/login_screen.dart';

class TeacherLayout extends StatefulWidget {
  const TeacherLayout({super.key});

  @override
  State<TeacherLayout> createState() => _TeacherLayoutState();
}

class _TeacherLayoutState extends State<TeacherLayout> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    Center(child: Text('QR Generation')),
    Center(child: Text('Attendance')),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final sidebarColor = const Color(0xFF3B4B9B);

    return Scaffold(
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
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeController.themeMode,
                  builder: (context, mode, _) {
                    final isDark = mode == ThemeMode.dark;
                    return IconButton(
                      icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                      tooltip: isDark
                          ? 'Switch to light mode'
                          : 'Switch to dark mode',
                      onPressed: () {
                        final next = isDark ? ThemeMode.light : ThemeMode.dark;
                        ThemeController.setThemeMode(next);
                      },
                    );
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
              child: TeacherSidebar(
                selectedIndex: _selectedIndex,
                onItemSelected: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                  Navigator.pop(context);
                },
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
                  child: TeacherSidebar(
                    selectedIndex: _selectedIndex,
                    onItemSelected: (index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                  ),
                ),
              if (!isMobile) const VerticalDivider(thickness: 1, width: 1),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {},
                  child: _pages[_selectedIndex],
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
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: ThemeController.themeMode,
                    builder: (context, mode, _) {
                      final isDark = mode == ThemeMode.dark;
                      return IconButton(
                        icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                        tooltip: isDark
                            ? 'Switch to light mode'
                            : 'Switch to dark mode',
                        onPressed: () {
                          final next = isDark
                              ? ThemeMode.light
                              : ThemeMode.dark;
                          ThemeController.setThemeMode(next);
                        },
                      );
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

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../components/sidebars/teacher_sidebar.dart';
import '../components/pages/teacher_qr_generation_page.dart';
import '../components/pages/teacher_attendance_page.dart';
import '../components/popup/logout_confirmation_popup.dart'; // <-- reusable popup
import 'login_screen.dart';
import '../services/theme_controller.dart';
import '../services/session.dart';
import '../theme/teacher_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class TeacherMainPage extends StatefulWidget {
  const TeacherMainPage({super.key});

  @override
  State<TeacherMainPage> createState() => _TeacherMainPageState();
}

class _TeacherMainPageState extends State<TeacherMainPage> {
  int selectedIndex = 0;
  // Removed local dark mode state, use global ThemeController
  String _displayName = 'Teacher';

  final List<Widget> pages = const [
    TeacherQRGenerationPage(),
    TeacherAttendancePage(),
  ];

  @override
  void initState() {
    super.initState();
    _displayName = (Session.name != null && Session.name!.trim().isNotEmpty)
        ? Session.name!.trim()
        : (Session.username != null && Session.username!.trim().isNotEmpty)
        ? Session.username!.trim()
        : 'Teacher';

    if ((Session.name == null || Session.name!.trim().isEmpty) &&
        Session.username != null &&
        Session.username!.trim().isNotEmpty) {
      _loadTeacherName();
    }
  }

  Future<void> _loadTeacherName() async {
    try {
      final username = Session.username?.trim();
      if (username == null || username.isEmpty) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('teachers')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      String? resolved;
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final value =
            (data['teacher_name'] ?? data['name'] ?? data['display_name']);
        if (value is String && value.trim().isNotEmpty) {
          resolved = value.trim();
        }
      }

      resolved ??= username;

      if (!mounted) return;
      setState(() => _displayName = resolved!);
      Session.name = resolved;
    } catch (_) {
      // ignore errors
    }
  }

  void onSidebarItemSelected(int index) {
    setState(() {
      selectedIndex = index;
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

    Widget themeToggle({Color? color}) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
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
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final textColor = isDark ? Colors.white : const Color(0xFF7A4CE0);
      final avatarBg = isDark
          ? const Color(0xFF4234A4)
          : const Color(0xFF8372FE);
      final displayName = _displayName.trim().isNotEmpty
          ? _displayName.trim()
          : 'Teacher';
      final initial = displayName.isNotEmpty
          ? displayName[0].toUpperCase()
          : 'T';

      return Row(
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
      );
    }

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
              backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
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
                  onPressed: () => _logout(context),
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
                      child: TeacherSidebar(
                        selectedIndex: selectedIndex,
                        onItemSelected: onSidebarItemSelected,
                      ),
                    ),
                  ],
                ),
              if (!isMobile) const VerticalDivider(thickness: 1, width: 1),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {},
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
                      const SizedBox(width: 8),
                      profileName(),
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

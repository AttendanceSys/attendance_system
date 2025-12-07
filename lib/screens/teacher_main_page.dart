import 'package:flutter/material.dart';
import '../components/sidebars/teacher_sidebar.dart';
import '../components/pages/teacher_qr_generation_page.dart';
import '../components/pages/teacher_attendance_page.dart';
import '../components/popup/logout_confirmation_popup.dart'; // <-- reusable popup
import 'login_screen.dart';

class TeacherMainPage extends StatefulWidget {
  final String displayName;
  const TeacherMainPage({super.key, this.displayName = ''});

  @override
  State<TeacherMainPage> createState() => _TeacherMainPageState();
}

class _TeacherMainPageState extends State<TeacherMainPage> {
  int selectedIndex = 0;
  bool collapsed = true;

  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
    pages = [
      TeacherQRGenerationPage(displayName: widget.displayName),
      const TeacherAttendancePage(),
    ];
  }

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
                collapsed: false,
                teacherName: widget.displayName,
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
                          teacherName: widget.displayName,
                        ),
                      ),
                    ],
                  ),
                ),
              if (!isMobile) const VerticalDivider(thickness: 1, width: 1),
              Expanded(child: pages[selectedIndex]),
            ],
          ),
          // Desktop/Tablet logout button
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

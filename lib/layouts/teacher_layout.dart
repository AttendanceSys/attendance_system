import 'package:flutter/material.dart';
import '../components/sidebars/teacher_sidebar.dart';

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
      body: Row(
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
    );
  }
}

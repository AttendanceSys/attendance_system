import 'package:flutter/material.dart';
import '../components/sidebars/teacher_sidebar.dart';

class TeacherLayout extends StatefulWidget {
  const TeacherLayout({super.key});

  @override
  State<TeacherLayout> createState() => _TeacherLayoutState();
}

class _TeacherLayoutState extends State<TeacherLayout> {
  int _selectedIndex = 0;
  bool _collapsed = true;

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
                collapsed: false,
              ),
            )
          : null,
      body: Row(
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
                            icon: const Icon(Icons.menu, color: Colors.white),
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
                      child: TeacherSidebar(
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
    );
  }
}

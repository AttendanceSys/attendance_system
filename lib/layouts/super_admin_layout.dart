import 'package:flutter/material.dart';
import '../components/sidebars/admin_sidebar.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  bool _collapsed = true; // Start collapsed

  final List<Widget> _pages = const [
    Center(child: Text('Dashboard Page')),
    Center(child: Text('fucalties Page')),
    Center(child: Text('Teachers Page')),
    Center(child: Text('Admins Page')),
    Center(child: Text('User Handling Page')),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final sidebarColor = const Color(0xFF3B4B9B);

    return Scaffold(
      appBar: isMobile
          ? AppBar(
              title: const Text('Admin Panel'),
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
              child: AdminSidebar(
                selectedIndex: _selectedIndex,
                onItemSelected: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                  Navigator.pop(context);
                },
                collapsed: false,
                adminName: '',
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
                  // Only show menu icon when collapsed
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
                  // Sidebar
                  if (!_collapsed || _collapsed)
                    Expanded(
                      child: AdminSidebar(
                        selectedIndex: _selectedIndex,
                        onItemSelected: (index) {
                          setState(() {
                            _selectedIndex = index;
                            _collapsed = true; // Auto-collapse after selection
                          });
                        },
                        collapsed: _collapsed,
                        adminName: '',
                      ),
                    ),
                ],
              ),
            ),
          if (!isMobile) const VerticalDivider(thickness: 1, width: 1),
          // Main content with tap-to-collapse
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

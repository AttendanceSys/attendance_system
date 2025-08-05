import 'package:flutter/material.dart';
import 'components/admin_sidebar.dart';
import 'screens/departScreen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  final List<String> _titles = [
    'Dashboard',
    'Faculties',
    'Teachers',
    'Admins',
    'User Handling',
  ];

  final List<Widget> _pages = const [
    Center(child: Text('Dashboard Page')),
    Center(child: Text('Faculties Page')),
    Center(child: Text('Teachers Page')),
    Center(child: Text('Admins Page')),
    Center(child: Text('User Handling Page')),
  ];

  final List<IconData> _icons = [
    Icons.dashboard_outlined,
    Icons.account_tree_outlined,
    Icons.person_pin_outlined,
    Icons.group_outlined,
    Icons.manage_accounts,
  ];

  Widget buildMenuList({required bool isMobile}) {
    return Column(
      children: [
        ...List.generate(_titles.length, (index) {
          return ListTile(
            leading: Icon(_icons[index], color: Colors.white),
            title: Text(
              _titles[index],
              style: const TextStyle(color: Colors.white),
            ),
            selected: _selectedIndex == index,
            selectedTileColor: Colors.indigo,
            onTap: () {
              setState(() {
                _selectedIndex = index;
                if (isMobile) Navigator.pop(context);
              });
            },
          );
        }),
        const Divider(color: Colors.white24),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.white),
          title: const Text('Logout', style: TextStyle(color: Colors.white)),
          onTap: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Logout pressed')));
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: isMobile
          ? AppBar(
              title: Text(_titles[_selectedIndex]),
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
              child: Container(
                color: Colors.indigo.shade700,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    DrawerHeader(
                      decoration: BoxDecoration(color: Colors.indigo.shade700),
                      child: Column(
                        children: [
                          Center(
                            child: Text(
                              'Admin User',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.indigo.shade400,
                            child: const Text(
                              'A',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    buildMenuList(isMobile: true),
                  ],
                ),
              ),
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            Container(
              width: 220,
              color: Colors.indigo.shade700,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: Text(
                        'Admin User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.indigo.shade400,
                      child: const Text(
                        'A',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24, thickness: 1),
                  Expanded(child: buildMenuList(isMobile: false)),
                ],
              ),
            ),
          if (!isMobile) const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: Column(
              children: [
                if (!isMobile)
                  AppBar(
                    title: Text(_titles[_selectedIndex]),
                    backgroundColor: Colors.indigo.shade100,
                  ),
                Expanded(child: _pages[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

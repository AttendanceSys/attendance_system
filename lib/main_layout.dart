import 'package:flutter/material.dart';

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

  // Use icons that closely match the image (outlined, thin, and relevant)
  final List<IconData> _icons = [
    Icons.home_outlined, // Dashboard
    Icons.account_tree_outlined, // Faculties
    Icons
        .cast_for_education_outlined, // Teachers (or use Icons.school_outlined)
    Icons.groups_outlined, // Admins
    Icons.person_outline, // User Handling
  ];

  Widget buildSidebarContent({required bool isMobile}) {
    return Column(
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
        ...List.generate(_titles.length, (index) {
          final isSelected = _selectedIndex == index;
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: isSelected
                ? BoxDecoration(
                    color: const Color(0xFF4E589A),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: ListTile(
              leading: Icon(_icons[index], color: Colors.white, size: 28),
              title: Text(
                _titles[index],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 2,
              ),
              selected: isSelected,
              selectedTileColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onTap: () {
                setState(() {
                  _selectedIndex = index;
                  if (isMobile) Navigator.pop(context);
                });
              },
            ),
          );
        }),
        const Divider(color: Colors.white24),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.white, size: 28),
          title: const Text(
            'Logout',
            style: TextStyle(color: Colors.white, fontSize: 17),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 2,
          ),
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
                color: const Color(0xFF3B438D),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [buildSidebarContent(isMobile: true)],
                ),
              ),
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            Container(
              width: 220,
              color: const Color(0xFF3B438D),
              child: buildSidebarContent(isMobile: false),
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

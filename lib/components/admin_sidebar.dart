import 'package:flutter/material.dart';

class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final String userName;
  final String userInitial;

  final List<_SidebarItem> _items = const [
    _SidebarItem('Dashboard', Icons.dashboard_outlined),
    _SidebarItem('Faculties', Icons.account_tree_outlined),
    _SidebarItem('Teachers', Icons.person_pin_outlined),
    _SidebarItem('Admins', Icons.group_outlined),
    _SidebarItem('User Handling', Icons.manage_accounts),
  ];

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.userName = 'Admin User',
    this.userInitial = 'A',
  });

  Widget _buildSidebar(BuildContext context) {
    return Container(
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
                userName,
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
              child: Text(
                userInitial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, thickness: 1),
          ...List.generate(_items.length, (index) {
            final item = _items[index];
            final isSelected = selectedIndex == index;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Material(
                color: isSelected ? Colors.indigo : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onDestinationSelected(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    child: Row(
                      children: [
                        Icon(item.icon, color: isSelected ? Colors.white : Colors.white70),
                        const SizedBox(width: 12),
                        Text(
                          item.title,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logout pressed')),
                );
              },
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text('Logout', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade400,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Responsive: show Drawer on small screens, sidebar on large screens
    final isMobile = MediaQuery.of(context).size.width < 600;
    if (isMobile) {
      return Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.indigo.shade700),
              child: Column(
                children: [
                  Text(
                    userName,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.indigo.shade400,
                    child: Text(
                      userInitial,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            ...List.generate(_items.length, (index) {
              final item = _items[index];
              return ListTile(
                leading: Icon(item.icon, color: Colors.indigo),
                title: Text(item.title),
                selected: selectedIndex == index,
                onTap: () => onDestinationSelected(index),
              );
            }),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.indigo),
              title: const Text('Logout'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logout pressed')),
                );
              },
            ),
          ],
        ),
      );
    } else {
      return _buildSidebar(context);
    }
  }
}

class _SidebarItem {
  final String title;
  final IconData icon;
  const _SidebarItem(this.title, this.icon);
}
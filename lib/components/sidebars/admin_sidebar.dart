import 'package:flutter/material.dart';

class AdminSidebar extends StatelessWidget {
  final Function(int) onItemSelected;
  final int selectedIndex;
  final bool collapsed;

  const AdminSidebar({
    Key? key,
    required this.onItemSelected,
    required this.selectedIndex,
    this.collapsed = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: collapsed ? 60 : 220,
      color: const Color(0xFF3B4B9B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 30),
          if (!collapsed)
            const Text(
              "Xasan Cali",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (!collapsed) const SizedBox(height: 10),
          CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xFF70C2FF),
            child: Text(
              "X",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SidebarItem(
            icon: Icons.home_outlined,
            title: "Dashboard",
            isSelected: selectedIndex == 0,
            onTap: () => onItemSelected(0),
            collapsed: collapsed,
          ),
          SidebarItem(
            icon: Icons.account_tree_outlined,
            title: "Faculties",
            isSelected: selectedIndex == 1,
            onTap: () => onItemSelected(1),
            collapsed: collapsed,
          ),
          SidebarItem(
            icon: Icons.school_outlined,
            title: "Teachers",
            isSelected: selectedIndex == 2,
            onTap: () => onItemSelected(2),
            collapsed: collapsed,
          ),
          SidebarItem(
            icon: Icons.groups_outlined,
            title: "Admins",
            isSelected: selectedIndex == 3,
            onTap: () => onItemSelected(3),
            collapsed: collapsed,
          ),
          SidebarItem(
            icon: Icons.person,
            title: "User Handling",
            isSelected: selectedIndex == 4,
            onTap: () => onItemSelected(4),
            collapsed: collapsed,
          ),
        ],
      ),
    );
  }
}

class SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final bool collapsed;

  const SidebarItem({
    Key? key,
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.collapsed = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 0 : 24,
            vertical: 12,
          ),
          child: Row(
            mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
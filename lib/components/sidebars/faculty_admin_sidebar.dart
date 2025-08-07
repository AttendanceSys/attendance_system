import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class FacultyAdminSidebar extends StatelessWidget {
  final Function(int) onItemSelected;
  final int selectedIndex;
  final bool collapsed;

  const FacultyAdminSidebar({
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
          const SizedBox(height: 24),
          if (!collapsed)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                "Axmed Faarax",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  overflow: TextOverflow.ellipsis,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          if (!collapsed) const SizedBox(height: 10),
          CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xFF70C2FF),
            child: const Text(
              "A",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _SidebarItem(
                  icon: Icons.home_outlined,
                  title: "Dashboard",
                  isSelected: selectedIndex == 0,
                  onTap: () => onItemSelected(0),
                  collapsed: collapsed,
                ),
                _SidebarItem(
                  icon: LucideIcons.settings,
                  title: "Departments",
                  isSelected: selectedIndex == 1,
                  onTap: () => onItemSelected(1),
                  collapsed: collapsed,
                ),
                _SidebarItem(
                  icon: LucideIcons.user2,
                  title: "Students",
                  isSelected: selectedIndex == 2,
                  onTap: () => onItemSelected(2),
                  collapsed: collapsed,
                ),
                _SidebarItem(
                  icon: LucideIcons.bookOpen,
                  title: "Subjects",
                  isSelected: selectedIndex == 3,
                  onTap: () => onItemSelected(3),
                  collapsed: collapsed,
                ),
                _SidebarItem(
                  icon: LucideIcons.users2,
                  title: "Classes",
                  isSelected: selectedIndex == 4,
                  onTap: () => onItemSelected(4),
                  collapsed: collapsed,
                ),
                _SidebarItem(
                  icon: LucideIcons.clipboardList,
                  title: "Attendance",
                  isSelected: selectedIndex == 5,
                  onTap: () => onItemSelected(5),
                  collapsed: collapsed,
                ),
                _SidebarItem(
                  icon: LucideIcons.calendarDays,
                  title: "TimeTable",
                  isSelected: selectedIndex == 6,
                  onTap: () => onItemSelected(6),
                  collapsed: collapsed,
                ),
                _SidebarItem(
                  icon: Icons.person,
                  title: "User Handling",
                  isSelected: selectedIndex == 7,
                  onTap: () => onItemSelected(7),
                  collapsed: collapsed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final bool collapsed;

  const _SidebarItem({
    Key? key,
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
    required this.collapsed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? const Color(0x33FFFFFF) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 0 : 16,
            vertical: 12,
          ),
          child: Row(
            mainAxisAlignment:
                collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
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

import 'package:flutter/material.dart';

class TeacherSidebar extends StatelessWidget {
  final Function(int) onItemSelected;
  final int selectedIndex;
  final bool collapsed;

  const TeacherSidebar({
    Key? key,
    required this.onItemSelected,
    required this.selectedIndex,
    this.collapsed = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String name = 'Dr Adam';
    return Container(
      width: collapsed ? 60 : 220,
      color: const Color(0xFF3B4B9B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          // Profile Section
          CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xFF70C2FF),
            child: Text(
              name.trim().isNotEmpty ? name.trim()[0] : '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (!collapsed) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  overflow: TextOverflow.ellipsis,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                _SidebarItem(
                  icon: Icons.qr_code_2,
                  title: "QR Generation",
                  isSelected: selectedIndex == 0,
                  onTap: () => onItemSelected(0),
                  collapsed: collapsed,
                ),
                _SidebarItem(
                  icon: Icons.calendar_month_outlined,
                  title: "Attendance",
                  isSelected: selectedIndex == 1,
                  onTap: () => onItemSelected(1),
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
    final Color selectedBg = Colors.white.withOpacity(0.13);
    final Color selectedText = Colors.white;
    final Color unselectedText = Colors.white;
    final Color selectedIcon = Colors.white;
    final Color unselectedIcon = Colors.white;
    return Material(
      color: isSelected ? selectedBg : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      elevation: isSelected ? 2 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 0 : 16,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isSelected ? selectedBg : Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: collapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isSelected ? selectedIcon : unselectedIcon,
                size: 24,
              ),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? selectedText : unselectedText,
                    fontSize: 16,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
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

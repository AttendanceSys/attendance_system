import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/session.dart';

class AdminSidebar extends StatefulWidget {
  final Function(int) onItemSelected;
  final int selectedIndex;
  final bool collapsed;

  const AdminSidebar({
    super.key,
    required this.onItemSelected,
    required this.selectedIndex,
    this.collapsed = false,
  });

  @override
  State<AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<AdminSidebar> {
  String? displayName;

  @override
  void initState() {
    super.initState();
    displayName = Session.name;
    if ((displayName == null || displayName!.isEmpty) &&
        Session.username != null &&
        Session.username!.isNotEmpty) {
      _loadDisplayName();
    }
  }

  Future<void> _loadDisplayName() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('admins')
          .where('username', isEqualTo: Session.username)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final name =
            (data['name'] ??
                    data['full_name'] ??
                    data['display_name'] ??
                    Session.username)
                as String;
        if (mounted) {
          setState(() {
            displayName = name;
          });
        }
        Session.name = name;
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = widget.collapsed;
    final selectedIndex = widget.selectedIndex;
    final onItemSelected = widget.onItemSelected;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = Theme.of(context).extension<SuperAdminColors>();
    final sidebarColor =
        palette?.sidebarColor ??
        (isDark ? const Color(0xFF0E1A60) : const Color(0xFF3B4B9B));

    return Container(
      width: collapsed ? 60 : 220,
      color: sidebarColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          // Profile Section
          CircleAvatar(
            radius: collapsed ? 22 : 42,
            backgroundColor: const Color(0xFF70C2FF),
            child: Text(
              (displayName != null && displayName!.isNotEmpty)
                  ? displayName![0].toUpperCase()
                  : 'U',
              style: TextStyle(
                color: Colors.white,
                fontSize: collapsed ? 18 : 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 14),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                displayName ?? 'User',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  overflow: TextOverflow.ellipsis,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          const SizedBox(height: 20),
          // Sidebar Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
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
                  title: "Lecturers",
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
    super.key,
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.collapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = Theme.of(context).extension<SuperAdminColors>();
    final Color selectedBg =
        (palette?.selectedBg ??
        (isDark
            ? Colors.white.withOpacity(0.13)
            : Colors.white.withOpacity(0.25)));
    final Color selectedText = Colors.white;
    final Color unselectedText = Colors.white;
    final Color selectedIcon = Colors.white;
    final Color unselectedIcon = Colors.white;

    final overlay = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.hovered)) {
        return palette?.hoverOverlay ??
            (isDark
                ? Colors.white.withOpacity(0.10)
                : Colors.white.withOpacity(0.20));
      }
      if (states.contains(WidgetState.pressed)) {
        return palette?.pressedOverlay ??
            (isDark
                ? Colors.white.withOpacity(0.16)
                : Colors.white.withOpacity(0.28));
      }
      return null;
    });
    return Tooltip(
      message: collapsed ? title : "",
      verticalOffset: 0,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 300),
      child: Material(
        color: isSelected ? selectedBg : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        elevation: isSelected ? 2 : 0,
        child: InkWell(
          overlayColor: overlay,
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
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/session.dart';

class TeacherSidebar extends StatefulWidget {
  final Function(int) onItemSelected;
  final int selectedIndex;
  final bool collapsed; // parent-controlled collapsed state
  final String teacherName; // optional fallback

  const TeacherSidebar({
    super.key,
    required this.onItemSelected,
    required this.selectedIndex,
    this.collapsed = false,
    this.teacherName = "",
  });

  @override
  State<TeacherSidebar> createState() => _TeacherSidebarState();
}

class _TeacherSidebarState extends State<TeacherSidebar> {
  String? displayName;

  @override
  void initState() {
    super.initState();
    displayName = widget.teacherName.isNotEmpty
        ? widget.teacherName
        : Session.name;
    if ((displayName == null || displayName!.isEmpty) &&
        Session.username != null &&
        Session.username!.isNotEmpty) {
      _loadDisplayName();
    }
  }

  Future<void> _loadDisplayName() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('teachers')
          .where('username', isEqualTo: Session.username)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        final name =
            (data['teacher_name'] ?? data['name'] ?? Session.username)
                as String;
        if (mounted) setState(() => displayName = name);
        Session.name = name;
        return;
      }

      // Fallback to users collection
      final q2 = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: Session.username)
          .limit(1)
          .get();
      if (q2.docs.isNotEmpty) {
        final d = q2.docs.first.data();
        final name =
            (d['name'] ?? d['display_name'] ?? Session.username) as String;
        if (mounted) setState(() => displayName = name);
        Session.name = name;
      }
    } catch (_) {
      // ignore errors
    }
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = widget.collapsed;
    final selectedIndex = widget.selectedIndex;
    final onItemSelected = widget.onItemSelected;

    return Container(
      width: collapsed ? 60 : 220,
      color: const Color(0xFF3B4B9B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 24),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                displayName ?? 'Teacher',
                style: const TextStyle(
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
            child: Text(
              (displayName != null && displayName!.isNotEmpty)
                  ? displayName![0].toUpperCase()
                  : 'T',
              style: const TextStyle(
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
              shrinkWrap: true,
              children: [
                SidebarItem(
                  icon: Icons.qr_code_2,
                  title: "QR Generation",
                  isSelected: selectedIndex == 0,
                  onTap: () => onItemSelected(0),
                  collapsed: collapsed,
                ),
                SidebarItem(
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
    final Color selectedBg = Colors.white.withOpacity(0.13);
    final Color selectedText = Colors.white;
    final Color unselectedText = Colors.white;
    final Color selectedIcon = Colors.white;
    final Color unselectedIcon = Colors.white;
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

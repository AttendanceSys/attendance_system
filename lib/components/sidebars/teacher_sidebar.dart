import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TeacherSidebar extends StatefulWidget {
  final Function(int) onItemSelected;
  final int selectedIndex;
  final bool enableHoverExpand;
  final bool forceExpanded;

  const TeacherSidebar({
    super.key,
    required this.onItemSelected,
    required this.selectedIndex,
    this.enableHoverExpand = true,
    this.forceExpanded = false,
  });

  @override
  State<TeacherSidebar> createState() => _TeacherSidebarState();
}

class _TeacherSidebarState extends State<TeacherSidebar> {
  bool isCollapsed = true;

  @override
  Widget build(BuildContext context) {
    final collapsed = widget.forceExpanded ? false : isCollapsed;
    final selectedIndex = widget.selectedIndex;
    final onItemSelected = widget.onItemSelected;

    const sidebarWidthExpanded = 270.0;
    const sidebarWidthCollapsed = 90.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sidebarBg = isDark
        ? const Color.fromARGB(255, 11, 16, 29)
        : const Color(0xFF3E54A0);
    const borderColor = Color(0xFF1F2937);
    final inactiveIcon = isDark
        ? const Color.fromARGB(255, 255, 255, 255)
        : const Color.fromARGB(255, 255, 255, 255);
    final activeBg = isDark ? const Color(0xFF4234A4) : const Color(0xFF8372FE);
    const selectedIcon = Colors.white;

    final sidebar = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: collapsed ? sidebarWidthCollapsed : sidebarWidthExpanded,
      decoration: BoxDecoration(
        color: sidebarBg,
        border: const Border(right: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Image.asset(
                  'assets/lightLogo.png',
                  height: 40,
                  fit: BoxFit.contain,
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'QScan',
                            style: GoogleFonts.playfairDisplay(
                              fontWeight: FontWeight.w600,
                              fontSize: 25,
                              color: const Color.fromARGB(255, 255, 255, 255),
                            ),
                          ),
                          TextSpan(
                            text: ' Smart',
                            style: GoogleFonts.playfairDisplay(
                              fontWeight: FontWeight.w600,
                              fontSize: 25,
                              color: const Color.fromARGB(255, 255, 255, 255),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _SidebarItem(
                  icon: Icons.qr_code_rounded,
                  title: "QR Generation",
                  isSelected: selectedIndex == 0,
                  onTap: () => onItemSelected(0),
                  collapsed: collapsed,
                  inactiveIcon: inactiveIcon,
                  activeBg: activeBg,
                  selectedIcon: selectedIcon,
                ),
                _SidebarItem(
                  icon: Icons.fact_check_rounded,
                  title: "Attendance",
                  isSelected: selectedIndex == 1,
                  onTap: () => onItemSelected(1),
                  collapsed: collapsed,
                  inactiveIcon: inactiveIcon,
                  activeBg: activeBg,
                  selectedIcon: selectedIcon,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );

    if (widget.forceExpanded || !widget.enableHoverExpand) {
      return sidebar;
    }

    return MouseRegion(
      onEnter: (_) {
        if (isCollapsed) setState(() => isCollapsed = false);
      },
      onExit: (_) {
        if (!isCollapsed) setState(() => isCollapsed = true);
      },
      child: sidebar,
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final bool collapsed;
  final Color inactiveIcon;
  final Color activeBg;
  final Color selectedIcon;

  const _SidebarItem({
    required this.icon,
    required this.title,
    required this.isSelected,
    required this.onTap,
    required this.collapsed,
    required this.inactiveIcon,
    required this.activeBg,
    required this.selectedIcon,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: collapsed ? null : double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isSelected ? activeBg : Colors.transparent,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // During the AnimatedContainer width transition, the sidebar may still be narrow
              // while `collapsed` is already false. Only show the spacer/label once there's room.
              const iconWidth = 25.0;
              const labelSpacing = 12.0;
              final canShowLabel =
                  !collapsed &&
                  constraints.maxWidth >= (iconWidth + labelSpacing);

              return Row(
                mainAxisSize: collapsed ? MainAxisSize.min : MainAxisSize.max,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? selectedIcon : inactiveIcon,
                    size: 25,
                  ),
                  if (canShowLabel) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected ? Colors.white : inactiveIcon,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );

    final item = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: onTap,
        child: content,
      ),
    );

    if (!collapsed) {
      return item;
    }

    return Tooltip(
      message: title,
      verticalOffset: 0,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 200),
      child: item,
    );
  }
}

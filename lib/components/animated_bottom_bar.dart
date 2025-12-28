import 'package:flutter/material.dart';
import 'student_theme_controller.dart';

typedef OnBarTap = void Function(int index);

class AnimatedBottomBar extends StatefulWidget {
  final int currentIndex;
  final OnBarTap onTap;
  final double lift; // pixels
  final Duration duration;

  const AnimatedBottomBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    this.lift = 30.0,
    this.duration = const Duration(milliseconds: 180),
  }) : super(key: key);

  @override
  State<AnimatedBottomBar> createState() => _AnimatedBottomBarState();
}

class _AnimatedBottomBarState extends State<AnimatedBottomBar> {
  @override
  Widget build(BuildContext context) {
    final theme = StudentThemeController.instance.theme;
    final items = [
      {'icon': Icons.menu_book, 'label': 'View Attendance'},
      {'icon': Icons.qr_code_scanner, 'label': 'Scan Attendance'},
      {'icon': Icons.person, 'label': 'Profile'},
    ];

    return SafeArea(
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.only(bottom: 6, top: 6),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Container(
              margin: EdgeInsets.only(top: widget.lift),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: theme.card,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadow,
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(items.length, (i) {
                  // center item is represented but we will still show label
                  final item = items[i];
                  final active = widget.currentIndex == i;
                  return _BarItem(
                    icon: item['icon'] as IconData,
                    label: item['label'] as String,
                    active: active,
                    lift: widget.lift,
                    duration: widget.duration,
                    onTap: () => widget.onTap(i),
                    theme: theme,
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final double lift;
  final Duration duration;
  final VoidCallback onTap;
  final dynamic theme;

  const _BarItem({
    Key? key,
    required this.icon,
    required this.label,
    required this.active,
    required this.lift,
    required this.duration,
    required this.onTap,
    required this.theme,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = active ? theme.button : theme.hint;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, active ? -lift : 0, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: active ? 28 : 22),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.hint, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'student_theme_controller.dart';

typedef OnBarTap = void Function(int index);

class AnimatedBottomBar extends StatefulWidget {
  final int currentIndex;
  final OnBarTap onTap;
  final double lift; // pixels
  final Duration duration;
  final double activeSize;

  const AnimatedBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.lift = 30.0,
    this.duration = const Duration(milliseconds: 180),
    this.activeSize = 70.0,
  });

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
        padding: const EdgeInsets.only(bottom: 6, top: 2),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              margin: EdgeInsets.only(top: widget.lift * 0.45),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: theme.card,
                border: Border(
                  top: BorderSide(color: theme.border),
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadow,
                    blurRadius: 14,
                    offset: const Offset(0, -6),
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
                    activeSize: widget.activeSize,
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
  final double activeSize;
  final VoidCallback onTap;
  final dynamic theme;

  const _BarItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.lift,
    required this.duration,
    required this.activeSize,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? theme.button : theme.hint;
    final activeIconColor = Colors.white;
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
              AnimatedContainer(
                duration: duration,
                width: active ? activeSize : 26,
                height: active ? activeSize : 26,
                decoration: BoxDecoration(
                  color: active ? theme.button : Colors.transparent,
                  shape: active ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: active ? null : BorderRadius.circular(8),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: theme.button.withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : const [],
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: active ? activeIconColor : color,
                  size: active ? 30 : 24,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedOpacity(
                opacity: active ? 0.0 : 1.0,
                duration: duration,
                curve: Curves.easeOut,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.hint, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

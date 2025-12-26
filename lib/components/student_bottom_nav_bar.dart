import 'package:flutter/material.dart';
import 'student_theme.dart';
import 'student_theme_controller.dart';

class StudentBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const StudentBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = StudentThemeController.instance.brightness;
    final Color navBgColor = StudentTheme.background(brightness);
    final Color navBorderColor = StudentTheme.border(brightness);

    final List<Map<String, dynamic>> items = [
      {'icon': Icons.article_outlined, 'label': 'View Attendance'},
      {'icon': Icons.crop_free_rounded, 'label': 'Scan Attendance'},
      {'icon': Icons.person_outline_rounded, 'label': 'Profile'},
    ];

    return AnimatedBuilder(
      animation: StudentThemeController.instance,
      builder: (context, _) {
        final brightness = StudentThemeController.instance.brightness;
        final Color navBgColor = StudentTheme.background(brightness);
        final Color navBorderColor = StudentTheme.border(brightness);
        return Container(
          height: 100,
          decoration: BoxDecoration(
            color: navBgColor,
            border: Border(top: BorderSide(color: navBorderColor, width: 1)),
          ),
          child: Row(
            children: List.generate(items.length, (index) {
              final bool isSelected = currentIndex == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        width: isSelected ? 54 : 30,
                        height: isSelected ? 54 : 30,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? StudentTheme.primaryPurple
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          items[index]['icon'],
                          size: isSelected ? 30 : 26,
                          color: isSelected
                              ? StudentTheme.icon(brightness, selected: true)
                              : (brightness == Brightness.dark
                                    ? Colors.white
                                    : StudentTheme.icon(
                                        brightness,
                                        selected: false,
                                      )),
                        ),
                      ),
                      if (!isSelected) ...[
                        const SizedBox(height: 6),
                        Text(
                          items[index]['label'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: brightness == Brightness.dark
                                ? Colors.white
                                : StudentTheme.label(brightness),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

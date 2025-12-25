import 'package:flutter/material.dart';

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
    // Exact colors from your UI images
    const Color primaryPurple = Color(0xFF6C4DFF); 
    const Color unselectedGrey = Color(0xFF636E72); 
    const Color borderColor = Color(0xFFE0E0E0);

    final List<Map<String, dynamic>> items = [
      {'icon': Icons.article_outlined, 'label': 'View Attendance'},
      {'icon': Icons.crop_free_rounded, 'label': 'Scan Attendance'},
      {'icon': Icons.person_outline_rounded, 'label': 'Profile'},
    ];

    return Container(
      height: 100, // Fixed height to prevent UI jumping
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
        ),
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
                  // Animated Purple Circle Container
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    width: isSelected ? 54 : 30, // Expands when selected
                    height: isSelected ? 54 : 30,
                    decoration: BoxDecoration(
                      color: isSelected ? primaryPurple : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      items[index]['icon'],
                      size: isSelected ? 30 : 26, // Icon grows when selected
                      color: isSelected ? Colors.white : unselectedGrey,
                    ),
                  ),
                  
                  // Label logic: Hidden when selected to match images
                  if (!isSelected) ...[
                    const SizedBox(height: 6),
                    Text(
                      items[index]['label'],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: unselectedGrey,
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
  }
}
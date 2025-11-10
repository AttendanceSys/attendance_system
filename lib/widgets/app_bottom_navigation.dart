import 'package:flutter/material.dart';

enum ActiveTab { view, scan, profile }

class AppBottomNavigation extends StatelessWidget {
  final ActiveTab active;
  final VoidCallback onView;
  final VoidCallback onScan;
  final VoidCallback onProfile;

  const AppBottomNavigation({
    super.key,
    required this.active,
    required this.onView,
    required this.onScan,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    Widget floatingButton() {
      final icon = active == ActiveTab.view
          ? Icons.menu_book_rounded
          : active == ActiveTab.scan
          ? Icons.qr_code_scanner
          : Icons.person;
      return GestureDetector(
        onTap: () {
          if (active == ActiveTab.view) {
            onView();
          } else if (active == ActiveTab.scan) {
            onScan();
          } else {
            onProfile();
          }
        },
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF6A46FF),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6A46FF).withOpacity(0.28),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, size: 30, color: Colors.white),
        ),
      );
    }

    return Transform.translate(
      offset: const Offset(0, -6),
      child: SizedBox(
        height: 86,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Background bar
            Container(
              height: 86,
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Left item (View)
                  InkWell(
                    onTap: onView,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          color: active == ActiveTab.view
                              ? const Color(0xFF6A46FF)
                              : Colors.black54,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "View Attendance",
                          style: TextStyle(
                            fontSize: 12,
                            color: active == ActiveTab.view
                                ? const Color(0xFF6A46FF)
                                : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Center placeholder (space for center floating button)
                  const SizedBox(width: 72),

                  // Right item (Profile)
                  InkWell(
                    onTap: onProfile,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_outline,
                          color: active == ActiveTab.profile
                              ? const Color(0xFF6A46FF)
                              : Colors.black54,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Profile",
                          style: TextStyle(
                            fontSize: 12,
                            color: active == ActiveTab.profile
                                ? const Color(0xFF6A46FF)
                                : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Floating button placement:
            // - View: left
            // - Scan: center
            // - Profile: right
            if (active == ActiveTab.view)
              Positioned(left: 18, top: -36, child: floatingButton())
            else if (active == ActiveTab.profile)
              Positioned(right: 18, top: -36, child: floatingButton())
            else
              Positioned.fill(
                top: -32,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: floatingButton(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

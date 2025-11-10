import 'package:flutter/material.dart';
import '../../screens/login_screen.dart';
import 'student_view_attendance_page.dart';
import 'student_scan_attendance_page.dart';

class StudentProfilePage extends StatelessWidget {
  final String name;
  final String className;
  final String semester;
  final String gender;
  final String id;
  final String avatarLetter;

  const StudentProfilePage({
    super.key,
    required this.name,
    required this.className,
    required this.semester,
    required this.gender,
    required this.id,
    required this.avatarLetter,
  });

  void _performLogout(BuildContext context) {
    // Close all routes and go to login screen (same behavior as before)
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        // <-- Added logout action on the top-right (purple icon)
        actions: [
          IconButton(
            onPressed: () => _performLogout(context),
            icon: const Icon(Icons.logout_rounded),
            color: const Color(0xFF6A46FF),
            tooltip: 'Logout',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),
            // Avatar with soft shadow
            Center(
              child: Material(
                elevation: 8,
                shape: const CircleBorder(),
                color: Colors.white,
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: Colors.white,
                  child: Text(
                    avatarLetter,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Name and role
            Text(
              name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF222238),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Student',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black45,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 18),

            // Info cards
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Column(
                  children: [
                    _infoCard(
                      icon: Icons.person_outline,
                      iconColor: const Color(0xFF6A46FF),
                      label: 'Student Name',
                      value: name,
                    ),
                    const SizedBox(height: 12),
                    _infoCard(
                      icon: Icons.school_outlined,
                      iconColor: const Color(0xFF6A46FF),
                      label: 'Class',
                      value: className,
                    ),
                    const SizedBox(height: 12),
                    _infoCard(
                      icon: Icons.calendar_today_outlined,
                      iconColor: const Color(0xFF6A46FF),
                      label: 'Semester',
                      value: semester,
                    ),
                    const SizedBox(height: 12),
                    _infoCard(
                      icon: Icons.person,
                      iconColor: const Color(0xFF6A46FF),
                      label: 'Gender',
                      value: gender,
                    ),
                    const SizedBox(height: 12),
                    _infoCard(
                      icon: Icons.tag,
                      iconColor: const Color(0xFF6A46FF),
                      label: 'Student ID',
                      value: id,
                    ),

                    const SizedBox(height: 24),

                    // Logout button (same behavior as top-right icon)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.logout, color: Colors.white),
                        label: const Text(
                          'Logout',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => _performLogout(context),
                      ),
                    ),

                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Bottom navigation with a right-floating purple profile button (to visually match provided design)
      bottomNavigationBar: SizedBox(
        height: 86,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 86,
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // View Attendance
                  InkWell(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const StudentViewAttendanceMobile()),
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.menu_book_rounded, color: Colors.black54),
                        SizedBox(height: 6),
                        Text("View Attendance", style: TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),

                  // Scan Attendance (center)
                  InkWell(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const StudentScanAttendancePage()),
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.qr_code_scanner, color: Colors.black54),
                        SizedBox(height: 6),
                        Text("Scan Attendance", style: TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),

                  // spacer for right-floating button overlap
                  const SizedBox(width: 56),
                ],
              ),
            ),

            // Right-floating purple profile button (overlaps nav, matches design)
            Positioned(
              right: 18,
              top: -28,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      // Already on profile page - no-op or you can add edit profile
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
                      child: const Icon(Icons.person, color: Colors.white, size: 30),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black12.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15, color: Color(0xFF222238), fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
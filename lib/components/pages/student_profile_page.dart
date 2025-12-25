import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../screens/login_screen.dart';
import 'student_view_attendance_page.dart';
import 'student_scan_attendance_page.dart';
import '../../components/student_bottom_nav_bar.dart';

class StudentProfilePage extends StatefulWidget {
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

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  late String _semester;
  bool _loadingSemester = false;

  // 🔹 Appearance state
  final ValueNotifier<bool> _isDarkMode = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _semester = widget.semester;
    if (_semester.trim().isEmpty) {
      _fetchSemesterFromCourses();
    }
  }

  @override
  void dispose() {
    _isDarkMode.dispose();
    super.dispose();
  }

  Future<void> _fetchSemesterFromCourses() async {
    setState(() => _loadingSemester = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final username = widget.id;

      String? classRefId;

      final q = await firestore
          .collection('students')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (q.docs.isNotEmpty) {
        final data = q.docs.first.data();
        final raw = data['class_ref'] ?? data['classRef'] ?? data['class'];
        if (raw is DocumentReference) {
          classRefId = raw.id;
        } else if (raw is String) {
          classRefId = raw.split('/').last;
        }
      }

      if (classRefId != null) {
        final courseSnap = await firestore
            .collection('courses')
            .where('class', isEqualTo: classRefId)
            .limit(1)
            .get();

        if (courseSnap.docs.isNotEmpty) {
          _semester =
              courseSnap.docs.first.data()['semester']?.toString() ?? '';
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingSemester = false);
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isDarkMode,
      builder: (context, darkMode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: darkMode ? ThemeData.dark() : ThemeData.light(),
          home: Scaffold(
            backgroundColor:
                darkMode ? Colors.grey[900] : const Color(0xFFF7F8FA),

            // ================= APP BAR =================
            appBar: AppBar(
              backgroundColor: darkMode ? Colors.grey[850] : Colors.white,
              elevation: 0.5,
              centerTitle: true,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios,
                    color: darkMode ? Colors.white70 : Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Profile',
                style: TextStyle(
                  color: darkMode ? Colors.white70 : Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
              actions: [
                IconButton(
                  onPressed: _logout,
                  icon: Icon(Icons.logout_rounded,
                      color: darkMode ? Colors.purple[200] : const Color(0xFF6A46FF)),
                ),
              ],
            ),

            // ================= BODY =================
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Avatar
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: darkMode ? Colors.grey[800] : Colors.white,
                    child: Text(
                      widget.avatarLetter,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: darkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Name
                  Text(
                    widget.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: darkMode ? Colors.white70 : Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'Student',
                    style: TextStyle(
                      fontSize: 13,
                      color: darkMode ? Colors.white38 : Colors.black45,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Profile cards
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          _profileTile(
                              icon: Icons.person_outline,
                              title: 'Student Name',
                              value: widget.name,
                              darkMode: darkMode),
                          _profileTile(
                              icon: Icons.school_outlined,
                              title: 'Class',
                              value: widget.className,
                              darkMode: darkMode),
                          _profileTile(
                              icon: Icons.calendar_today_outlined,
                              title: 'Semester',
                              value:
                                  _loadingSemester ? 'Loading...' : _semester,
                              darkMode: darkMode),
                          _profileTile(
                              icon: Icons.person,
                              title: 'Gender',
                              value: widget.gender,
                              darkMode: darkMode),
                          _profileTile(
                              icon: Icons.badge_outlined,
                              title: 'Student Username',
                              value: widget.id,
                              darkMode: darkMode),
                          // 🔹 Appearance Switch
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: darkMode ? Colors.grey[850] : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: darkMode
                                      ? Colors.grey[700]!
                                      : Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.dark_mode,
                                    color: Color(0xFF6A46FF)),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Appearance',
                                    style: TextStyle(
                                      
                                      fontSize: 12,
                                      color: Colors.black45,
                                    ),
                                    
                                  ),
                                ),
                                Switch(
                                  value: darkMode,
                                  activeColor: const Color(0xFF6A46FF),
                                  onChanged: (val) => _isDarkMode.value = val,
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ================= NAV BAR =================
            bottomNavigationBar: SafeArea(
              child: StudentBottomNavBar(
                currentIndex: 2,
                onTap: (index) {
                  if (index == 0) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StudentViewAttendanceMobile(),
                      ),
                    );
                  } else if (index == 1) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StudentScanAttendancePage(),
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // ================= PROFILE TILE =================
  Widget _profileTile({
    required IconData icon,
    required String title,
    required String value,
    required bool darkMode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: darkMode ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: darkMode ? Colors.grey[700]! : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6A46FF), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: darkMode ? Colors.white38 : Colors.black45,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: darkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

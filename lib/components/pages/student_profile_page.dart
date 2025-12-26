import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../screens/login_screen.dart';
import 'student_view_attendance_page.dart';
import 'student_scan_attendance_page.dart';
import '../../components/student_bottom_nav_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
// student_theme_controller.dart
import '../student_theme_controller.dart';

// For Lucide icons, if needed:
// import 'package:lucide_icons/lucide_icons.dart';

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
  File? _avatarImage;
  Future<void> _pickAvatarImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _avatarImage = File(pickedFile.path);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Image selected!')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No image selected.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  late String _semester;
  bool _loadingSemester = false;

  @override
  void initState() {
    super.initState();
    _semester = widget.semester;
    if (_semester.trim().isEmpty) {
      _fetchSemesterFromCourses();
    }
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
    return AnimatedBuilder(
      animation: StudentThemeController.instance,
      builder: (context, _) {
        final darkMode = StudentThemeController.instance.isDarkMode;
        final Color bgColor = darkMode
            ? const Color(0xFF1F2937)
            : const Color(0xFFF7F8FA);
        final Color cardColor = darkMode
            ? const Color(0xFF23243A)
            : Colors.white;
        final Color borderColor = darkMode
            ? const Color(0xFF374151)
            : Colors.grey.shade200;
        final Color textColor = darkMode ? Colors.white : Colors.black;
        final Color subTextColor = darkMode ? Colors.white70 : Colors.black54;
        final Color accentColor = darkMode ? const Color.fromARGB(255, 170, 148, 255) : const Color(0xFF6A46FF);

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: darkMode ? ThemeData.dark() : ThemeData.light(),
          home: Scaffold(
            backgroundColor: bgColor,

            // ================= APP BAR =================
            appBar: AppBar(
              backgroundColor: cardColor,
              elevation: 0.5,
              centerTitle: true,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios, color: accentColor),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Profile',
                style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
              ),
              actions: [
                IconButton(
                  onPressed: _logout,
                  icon: Icon(Icons.logout_rounded, color: accentColor),
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
                  GestureDetector(
                    onTap: _avatarImage != null
                        ? () {
                            showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                backgroundColor: Colors.transparent,
                                child: InteractiveViewer(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.file(
                                      _avatarImage!,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                        : null,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: cardColor,
                      backgroundImage: _avatarImage != null
                          ? FileImage(_avatarImage!)
                          : null,
                      child: _avatarImage == null
                          ? Text(
                              widget.avatarLetter,
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: accentColor,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Name
                  Text(
                    widget.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Student',
                    style: TextStyle(fontSize: 15, color: subTextColor),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _profileCard(
                            icon: Icons.person_outline,
                            title: 'Student Name',
                            value: widget.name,
                            darkMode: darkMode,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            accentColor: accentColor,
                            cardColor: cardColor,
                            borderColor: borderColor,
                          ),
                          _profileCard(
                            icon: Icons.school_outlined,
                            title: 'Class',
                            value: widget.className,
                            darkMode: darkMode,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            accentColor: accentColor,
                            cardColor: cardColor,
                            borderColor: borderColor,
                          ),
                          _profileCard(
                            icon: Icons.calendar_today_outlined,
                            title: 'Semester',
                            value: _loadingSemester ? 'Loading...' : _semester,
                            darkMode: darkMode,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            accentColor: accentColor,
                            cardColor: cardColor,
                            borderColor: borderColor,
                          ),
                          _profileCard(
                            icon: Icons.person,
                            title: 'Gender',
                            value: widget.gender,
                            darkMode: darkMode,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            accentColor: accentColor,
                            cardColor: cardColor,
                            borderColor: borderColor,
                          ),
                          _profileCard(
                            icon: Icons.badge_outlined,
                            title: 'Student Username',
                            value: widget.id,
                            darkMode: darkMode,
                            textColor: textColor,
                            subTextColor: subTextColor,
                            accentColor: accentColor,
                            cardColor: cardColor,
                            borderColor: borderColor,
                          ),
                          // Settings Card
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.settings, color: accentColor),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Setting',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: subTextColor,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Icon(
                                      darkMode
                                          ? Icons.dark_mode
                                          : Icons.brightness_6,
                                      color: accentColor,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Appearance',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: subTextColor,
                                        ),
                                      ),
                                    ),
                                    Switch(
                                      value: darkMode,
                                      activeColor: accentColor,
                                      onChanged: (val) {
                                        StudentThemeController.instance
                                            .setDarkMode(val);
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: cardColor,
                                      foregroundColor: accentColor,
                                      elevation: 0,
                                      side: BorderSide(color: accentColor),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 8,
                                      ),
                                    ),
                                    onPressed: _pickAvatarImage,
                                    icon: Icon(Icons.edit, color: accentColor),
                                    label: Text(
                                      'Edit Image',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: accentColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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

  // ================= PROFILE CARD =================
  Widget _profileCard({
    required IconData icon,
    required String title,
    required String value,
    required bool darkMode,
    required Color textColor,
    required Color subTextColor,
    required Color accentColor,
    required Color cardColor,
    required Color borderColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: accentColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 13, color: subTextColor),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
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

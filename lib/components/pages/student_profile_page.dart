import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../screens/login_screen.dart';
import '../../components/popup/logout_confirmation_popup.dart';
import 'student_view_attendance_page.dart';
import 'student_scan_attendance_page.dart';
import '../../components/animated_bottom_bar.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
// student_theme_controller.dart
import '../student_theme_controller.dart';

// Import the ChangePasswordPopup
import '../../components/popup/change_password_popup.dart';

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

  /// Shows the ChangePasswordPopup, verifies the old password against the
  /// students document (username == widget.id) and updates the password field.
  Future<void> _showChangePasswordDialog() async {
    final success = await showDialog<bool?>(
      context: context,
      builder: (context) => ChangePasswordPopup(
        onSubmit: (oldPass, newPass) async {
          try {
            if (newPass.length < 6) {
              return 'New password must be at least 6 characters';
            }

            final studentsRef = FirebaseFirestore.instance.collection(
              'students',
            );

            // Robust lookup
            DocumentSnapshot? studentDoc;
            try {
              var q = await studentsRef
                  .where('username', isEqualTo: widget.id)
                  .limit(1)
                  .get();
              if (q.docs.isNotEmpty) studentDoc = q.docs.first;
              if (studentDoc == null) {
                q = await studentsRef
                    .where('student_id', isEqualTo: widget.id)
                    .limit(1)
                    .get();
                if (q.docs.isNotEmpty) studentDoc = q.docs.first;
              }
              if (studentDoc == null) {
                q = await studentsRef
                    .where('id', isEqualTo: widget.id)
                    .limit(1)
                    .get();
                if (q.docs.isNotEmpty) studentDoc = q.docs.first;
              }
              if (studentDoc == null) {
                final docById = await studentsRef.doc(widget.id).get();
                if (docById.exists) studentDoc = docById;
              }
            } catch (e) {
              debugPrint('Password change onSubmit lookup error: $e');
            }

            if (studentDoc == null || !studentDoc.exists) {
              return 'Student record not found';
            }

            final data = (studentDoc.data() ?? {}) as Map<String, dynamic>;
            final stored = (data['password'] ?? '').toString();

            if (stored.trim() != oldPass) {
              return 'Current password is incorrect';
            }

            try {
              await studentsRef.doc(studentDoc.id).update({
                'password': newPass,
                'passwordChangedAt': FieldValue.serverTimestamp(),
              });
              debugPrint(
                'Password change onSubmit: update succeeded for docId=${studentDoc.id}',
              );
              // Also attempt to update the corresponding record in `users` collection
              try {
                final usersRef = FirebaseFirestore.instance.collection('users');
                final uQ = await usersRef
                    .where('username', isEqualTo: widget.id)
                    .limit(1)
                    .get();
                if (uQ.docs.isNotEmpty) {
                  final uDoc = uQ.docs.first;
                  await usersRef.doc(uDoc.id).update({
                    'password': newPass,
                    'updated_at': FieldValue.serverTimestamp(),
                  });
                  debugPrint(
                    'Password change onSubmit: updated users/${uDoc.id}',
                  );
                } else {
                  debugPrint(
                    'Password change onSubmit: no matching user doc in users collection for username=${widget.id}',
                  );
                }
              } catch (e) {
                debugPrint(
                  'Password change onSubmit: failed to update users collection: $e',
                );
              }
            } catch (e) {
              debugPrint('Password change: update failed: $e');
              return 'Failed to update student record';
            }

            return null; // success
          } catch (e) {
            debugPrint('Password change onSubmit error: $e');
            return 'An error occurred';
          }
        },
      ),
    );

    debugPrint('ChangePassword dialog returned: $success');
    if (success == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Password changed successfully',
              style: TextStyle(color: Colors.black),
            ),
            backgroundColor: Colors.greenAccent,
          ),
        );
      }
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
    // Show confirmation popup before logging out
    showLogoutConfirmationPopup(context).then((confirmed) {
      if (confirmed == true) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: StudentThemeController.instance,
      builder: (context, _) {
        final darkMode = StudentThemeController.instance.isDarkMode;
        final themeMode = StudentThemeController.instance.mode;
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
        final Color accentColor = darkMode
            ? const Color.fromARGB(255, 170, 148, 255)
            : const Color(0xFF6A46FF);
        final pageBg = Color.alphaBlend(
          accentColor.withValues(alpha: darkMode ? 0.06 : 0.04),
          bgColor,
        );

        return Theme(
          data: darkMode ? ThemeData.dark() : ThemeData.light(),
          child: Scaffold(
            backgroundColor: pageBg,

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
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1020),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Profile',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Manage your account information and preferences.',
                          style: TextStyle(
                            color: subTextColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: _cardDecoration(
                            cardColor: cardColor,
                            borderColor: borderColor,
                            accentColor: accentColor,
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: _avatarImage != null
                                    ? () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => Dialog(
                                            backgroundColor: Colors.transparent,
                                            child: InteractiveViewer(
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(
                                                  16,
                                                ),
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
                                  radius: 34,
                                  backgroundColor: accentColor.withValues(
                                    alpha: 0.16,
                                  ),
                                  backgroundImage: _avatarImage != null
                                      ? FileImage(_avatarImage!)
                                      : null,
                                  child: _avatarImage == null
                                      ? Text(
                                          widget.avatarLetter,
                                          style: TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.bold,
                                            color: accentColor,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 25,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '@${widget.id}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: subTextColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _metaPill(
                                          label: 'Student',
                                          foreground: accentColor,
                                          background: accentColor.withValues(
                                            alpha: 0.11,
                                          ),
                                          border: accentColor.withValues(
                                            alpha: 0.3,
                                          ),
                                        ),
                                        _metaPill(
                                          label: widget.gender,
                                          foreground: textColor,
                                          background: textColor.withValues(
                                            alpha: 0.08,
                                          ),
                                          border: borderColor,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _sectionHeader(
                          title: 'Account Settings',
                          subtitle:
                              'Personal profile details, appearance and password controls.',
                          textColor: textColor,
                          subTextColor: subTextColor,
                        ),
                        const SizedBox(height: 10),
                        _profileCard(
                          icon: Icons.person_outline,
                          title: 'Student Name',
                          value: widget.name,
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
                          textColor: textColor,
                          subTextColor: subTextColor,
                          accentColor: accentColor,
                          cardColor: cardColor,
                          borderColor: borderColor,
                        ),
                        _appearanceCard(
                          darkMode: darkMode,
                          textColor: textColor,
                          subTextColor: subTextColor,
                          accentColor: accentColor,
                          cardColor: cardColor,
                          borderColor: borderColor,
                          themeMode: themeMode,
                          onChanged: (mode) {
                            StudentThemeController.instance.setThemeMode(mode);
                          },
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _showChangePasswordDialog,
                          icon: const Icon(Icons.lock_outline, size: 18),
                          label: const Text('Change Password'),
                          style: FilledButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(46),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ================= NAV BAR =================
            bottomNavigationBar: SafeArea(
              child: AnimatedBottomBar(
                currentIndex: 2,
                onTap: (index) {
                  if (index == 2) return;
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
    required Color textColor,
    required Color subTextColor,
    required Color accentColor,
    required Color cardColor,
    required Color borderColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(
        cardColor: cardColor,
        borderColor: borderColor,
        accentColor: accentColor,
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
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: subTextColor,
                    letterSpacing: 0.15,
                  ),
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

  Widget _appearanceCard({
    required bool darkMode,
    required Color textColor,
    required Color subTextColor,
    required Color accentColor,
    required Color cardColor,
    required Color borderColor,
    required ThemeMode themeMode,
    required ValueChanged<ThemeMode> onChanged,
  }) {
    final options = const [
      {'label': 'Device', 'mode': ThemeMode.system},
      {'label': 'Light', 'mode': ThemeMode.light},
      {'label': 'Dark', 'mode': ThemeMode.dark},
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(
        cardColor: cardColor,
        borderColor: borderColor,
        accentColor: accentColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, color: accentColor, size: 20),
              const SizedBox(width: 12),
              Text(
                'Appearance',
                style: TextStyle(fontSize: 13, color: subTextColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: darkMode ? const Color(0xFF1F2335) : const Color(0xFFF1F3F7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: options.map((o) {
                final mode = o['mode'] as ThemeMode;
                final selected = mode == themeMode;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(mode),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? accentColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: accentColor.withOpacity(0.28),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : const [],
                      ),
                      child: Text(
                        o['label'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : (darkMode ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration({
    required Color cardColor,
    required Color borderColor,
    required Color accentColor,
  }) {
    return BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: borderColor),
      boxShadow: [
        BoxShadow(
          color: accentColor.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  Widget _sectionHeader({
    required String title,
    required String subtitle,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: subTextColor,
          ),
        ),
      ],
    );
  }

  Widget _metaPill({
    required String label,
    required Color foreground,
    required Color background,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 11.5,
          height: 1,
        ),
      ),
    );
  }
}

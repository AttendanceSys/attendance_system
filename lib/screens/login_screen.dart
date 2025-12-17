import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:attendance_system/screens/super_admin_page.dart';
import 'package:attendance_system/screens/faculty_admin_page.dart';
// <-- Import your teacher page!
import 'package:attendance_system/screens/teacher_main_page.dart';
import 'package:attendance_system/components/pages/student_view_attendance_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../services/session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // UI-only additions
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  String? _errorMessage;
  bool _isLoggingIn = false;
  bool _obscurePassword = true;

  bool _isMobilePlatform() {
    if (kIsWeb) return false;
    final p = defaultTargetPlatform;
    return p == TargetPlatform.android || p == TargetPlatform.iOS;
  }

  // Shared text styles
  static const TextStyle _headerStyle = TextStyle(
    color: Colors.black87,
    fontSize: 28,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle _subtitleStyle = TextStyle(
    color: Colors.black54,
    fontSize: 14,
  );

  void _handleLogin() async {
    if (_isLoggingIn) return;
    setState(() {
      _isLoggingIn = true;
    });

    String username = _usernameController.text.trim();
    String password = _passwordController.text;

    try {
      // Query the users collection
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .where('password', isEqualTo: password)
          .get();

      if (snapshot.docs.isEmpty) {
        // No matching user found
        setState(() {
          _errorMessage = 'Invalid username or password';
          _isLoggingIn = false;
        });
        return;
      }

      // Get the user data
      final userData = snapshot.docs.first.data();
      final role = userData['role'];
      final status = userData['status'];

      // Check if the user is disabled
      if (status == 'disabled') {
        setState(() {
          _errorMessage = 'Your account is disabled';
          _isLoggingIn = false;
        });
        return;
      }
      // store username in session
      Session.username = username;

      // Try to fetch the admin's full name and faculty_ref from the 'admins' collection.
      String? displayName;
      try {
        final adminSnap = await FirebaseFirestore.instance
            .collection('admins')
            .where('username', isEqualTo: username)
            .limit(1)
            .get();
        if (adminSnap.docs.isNotEmpty) {
          final adminData = adminSnap.docs.first.data();
          displayName =
              (adminData['full_name'] ??
                      adminData['name'] ??
                      adminData['display_name'])
                  as String?;

          // populate facultyRef in session if available
          final facCandidate =
              adminData['faculty_ref'] ??
              adminData['faculty_id'] ??
              adminData['faculty'];
          // Normalize and set Session.facultyRef from whatever shape the admin doc uses
          Session.setFacultyFromField(facCandidate);
        }
      } catch (e) {
        // ignore and fallback below
      }

      // fallback to user document fields or username
      displayName ??=
          (userData['name'] ??
                  userData['full_name'] ??
                  userData['display_name'] ??
                  username)
              as String;

      // if faculty not found on admins doc, try users doc
      if (Session.facultyRef == null) {
        final userFac =
            userData['faculty_ref'] ??
            userData['faculty_id'] ??
            userData['faculty'];
        Session.setFacultyFromField(userFac);
      }

      Session.name = displayName;

      if (role == 'Super admin') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Welcome $displayName')));
        await Future.delayed(const Duration(milliseconds: 700));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SuperAdminPage()),
        );
      } else if (role == 'admin') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Welcome $displayName')));
        await Future.delayed(const Duration(milliseconds: 700));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const FacultyAdminPage()),
        );
      } else if (role == 'teacher') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Welcome $displayName')));
        await Future.delayed(const Duration(milliseconds: 700));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TeacherMainPage()),
        );
      } else if (role == 'student') {
        if (!_isMobilePlatform()) {
          setState(() {
            _errorMessage =
                'Student login is allowed only on mobile (Android/iOS).';
            _isLoggingIn = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Student login is allowed only on mobile (Android/iOS).',
              ),
            ),
          );
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Welcome $displayName')));
        await Future.delayed(const Duration(milliseconds: 700));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const StudentViewAttendanceMobile(),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Role not supported';
          _isLoggingIn = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred during login';
        _isLoggingIn = false;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isMobile
              ? const LinearGradient(
                  colors: [Color(0xFF9D83D7), Color(0xFFB39AF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFFF5F8FB), Color(0xFFF1F6FB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
        ),
        child: Center(
          child: isMobile ? _buildMobileForm(context) : _buildWebForm(context),
        ),
      ),
    );
  }

  Widget _buildMobileForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black26.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          child: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                Text("LOGIN", style: _headerStyle, textAlign: TextAlign.center),
                const SizedBox(height: 18),
                Text(
                  "Welcome Please enter your details to log in.",
                  style: _subtitleStyle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                _buildStyledInput(
                  controller: _usernameController,
                  icon: Icons.person_outline,
                  hint: "Enter your username",
                  isPassword: false,
                  focusNode: _usernameFocus,
                  onSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_passwordFocus),
                  autofillHints: const [AutofillHints.username],
                ),
                const SizedBox(height: 14),
                _buildStyledInput(
                  controller: _passwordController,
                  icon: Icons.lock_outline,
                  hint: "Enter your password",
                  isPassword: true,
                  focusNode: _passwordFocus,
                  onSubmitted: (_) => _handleLogin(),
                  autofillHints: const [AutofillHints.password],
                ),
                const SizedBox(height: 20),
                if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(height: 8),
                _isLoggingIn
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(
                          color: Color(0xFF6A46FF),
                        ),
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A46FF),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Log In",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebForm(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Center(
          child: Container(
            width: 460,
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 34),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("LOGIN", style: _headerStyle),
                  const SizedBox(height: 8),
                  Text(
                    "Welcome Please enter your details to log in.",
                    style: _subtitleStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  _buildStyledInput(
                    controller: _usernameController,
                    icon: Icons.person,
                    hint: "Enter your username",
                    isPassword: false,
                    focusNode: _usernameFocus,
                    onSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_passwordFocus),
                    filledColor: const Color(0xFFF7F9FB),
                    autofillHints: const [AutofillHints.username],
                  ),
                  const SizedBox(height: 14),
                  _buildStyledInput(
                    controller: _passwordController,
                    icon: Icons.lock,
                    hint: "Enter your password",
                    isPassword: true,
                    focusNode: _passwordFocus,
                    onSubmitted: (_) => _handleLogin(),
                    filledColor: const Color(0xFFF7F9FB),
                    autofillHints: const [AutofillHints.password],
                  ),
                  const SizedBox(height: 18),
                  if (_errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 14,
                      ),
                    ),
                  const SizedBox(height: 12),
                  _isLoggingIn
                      ? const CircularProgressIndicator(
                          color: Color(0xFF3B82F6),
                        )
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "LOG IN",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStyledInput({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    FocusNode? focusNode,
    void Function(String)? onSubmitted,
    Color? filledColor,
    List<String>? autofillHints,
  }) {
    final inputFill = filledColor ?? Colors.white;
    final bool showObscure = isPassword ? _obscurePassword : false;

    return TextField(
      controller: controller,
      obscureText: showObscure,
      style: const TextStyle(color: Colors.black87, fontSize: 16),
      focusNode: focusNode,
      onSubmitted: onSubmitted,
      autofillHints: autofillHints,
      decoration: InputDecoration(
        filled: true,
        fillColor: inputFill,
        prefixIcon: Icon(icon, color: Colors.black45),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black45),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.black45,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              )
            : null,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.black12.withOpacity(0.04)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.black12.withOpacity(0.04)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 12,
        ),
      ),
    );
  }
}

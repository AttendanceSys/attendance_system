import 'package:flutter/material.dart';
import 'package:attendance_system/screens/super_admin_page.dart';
import 'package:attendance_system/screens/faculty_admin_page.dart';
// <-- Import your teacher page!
import 'package:attendance_system/screens/teacher_main_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String? _errorMessage;
  bool _isLoggingIn = false;

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Welcome $displayName')));
      await Future.delayed(const Duration(milliseconds: 700));

      if (role == 'Super admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SuperAdminPage()),
        );
      } else if (role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const FacultyAdminPage()),
        );
      } else if (role == 'teacher') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TeacherMainPage()),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF9D83D7), Color(0xFF4D91D6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: isMobile ? _buildMobileForm(context) : _buildWebForm(context),
        ),
      ),
    );
  }

  Widget _buildMobileForm(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "LOGIN",
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 32),
          _buildInputField(
            controller: _usernameController,
            icon: Icons.person,
            hint: "Username",
            obscure: false,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            controller: _passwordController,
            icon: Icons.lock,
            hint: "Password",
            obscure: true,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(_errorMessage!, style: TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4D91D6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _handleLogin,
              child: const Text(
                "Login",
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebForm(BuildContext context) {
    return Center(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "LOGIN",
              style: TextStyle(
                color: Color(0xFF4D91D6),
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 32),
            _buildInputField(
              controller: _usernameController,
              icon: Icons.person,
              hint: "Username",
              obscure: false,
              fillColor: Colors.grey[100],
              textColor: Colors.black87,
            ),
            const SizedBox(height: 16),
            _buildInputField(
              controller: _passwordController,
              icon: Icons.lock,
              hint: "Password",
              obscure: true,
              fillColor: Colors.grey[100],
              textColor: Colors.black87,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4D91D6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _handleLogin,
                child: const Text(
                  "Login",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required bool obscure,
    Color? fillColor,
    Color? textColor,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: textColor ?? Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: fillColor ?? Colors.white.withOpacity(0.2),
        prefixIcon: Icon(icon, color: textColor ?? Colors.white),
        hintText: hint,
        hintStyle: TextStyle(color: textColor ?? Colors.white70),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:attendance_system/screens/super_admin_page.dart';
import 'package:attendance_system/screens/faculty_admin_page.dart';
import 'package:attendance_system/components/pages/student_view_attendance_page.dart';
// <-- Import your teacher page!
import 'package:attendance_system/screens/teacher_main_page.dart';
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

  void _handleLogin() {
    if (_isLoggingIn) return;
    setState(() {
      _isLoggingIn = true;
    });

    String username = _usernameController.text.trim();
    String password = _passwordController.text;
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    // Example credentials
    if (username == 'admin' && password == 'admin123') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SuperAdminPage()),
      ).then((_) {
        if (mounted) setState(() => _isLoggingIn = false);
      });
    } else if (username == 'a' && password == 'b') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const FacultyAdminPage()),
      ).then((_) {
        if (mounted) setState(() => _isLoggingIn = false);
      });
    } else if (username == 'student' && password == 'student123') {
      if (!isMobile) {
        // Only allow student login on mobile devices
        setState(() {
          _errorMessage = 'Student login is allowed on mobile devices only.';
          _isLoggingIn = false;
        });
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const StudentViewAttendanceMobile()),
        ).then((_) {
          if (mounted) setState(() => _isLoggingIn = false);
        });
      }
    }
    // Teacher login
    else if (username == 'teacher' && password == 'teacher123') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const TeacherMainPage()),
      ).then((_) {
        if (mounted) setState(() => _isLoggingIn = false);
      });
    }
    else {
      if (mounted) {
        setState(() {
          _errorMessage = 'Invalid username or password';
          _isLoggingIn = false;
        });
      }
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
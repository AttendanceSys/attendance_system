import 'package:flutter/material.dart';
import 'package:attendance_system/screens/super_admin_page.dart';
import 'package:attendance_system/screens/faculty_admin_page.dart';
import 'package:attendance_system/components/pages/student_view_attendance_page.dart';
import 'package:attendance_system/screens/teacher_main_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  String? _errorMessage;
  bool _isLoggingIn = false;
  bool _obscurePassword = true;

  void _handleLogin() {
    if (_isLoggingIn) return;
    setState(() {
      _isLoggingIn = true;
    });

    String username = _usernameController.text.trim();
    String password = _passwordController.text;
    final bool isMobile = MediaQuery.of(context).size.width < 600;

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
    } else if (username == 'teacher' && password == 'teacher123') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const TeacherMainPage()),
      ).then((_) {
        if (mounted) setState(() => _isLoggingIn = false);
      });
    } else {
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
    _usernameFocus.dispose();
    _passwordFocus.dispose();
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
    // For mobile, keep it compact but slightly larger
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "LOGIN",
            style: TextStyle(
              color: Colors.white,
              fontSize: 38, // Larger font
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 38),
          _buildInputField(
            controller: _usernameController,
            icon: Icons.person,
            hint: "Username",
            obscure: false,
            focusNode: _usernameFocus,
            onSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
          ),
          const SizedBox(height: 22),
          _buildInputField(
            controller: _passwordController,
            icon: Icons.lock,
            hint: "Password",
            obscure: true,
            isPassword: true,
            focusNode: _passwordFocus,
            onSubmitted: (_) => _handleLogin(),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16)),
          ],
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4D91D6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(vertical: 22),
              ),
              onPressed: _handleLogin,
              child: const Text(
                "Login",
                style: TextStyle(fontSize: 22, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebForm(BuildContext context) {
    // Make card much larger and more central
    return Center(
      child: Container(
        width: 600, // Wider card
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 54), // More padding
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 32,
              offset: const Offset(0, 12),
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
                fontSize: 48, // Much larger font
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 48),
            _buildInputField(
              controller: _usernameController,
              icon: Icons.person,
              hint: "Username",
              obscure: false,
              fillColor: Colors.grey[100],
              textColor: Colors.black87,
              focusNode: _usernameFocus,
              fontSize: 24,
              onSubmitted: (_) => FocusScope.of(context).requestFocus(_passwordFocus),
            ),
            const SizedBox(height: 28),
            _buildInputField(
              controller: _passwordController,
              icon: Icons.lock,
              hint: "Password",
              obscure: true,
              isPassword: true,
              fillColor: Colors.grey[100],
              textColor: Colors.black87,
              focusNode: _passwordFocus,
              fontSize: 24,
              onSubmitted: (_) => _handleLogin(),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 24),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 18)),
            ],
            const SizedBox(height: 42),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4D91D6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 26),
                ),
                onPressed: _handleLogin,
                child: const Text(
                  "Login",
                  style: TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold),
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
    bool isPassword = false,
    FocusNode? focusNode,
    void Function(String)? onSubmitted,
    double fontSize = 20,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : obscure,
      style: TextStyle(color: textColor ?? Colors.white, fontSize: fontSize),
      focusNode: focusNode,
      decoration: InputDecoration(
        filled: true,
        fillColor: fillColor ?? Colors.white.withOpacity(0.2),
        prefixIcon: Icon(icon, color: textColor ?? Colors.white, size: fontSize + 4),
        hintText: hint,
        hintStyle: TextStyle(color: textColor ?? Colors.white70, fontSize: fontSize),
        contentPadding: EdgeInsets.symmetric(
          vertical: fontSize + 8,
          horizontal: fontSize + 4,
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: textColor ?? Colors.white,
                  size: fontSize + 2,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
      textInputAction: isPassword ? TextInputAction.done : TextInputAction.next,
      onSubmitted: onSubmitted,
    );
  }
}
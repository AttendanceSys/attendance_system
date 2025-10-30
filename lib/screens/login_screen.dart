import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
import '../hooks/use_login.dart';
import '../screens/super_admin_page.dart';
import '../screens/faculty_admin_page.dart';
import '../screens/teacher_main_page.dart';
import '../components/pages/student_view_attendance_page.dart';

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

  bool _isLoggingIn = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isLoggingIn) return;

    setState(() {
      _isLoggingIn = true;
      _errorMessage = null;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill all fields';
        _isLoggingIn = false;
      });
      return;
    }

    final user = await loginUser(username, password);

    if (!mounted) return;

    if (user == null) {
      setState(() {
        _errorMessage = 'Invalid username or password';
        _isLoggingIn = false;
      });
      return;
    }

    // If loginUser returns a marker indicating the account is disabled,
    // show a clear message and do not proceed.
    if (user.containsKey('disabled') && user['disabled'] == true) {
      setState(() {
        _errorMessage = 'Account disabled. Contact administrator.';
        _isLoggingIn = false;
      });
      return;
    }

    final role = user['role'];
    final fullName = (user['full_name'] ?? user['usernames'] ?? username)
        .toString();
    final String? userFacultyId = (user['faculty_id'] != null)
        ? user['faculty_id'].toString()
        : null;

    // Show a brief welcome message with full name in the login screen
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Welcome, $fullName')));
    }

    switch (role) {
      case 'super_admin':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SuperAdminPage()),
        );
        break;
      case 'admin':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => FacultyAdminPage(
              displayName: fullName,
              facultyId: userFacultyId,
            ),
          ),
        );
        break;
      case 'teacher':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TeacherMainPage(displayName: fullName),
          ),
        );
        break;
      case 'student':
        if (!isMobile) {
          setState(() {
            _errorMessage = 'Student login allowed only on mobile devices.';
            _isLoggingIn = false;
          });
          return;
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const StudentViewAttendanceMobile(),
          ),
        );
        break;
      default:
        setState(() {
          _errorMessage = 'Unknown role: $role';
          _isLoggingIn = false;
        });
        return;
    }

    if (mounted) setState(() => _isLoggingIn = false);
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
              fontSize: 38,
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
            onSubmitted: (_) =>
                FocusScope.of(context).requestFocus(_passwordFocus),
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
          const SizedBox(height: 24),
          if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 16),
            ),
          const SizedBox(height: 28),
          _isLoggingIn
              ? const CircularProgressIndicator(color: Colors.white)
              : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4D91D6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    onPressed: _handleLogin,
                    child: const Text(
                      "Login",
                      style: TextStyle(fontSize: 20, color: Colors.white),
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
        width: 520,
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 54),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 24,
              offset: const Offset(0, 10),
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
                fontSize: 44,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
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
              fontSize: 22,
              onSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_passwordFocus),
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
              fontSize: 22,
              onSubmitted: (_) => _handleLogin(),
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 18),
              ),
            const SizedBox(height: 32),
            _isLoggingIn
                ? const CircularProgressIndicator(color: Color(0xFF4D91D6))
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4D91D6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 24),
                      ),
                      onPressed: _handleLogin,
                      child: const Text(
                        "Login",
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
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
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        filled: true,
        fillColor: fillColor ?? Colors.white.withOpacity(0.15),
        prefixIcon: Icon(icon, color: textColor ?? Colors.white),
        hintText: hint,
        hintStyle: TextStyle(color: textColor ?? Colors.white70),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: textColor ?? Colors.white,
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
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 16,
        ),
      ),
    );
  }
}

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

  // Shared text styles so web and mobile use the same font styling
  static const TextStyle _headerStyle = TextStyle(
    color: Colors.black87,
    fontSize: 28,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle _subtitleStyle = TextStyle(
    color: Colors.black54,
    fontSize: 14,
  );

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
      // keep same behavior, only change visuals
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
              ),
              const SizedBox(height: 14),
              _buildStyledInput(
                controller: _passwordController,
                icon: Icons.lock_outline,
                hint: "Enter your password",
                isPassword: true,
                focusNode: _passwordFocus,
                onSubmitted: (_) => _handleLogin(),
              ),
              const SizedBox(height: 20),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
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
                    ? const CircularProgressIndicator(color: Color(0xFF3B82F6))
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
  }) {
    final inputFill = filledColor ?? Colors.white;
    final bool showObscure = isPassword ? _obscurePassword : false;

    return TextField(
      controller: controller,
      obscureText: showObscure,
      style: const TextStyle(color: Colors.black87, fontSize: 16),
      focusNode: focusNode,
      onSubmitted: onSubmitted,
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

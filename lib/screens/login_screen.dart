import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:attendance_system/screens/super_admin_page.dart';
import 'package:attendance_system/screens/faculty_admin_page.dart';
// <-- Import your teacher page!
import 'package:attendance_system/screens/teacher_main_page.dart';
import 'package:attendance_system/components/pages/student_view_attendance_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session.dart';
import '../services/theme_controller.dart';

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
  static const TextStyle _headerStyleLight = TextStyle(
    color: Colors.black87,
    fontSize: 28,
    fontWeight: FontWeight.bold,
  );
  static const TextStyle _headerStyleDark = TextStyle(
    color: Color(0xFFE6EAF1),
    fontSize: 28,
    fontWeight: FontWeight.bold,
  );
  static const TextStyle _subtitleStyleLight = TextStyle(
    color: Colors.black54,
    fontSize: 14,
  );
  static const TextStyle _subtitleStyleDark = TextStyle(
    color: Color(0xFF9EA5B5),
    fontSize: 14,
  );

  void _handleLogin() async {
    if (_isLoggingIn) return;

    setState(() {
      _isLoggingIn = true;
      _errorMessage = null;
    });

    String username = _usernameController.text.trim();
    String password = _passwordController.text;

    try {
      // 1️⃣ Check username first
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (userSnap.docs.isEmpty) {
        setState(() {
          _errorMessage = 'Username not found';
          _isLoggingIn = false;
        });
        return;
      }

      final userData = userSnap.docs.first.data();

      // 2️⃣ Check password
      if (userData['password'] != password) {
        setState(() {
          _errorMessage = 'Incorrect password';
          _isLoggingIn = false;
        });
        return;
      }

      // 3️⃣ Check account status
      if (userData['status'] == 'disabled') {
        setState(() {
          _errorMessage = 'Your account is disabled';
          _isLoggingIn = false;
        });
        return;
      }

      // 4️⃣ Successful login
      final role = userData['role'];
      Session.username = username;

      final displayName =
          userData['name'] ??
          userData['full_name'] ??
          userData['display_name'] ??
          username;

      Session.name = displayName;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Welcome $displayName')));

      await Future.delayed(const Duration(milliseconds: 700));

      if (role == 'Super admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SuperAdminPage()),
        );
      } else if (role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const FacultyAdminPage()),
        );
      } else if (role == 'teacher') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TeacherMainPage()),
        );
      } else if (role == 'student') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const StudentViewAttendanceMobile(),
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
        _errorMessage = 'Login failed. Try again.';
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
    // Use ValueListenableBuilder to react to theme changes for the whole login page
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, themeMode, _) {
        final isDark = themeMode == ThemeMode.dark;
        return Scaffold(
          body: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: isDark
                      ? const LinearGradient(
                          colors: [Color(0xFF23283A), Color(0xFF181C2A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : (isMobile
                            ? const LinearGradient(
                                colors: [Color(0xFF9D83D7), Color(0xFFB39AF6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : const LinearGradient(
                                colors: [Color(0xFFF5F8FB), Color(0xFFF1F6FB)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )),
                ),
                child: Center(
                  child: isMobile
                      ? _buildMobileForm(context)
                      : _buildWebForm(context),
                ),
              ),
              Positioned(
                top: isMobile ? 32 : 48,
                right: isMobile ? 32 : 48,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      ThemeController.themeMode.value = isDark
                          ? ThemeMode.light
                          : ThemeMode.dark;
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.white70,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isDark
                            ? Icons.wb_sunny_outlined
                            : Icons.nightlight_round,
                        color: isDark ? Colors.yellow[700] : Colors.indigo,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileForm(BuildContext context) {
    final themeMode = ThemeController.themeMode.value;
    final isDark = themeMode == ThemeMode.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF262C3A) : Colors.white,
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
                Text(
                  "LOGIN",
                  style: isDark ? _headerStyleDark : _headerStyleLight,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                Text(
                  "Welcome Please enter your details to log in.",
                  style: isDark ? _subtitleStyleDark : _subtitleStyleLight,
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
                  isDark: isDark,
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
                  isDark: isDark,
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
    final themeMode = ThemeController.themeMode.value;
    final isDark = themeMode == ThemeMode.dark;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Center(
          child: Container(
            width: 460,
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 34),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF262C3A) : Colors.white,
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
                  Text(
                    "LOGIN",
                    style: isDark ? _headerStyleDark : _headerStyleLight,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Welcome Please enter your details to log in.",
                    style: isDark ? _subtitleStyleDark : _subtitleStyleLight,
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
                    filledColor: isDark
                        ? const Color(0xFF2B303D)
                        : const Color(0xFFF7F9FB),
                    autofillHints: const [AutofillHints.username],
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                  _buildStyledInput(
                    controller: _passwordController,
                    icon: Icons.lock,
                    hint: "Enter your password",
                    isPassword: true,
                    focusNode: _passwordFocus,
                    onSubmitted: (_) => _handleLogin(),
                    filledColor: isDark
                        ? const Color(0xFF2B303D)
                        : const Color(0xFFF7F9FB),
                    autofillHints: const [AutofillHints.password],
                    isDark: isDark,
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
    bool isDark = false,
  }) {
    final inputFill =
        filledColor ?? (isDark ? const Color(0xFF2B303D) : Colors.white);
    final bool showObscure = isPassword ? _obscurePassword : false;
    final textColor = isDark ? const Color(0xFFE6EAF1) : Colors.black87;
    final hintTextColor = isDark ? const Color(0xFF9EA5B5) : Colors.black45;
    return TextField(
      controller: controller,
      obscureText: showObscure,
      style: TextStyle(color: textColor, fontSize: 16),
      focusNode: focusNode,
      onSubmitted: onSubmitted,
      autofillHints: autofillHints,
      decoration: InputDecoration(
        filled: true,
        fillColor: inputFill,
        prefixIcon: Icon(icon, color: hintTextColor),
        hintText: hint,
        hintStyle: TextStyle(color: hintTextColor),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: hintTextColor,
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
          borderSide: BorderSide(
            color: isDark
                ? const Color(0xFF3A404E)
                : Colors.black12.withOpacity(0.04),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark
                ? const Color(0xFFE6EAF1)
                : Colors.black12.withOpacity(0.04),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 12,
        ),
      ),
    );
  }
}

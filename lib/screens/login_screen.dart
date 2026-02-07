import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:attendance_system/screens/super_admin_page.dart';
import 'package:attendance_system/screens/faculty_admin_page.dart';
import 'package:attendance_system/screens/teacher_main_page.dart';
import 'package:attendance_system/components/pages/student_view_attendance_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
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

  void _handleLogin() async {
    if (_isLoggingIn) return;
    setState(() => _isLoggingIn = true);

    String username = _usernameController.text.trim();
    String password = _passwordController.text;

    try {
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (userSnap.docs.isEmpty) {
        setState(() {
          _errorMessage = 'Invalid username';
          _isLoggingIn = false;
        });
        return;
      }

      final userData = userSnap.docs.first.data();

      if ((userData['password'] as String?) != password) {
        setState(() {
          _errorMessage = 'Invalid password';
          _isLoggingIn = false;
        });
        return;
      }

      final role = userData['role'];
      final status = userData['status'];

      if (status == 'disabled') {
        setState(() {
          _errorMessage = 'Your account is disabled';
          _isLoggingIn = false;
        });
        return;
      }

      Session.username = username;

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

          final facCandidate =
              adminData['faculty_ref'] ??
              adminData['faculty_id'] ??
              adminData['faculty'];
          Session.setFacultyFromField(facCandidate);
        }
      } catch (_) {}

      displayName ??=
          (userData['name'] ??
                  userData['full_name'] ??
                  userData['display_name'] ??
                  username)
              as String;

      if (role == 'teacher') {
        try {
          final lecSnap = await FirebaseFirestore.instance
              .collection('teachers')
              .where('username', isEqualTo: username)
              .limit(1)
              .get();
          if (lecSnap.docs.isNotEmpty) {
            final lecData = lecSnap.docs.first.data();
            final teacherName =
                (lecData['teacher_name'] ??
                        lecData['name'] ??
                        lecData['display_name'])
                    as String?;
            if (teacherName != null && teacherName.isNotEmpty) {
              displayName = teacherName;
            }
          }
        } catch (_) {}
      }

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
      await Future.delayed(const Duration(milliseconds: 500));

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
        if (!_isMobilePlatform()) {
          setState(() {
            _errorMessage =
                'Student login is allowed only on mobile (Android/iOS).';
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
      } else {
        setState(() {
          _errorMessage = 'Role not supported';
          _isLoggingIn = false;
        });
      }
    } catch (_) {
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
    final isMobile = MediaQuery.of(context).size.width < 650;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, themeMode, _) {
        final systemDark =
            MediaQuery.of(context).platformBrightness == Brightness.dark;
        final isDark =
            themeMode == ThemeMode.dark ||
            (themeMode == ThemeMode.system && systemDark);

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? const LinearGradient(
                      colors: [Color(0xFF0B1220), Color(0xFF111B2E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFEFF6FF), Color(0xFFEDE9FE)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
            ),
            child: Stack(
              children: [
                // soft glow blobs (like SaaS)
                Positioned(
                  top: -120,
                  left: -120,
                  child: _GlowBlob(isDark: isDark),
                ),
                Positioned(
                  bottom: -140,
                  right: -140,
                  child: _GlowBlob(isDark: isDark),
                ),

                Center(
                  child: isMobile
                      ? _buildMobileForm(context, isDark: isDark)
                      : _buildWebForm(context, isDark: isDark),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileForm(BuildContext context, {required bool isDark}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 44),
      child: _LoginCard(
        isDark: isDark,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            _BrandHeader(isDark: isDark),
            const SizedBox(height: 18),

            Text(
              "Welcome Back",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? const Color(0xFFE6EAF1)
                    : const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Please enter your details to log in.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? const Color(0xFF9EA5B5)
                    : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 22),

            _buildStyledInput(
              controller: _usernameController,
              icon: Icons.person_outline_rounded,
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
              icon: Icons.lock_outline_rounded,
              hint: "Enter your password",
              isPassword: true,
              focusNode: _passwordFocus,
              onSubmitted: (_) => _handleLogin(),
              autofillHints: const [AutofillHints.password],
              isDark: isDark,
            ),

            const SizedBox(height: 18),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            _isLoggingIn
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(),
                  )
                : SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: _GradientButton(
                      text: "LOG IN",
                      onPressed: _handleLogin,
                      isDark: isDark,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebForm(BuildContext context, {required bool isDark}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: _LoginCard(
        isDark: isDark,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BrandHeader(isDark: isDark),
            const SizedBox(height: 18),

            Text(
              "Welcome Back",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? const Color(0xFFE6EAF1)
                    : const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Please enter your details to log in.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? const Color(0xFF9EA5B5)
                    : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 22),

            _buildStyledInput(
              controller: _usernameController,
              icon: Icons.person_outline_rounded,
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
              icon: Icons.lock_outline_rounded,
              hint: "Enter your password",
              isPassword: true,
              focusNode: _passwordFocus,
              onSubmitted: (_) => _handleLogin(),
              autofillHints: const [AutofillHints.password],
              isDark: isDark,
            ),

            const SizedBox(height: 18),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            _isLoggingIn
                ? const Padding(      
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(),
                  )
                : SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: _GradientButton(
                      text: "LOG IN",
                      onPressed: _handleLogin,
                      isDark: isDark,
                    ),
                  ),
          ],
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
    List<String>? autofillHints,
    required bool isDark,
  }) {
    final fill = isDark
        ? const Color(0xFF0F172A).withOpacity(0.55)
        : Colors.white.withOpacity(0.75);
    final textColor = isDark
        ? const Color(0xFFE6EAF1)
        : const Color(0xFF111827);
    final hintColor = isDark
        ? const Color(0xFF9EA5B5)
        : const Color(0xFF6B7280);

    return TextField(
      controller: controller,
      focusNode: focusNode,
      onSubmitted: onSubmitted,
      autofillHints: autofillHints,
      obscureText: isPassword ? _obscurePassword : false,
      style: TextStyle(
        color: textColor,
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: fill,
        prefixIcon: Icon(icon, color: hintColor),
        hintText: hint,
        hintStyle: TextStyle(color: hintColor, fontWeight: FontWeight.w500),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: hintColor,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark
                ? const Color(0xFF334155).withOpacity(0.55)
                : const Color(0xFFE5E7EB),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF7C3AED),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

/// ---------- UI helpers ----------

class _LoginCard extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const _LoginCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 34),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0B1220).withOpacity(0.55)
            : Colors.white.withOpacity(0.70),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? const Color(0xFF334155).withOpacity(0.45)
              : Colors.white.withOpacity(0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isDark;

  const _GradientButton({
    required this.text,
    required this.onPressed,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(14),
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  final bool isDark;
  const _BrandHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark
        ? const Color.fromARGB(255, 255, 255, 255)
        : const Color(0xFF1F2937);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/lightLogo.png',
            height: 82,
            width: 82,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 10),
          RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'QScan',
                  style: GoogleFonts.playfairDisplay(
                    fontWeight: FontWeight.w600,
                    fontSize: 26,
                    color: textColor,
                  ),
                ),
                TextSpan(
                  text: ' Smart',
                  style: GoogleFonts.playfairDisplay(
                    fontWeight: FontWeight.w600,
                    fontSize: 26,
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

class _GlowBlob extends StatelessWidget {
  final bool isDark;
  const _GlowBlob({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: isDark
              ? [const Color(0xFF7C3AED).withOpacity(0.22), Colors.transparent]
              : [const Color(0xFF7C3AED).withOpacity(0.22), Colors.transparent],
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/session.dart';
import '../../theme/teacher_theme.dart';

class TeacherProfilePage extends StatefulWidget {
  const TeacherProfilePage({super.key});

  @override
  State<TeacherProfilePage> createState() => _TeacherProfilePageState();
}

class _TeacherProfilePageState extends State<TeacherProfilePage> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _gender = 'Male';
  String _originalUsername = '';
  String _docPassword = '';
  String _roleLabel = 'Lecturer';
  bool _loading = true;
  bool _savingProfile = false;
  bool _savingPassword = false;

  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final currentUsername = (Session.username ?? '').trim();
      if (currentUsername.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No active user session found')),
          );
        }
        setState(() => _loading = false);
        return;
      }

      final teacherSnap = await _firestore
          .collection('teachers')
          .where('username', isEqualTo: currentUsername)
          .limit(1)
          .get();

      if (teacherSnap.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Teacher profile not found')),
          );
        }
        setState(() => _loading = false);
        return;
      }

      final data = teacherSnap.docs.first.data();
      final teacherName =
          (data['teacher_name'] ?? data['name'] ?? data['display_name'] ?? '')
              .toString();
      final username = (data['username'] ?? currentUsername).toString();
      final gender = (data['gender'] ?? 'Male').toString();
      final password = (data['password'] ?? '').toString();

      _fullNameController.text = teacherName;
      _usernameController.text = username;
      _gender = gender.isEmpty ? 'Male' : gender;
      _originalUsername = username;
      _docPassword = password;
      Session.name = teacherName.trim().isEmpty ? username : teacherName;
      Session.username = username;

      // Try to load role from users collection to display it on the profile
      try {
        final userQ = await _firestore
            .collection('users')
            .where('username', isEqualTo: username)
            .limit(1)
            .get();
        if (userQ.docs.isNotEmpty) {
          final roleRaw = (userQ.docs.first.data()['role'] ?? '').toString();
          _roleLabel = _roleLabelFromRaw(roleRaw);
        }
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;

    final nextName = _fullNameController.text.trim();
    final nextUsername = _usernameController.text.trim();

    if (nextName.isEmpty || nextUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Full name and username are required')),
      );
      return;
    }

    setState(() => _savingProfile = true);
    try {
      final teacherQ = await _firestore
          .collection('teachers')
          .where('username', isEqualTo: _originalUsername)
          .limit(1)
          .get();

      if (teacherQ.docs.isEmpty) {
        throw 'Teacher profile not found';
      }

      if (_originalUsername != nextUsername) {
        final dup = await _firestore
            .collection('users')
            .where('username', isEqualTo: nextUsername)
            .limit(1)
            .get();
        if (dup.docs.isNotEmpty) {
          throw 'Username already exists';
        }
      }

      final teacherDoc = teacherQ.docs.first;
      await teacherDoc.reference.update({
        'teacher_name': nextName,
        'username': nextUsername,
        'updated_at': FieldValue.serverTimestamp(),
      });

      final userQ = await _firestore
          .collection('users')
          .where('username', isEqualTo: _originalUsername)
          .where('role', isEqualTo: 'teacher')
          .limit(1)
          .get();

      if (userQ.docs.isNotEmpty) {
        await userQ.docs.first.reference.update({
          'username': nextUsername,
          'name': nextName,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      Session.username = nextUsername;
      Session.name = nextName;
      _originalUsername = nextUsername;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update profile: $e')));
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _savePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;

    final current = _currentPasswordController.text.trim();
    final next = _newPasswordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (current != _docPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current password is incorrect')),
      );
      return;
    }
    if (next != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password and confirm must match')),
      );
      return;
    }

    setState(() => _savingPassword = true);
    try {
      final teacherQ = await _firestore
          .collection('teachers')
          .where('username', isEqualTo: _originalUsername)
          .limit(1)
          .get();
      if (teacherQ.docs.isEmpty) throw 'Teacher profile not found';

      await teacherQ.docs.first.reference.update({
        'password': next,
        'updated_at': FieldValue.serverTimestamp(),
      });

      final userQ = await _firestore
          .collection('users')
          .where('username', isEqualTo: _originalUsername)
          .where('role', isEqualTo: 'teacher')
          .limit(1)
          .get();
      if (userQ.docs.isNotEmpty) {
        await userQ.docs.first.reference.update({
          'password': next,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      _docPassword = next;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update password: $e')));
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<TeacherThemeColors>();
    final scheme = Theme.of(context).colorScheme;
    final pageBackground = Color.alphaBlend(
      (palette?.accent ?? const Color(0xFF2667FF)).withValues(alpha: 0.035),
      palette?.scaffold ?? scheme.surface,
    );
    final surface = palette?.surface ?? scheme.surface;
    final inputFill = palette?.inputFill ?? scheme.surface;
    final border = (palette?.border ?? Theme.of(context).dividerColor)
        .withValues(alpha: 0.8);
    final titleColor = palette?.textPrimary ?? scheme.onSurface;
    final subColor = (palette?.textSecondary ?? scheme.onSurfaceVariant)
        .withValues(alpha: 0.95);
    final accent = palette?.accent ?? const Color(0xFF2667FF);

    final displayName = _fullNameController.text.trim().isEmpty
        ? (_usernameController.text.trim().isEmpty
              ? 'Teacher'
              : _usernameController.text.trim())
        : _fullNameController.text.trim();
    final displayUsername = _usernameController.text.trim().isEmpty
        ? 'username'
        : _usernameController.text.trim();
    final initials = displayName
        .split(' ')
        .where((p) => p.trim().isNotEmpty)
        .take(2)
        .map((p) => p.trim()[0].toUpperCase())
        .join();

    return Container(
      color: pageBackground,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1360),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profile',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            color: titleColor,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Manage your account information and security settings.',
                          style: TextStyle(
                            fontSize: 14,
                            color: subColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: _cardDecoration(
                            surface: surface,
                            border: border,
                            shadow: accent.withValues(alpha: 0.08),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      accent.withValues(alpha: 0.9),
                                      accent.withValues(alpha: 0.68),
                                    ],
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    initials.isEmpty ? 'T' : initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 24,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        color: titleColor,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '@$displayUsername',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: subColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _metaPill(
                                          label: _roleLabel,
                                          foreground: accent,
                                          background: accent.withValues(
                                            alpha: 0.1,
                                          ),
                                          border: accent.withValues(alpha: 0.26),
                                        ),
                                        _metaPill(
                                          label: _gender,
                                          foreground: titleColor,
                                          background: titleColor.withValues(
                                            alpha: 0.08,
                                          ),
                                          border: border,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        _sectionHeader(
                          title: 'Account Settings',
                          subtitle: 'Personal profile details and password controls.',
                          titleColor: titleColor,
                          subtitleColor: subColor,
                        ),
                        const SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final wide = constraints.maxWidth >= 1024;
                            final leftCard = _buildProfileCard(
                              surface: surface,
                              border: border,
                              titleColor: titleColor,
                              inputFill: inputFill,
                              accent: accent,
                            );
                            final rightCard = _buildPasswordCard(
                              surface: surface,
                              border: border,
                              titleColor: titleColor,
                              subColor: subColor,
                              inputFill: inputFill,
                              accent: accent,
                            );

                            if (wide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 7, child: leftCard),
                                  const SizedBox(width: 16),
                                  Expanded(flex: 5, child: rightCard),
                                ],
                              );
                            }

                            return Column(
                              children: [
                                leftCard,
                                const SizedBox(height: 16),
                                rightCard,
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  String _roleLabelFromRaw(String raw) {
    final r = raw.trim().toLowerCase();
    if (r.isEmpty) return 'Lecturer';
    if (r == 'super admin' || r == 'super_admin' || r == 'super-admin') {
      return 'Super admin';
    }
    if (r == 'admin') return 'Admin';
    if (r == 'teacher' || r == 'lecturer') return 'Lecturer';
    if (r == 'student') return 'Student';
    // Title-case fallback
    return raw
        .splitMapJoin(
          RegExp(r'[_\- ]'),
          onMatch: (_) => ' ',
          onNonMatch: (m) => m,
        )
        .split(' ')
        .map((s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');
  }

  Widget _buildProfileCard({
    required Color surface,
    required Color border,
    required Color titleColor,
    required Color inputFill,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(
        surface: surface,
        border: border,
        shadow: accent.withValues(alpha: 0.06),
      ),
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(
              title: 'Profile Information',
              subtitle: 'Basic account details.',
              titleColor: titleColor,
              subtitleColor: titleColor.withValues(alpha: 0.62),
            ),
            const SizedBox(height: 18),
            _label('Full Name', titleColor, required: true),
            const SizedBox(height: 8),
            TextFormField(
              controller: _fullNameController,
              readOnly: true,
              canRequestFocus: false,
              mouseCursor: SystemMouseCursors.basic,
              showCursor: false,
              enableInteractiveSelection: false,
              style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
              decoration: _inputDecoration(
                inputFill,
                border,
                accent: accent,
                hint: 'Full Name',
              ),
            ),
            const SizedBox(height: 14),
            _label('Username', titleColor, required: true),
            const SizedBox(height: 8),
            TextFormField(
              controller: _usernameController,
              readOnly: true,
              canRequestFocus: false,
              mouseCursor: SystemMouseCursors.basic,
              showCursor: false,
              enableInteractiveSelection: false,
              style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
              decoration: _inputDecoration(
                inputFill,
                border,
                accent: accent,
                hint: 'Username',
              ),
            ),
            const SizedBox(height: 14),
            _label('Role', titleColor),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _roleLabel,
              readOnly: true,
              canRequestFocus: false,
              mouseCursor: SystemMouseCursors.basic,
              showCursor: false,
              enableInteractiveSelection: false,
              style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
              decoration: _inputDecoration(
                inputFill,
                border,
                accent: accent,
                hint: 'Role',
              ),
            ),
            const SizedBox(height: 14),
            _label('Gender', titleColor),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _gender,
              readOnly: true,
              canRequestFocus: false,
              mouseCursor: SystemMouseCursors.basic,
              showCursor: false,
              enableInteractiveSelection: false,
              style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
              decoration: _inputDecoration(
                inputFill,
                border,
                accent: accent,
                hint: 'Gender',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordCard({
    required Color surface,
    required Color border,
    required Color titleColor,
    required Color subColor,
    required Color inputFill,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(
        surface: surface,
        border: border,
        shadow: accent.withValues(alpha: 0.06),
      ),
      child: Form(
        key: _passwordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(
              title: 'Security',
              subtitle: 'Update your login password.',
              titleColor: titleColor,
              subtitleColor: subColor,
            ),
            const SizedBox(height: 18),
            _label('Current Password', titleColor),
            const SizedBox(height: 8),
            TextFormField(
              controller: _currentPasswordController,
              obscureText: !_showCurrentPassword,
              style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
              decoration:
                  _inputDecoration(
                    inputFill,
                    border,
                    accent: accent,
                    hint: 'Current Password',
                  ).copyWith(
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(
                          () => _showCurrentPassword = !_showCurrentPassword,
                        );
                      },
                      icon: Icon(
                        _showCurrentPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: subColor,
                      ),
                    ),
                  ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Current password is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _label('New Password', titleColor),
            const SizedBox(height: 8),
            TextFormField(
              controller: _newPasswordController,
              obscureText: !_showNewPassword,
              style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
              decoration:
                  _inputDecoration(
                    inputFill,
                    border,
                    accent: accent,
                    hint: 'New Password',
                  ).copyWith(
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() => _showNewPassword = !_showNewPassword);
                      },
                      icon: Icon(
                        _showNewPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: subColor,
                      ),
                    ),
                  ),
              validator: (value) {
                final v = (value ?? '').trim();
                if (v.isEmpty) return 'New password is required';
                if (v.length < 6) {
                  return 'New password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _label('Confirm New Password', titleColor),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !_showConfirmPassword,
              style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
              decoration:
                  _inputDecoration(
                    inputFill,
                    border,
                    accent: accent,
                    hint: 'Confirm New Password',
                  ).copyWith(
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(
                          () => _showConfirmPassword = !_showConfirmPassword,
                        );
                      },
                      icon: Icon(
                        _showConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: subColor,
                      ),
                    ),
                  ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Confirm password is required';
                }
                if ((value ?? '').trim() !=
                    _newPasswordController.text.trim()) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _savingPassword ? null : _savePassword,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                icon: _savingPassword
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock_outline, size: 18),
                label: Text(_savingPassword ? 'Saving...' : 'Save Password'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, Color titleColor, {bool required = false}) {
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: titleColor,
            fontSize: 12.5,
            letterSpacing: 0.2,
          ),
        ),
        if (required) const SizedBox.shrink(),
      ],
    );
  }

  InputDecoration _inputDecoration(
    Color fill,
    Color border, {
    required Color accent,
    required String hint,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: border.withValues(alpha: 0.95)),
      filled: true,
      fillColor: fill,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
    );
  }

  BoxDecoration _cardDecoration({
    required Color surface,
    required Color border,
    required Color shadow,
  }) {
    return BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: border.withValues(alpha: 0.9)),
      boxShadow: [
        BoxShadow(
          color: shadow,
          blurRadius: 24,
          spreadRadius: 1,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Widget _sectionHeader({
    required String title,
    required String subtitle,
    required Color titleColor,
    required Color subtitleColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: titleColor,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: subtitleColor,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _cardTitle({
    required String title,
    required String subtitle,
    required Color titleColor,
    required Color subtitleColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: titleColor,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: subtitleColor,
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

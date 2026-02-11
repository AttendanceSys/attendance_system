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
        'gender': _gender,
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
    final surface = palette?.surface ?? scheme.surface;
    final inputFill = palette?.inputFill ?? scheme.surface;
    final border = palette?.border ?? Theme.of(context).dividerColor;
    final titleColor = palette?.textPrimary ?? scheme.onSurface;
    final subColor = palette?.textSecondary ?? scheme.onSurfaceVariant;
    final accent = const Color(0xFF8372FE);

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

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border.withValues(alpha: 0.65)),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 760;
                        final saveButton = FilledButton(
                          onPressed: _savingProfile ? null : _saveProfile,
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _savingProfile
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save Changes'),
                        );

                        final info = Row(
                          children: [
                            CircleAvatar(
                              radius: 38,
                              backgroundColor: accent,
                              child: Text(
                                initials.isEmpty ? 'T' : initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 26,
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
                                      fontSize: 30,
                                      fontWeight: FontWeight.w700,
                                      color: titleColor,
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
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: accent.withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Text(
                                      'Lecturer',
                                      style: TextStyle(
                                        color: accent,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );

                        if (isWide) {
                          return Row(
                            children: [
                              Expanded(child: info),
                              const SizedBox(width: 12),
                              saveButton,
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            info,
                            const SizedBox(height: 14),
                            Align(
                              alignment: Alignment.centerRight,
                              child: saveButton,
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Profile Information',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 980;
                      final leftCard = _buildProfileCard(
                        surface: surface,
                        border: border,
                        titleColor: titleColor,
                        subColor: subColor,
                        inputFill: inputFill,
                      );
                      final rightCard = _buildPasswordCard(
                        surface: surface,
                        border: border,
                        titleColor: titleColor,
                        subColor: subColor,
                        inputFill: inputFill,
                      );

                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: leftCard),
                            const SizedBox(width: 14),
                            Expanded(flex: 1, child: rightCard),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          leftCard,
                          const SizedBox(height: 14),
                          rightCard,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileCard({
    required Color surface,
    required Color border,
    required Color titleColor,
    required Color subColor,
    required Color inputFill,
  }) {
    final genders = const ['Male', 'Female'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border.withValues(alpha: 0.65)),
      ),
      child: Form(
        key: _profileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Full Name', titleColor, subColor, required: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: _fullNameController,
              onChanged: (_) => setState(() {}),
              decoration: _inputDecoration(inputFill, border, hint: 'Full Name'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Full name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _label('Username', titleColor, subColor, required: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: _usernameController,
              onChanged: (_) => setState(() {}),
              decoration: _inputDecoration(inputFill, border, hint: 'Username'),
              validator: (value) {
                final v = (value ?? '').trim();
                if (v.isEmpty) return 'Username is required';
                if (v.contains(' ')) return 'Username cannot contain spaces';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _label('Gender', titleColor, subColor),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: genders.contains(_gender) ? _gender : genders.first,
              decoration: _inputDecoration(inputFill, border, hint: 'Gender'),
              items: genders
                  .map(
                    (g) => DropdownMenuItem<String>(value: g, child: Text(g)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _gender = value);
              },
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
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border.withValues(alpha: 0.65)),
      ),
      child: Form(
        key: _passwordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change Password',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 12),
            _label('Current Password', titleColor, subColor),
            const SizedBox(height: 6),
            TextFormField(
              controller: _currentPasswordController,
              obscureText: !_showCurrentPassword,
              decoration: _inputDecoration(
                inputFill,
                border,
                hint: 'Current Password',
              ).copyWith(
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _showCurrentPassword = !_showCurrentPassword);
                  },
                  icon: Icon(
                    _showCurrentPassword ? Icons.visibility : Icons.visibility_off,
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
            const SizedBox(height: 12),
            _label('New Password', titleColor, subColor),
            const SizedBox(height: 6),
            TextFormField(
              controller: _newPasswordController,
              obscureText: !_showNewPassword,
              decoration: _inputDecoration(
                inputFill,
                border,
                hint: 'New Password',
              ).copyWith(
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _showNewPassword = !_showNewPassword);
                  },
                  icon: Icon(
                    _showNewPassword ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
              validator: (value) {
                final v = (value ?? '').trim();
                if (v.isEmpty) return 'New password is required';
                if (v.length < 6) return 'New password must be at least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _label('Confirm New Password', titleColor, subColor),
            const SizedBox(height: 6),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !_showConfirmPassword,
              decoration: _inputDecoration(
                inputFill,
                border,
                hint: 'Confirm New Password',
              ).copyWith(
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _showConfirmPassword = !_showConfirmPassword);
                  },
                  icon: Icon(
                    _showConfirmPassword ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Confirm password is required';
                }
                if ((value ?? '').trim() != _newPasswordController.text.trim()) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _savingPassword ? null : _savePassword,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8372FE),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _savingPassword
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Password'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, Color titleColor, Color subColor, {bool required = false}) {
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: titleColor,
            fontSize: 13,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 6),
          Text(
            '* Required',
            style: TextStyle(
              fontSize: 11,
              color: subColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration(Color fill, Color border, {required String hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: fill,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF8372FE), width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
    );
  }
}

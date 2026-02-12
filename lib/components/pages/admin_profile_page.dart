import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/session.dart';
import '../../theme/super_admin_theme.dart';

class AdminProfilePage extends StatefulWidget {
  final String roleFilter;
  final String roleLabel;

  const AdminProfilePage({
    super.key,
    required this.roleFilter,
    required this.roleLabel,
  });

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
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

  String _facultyName = '';
  String _originalUsername = '';
  String _storedPassword = '';
  String? _userDocId;
  String? _adminDocId;
  String _gender = 'Male';

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
        throw 'No active session found';
      }

      QueryDocumentSnapshot<Map<String, dynamic>>? userDoc;
      final userQ = await _firestore
          .collection('users')
          .where('username', isEqualTo: currentUsername)
          .where('role', isEqualTo: widget.roleFilter)
          .limit(1)
          .get();

      if (userQ.docs.isNotEmpty) {
        userDoc = userQ.docs.first;
      } else {
        final fallback = await _firestore
            .collection('users')
            .where('username', isEqualTo: currentUsername)
            .limit(1)
            .get();
        if (fallback.docs.isNotEmpty) userDoc = fallback.docs.first;
      }

      if (userDoc == null) {
        throw 'User record not found';
      }

      _userDocId = userDoc.id;
      final userData = userDoc.data();

      QueryDocumentSnapshot<Map<String, dynamic>>? adminDoc;
      final adminQ = await _firestore
          .collection('admins')
          .where('username', isEqualTo: currentUsername)
          .limit(1)
          .get();
      if (adminQ.docs.isNotEmpty) {
        adminDoc = adminQ.docs.first;
        _adminDocId = adminDoc.id;
      }

      final mergedName =
          (adminDoc?.data()['full_name'] ??
                  adminDoc?.data()['name'] ??
                  userData['full_name'] ??
                  userData['name'] ??
                  userData['display_name'] ??
                  currentUsername)
              .toString();
      final mergedUsername = (userData['username'] ?? currentUsername)
          .toString();

      final password =
          (userData['password'] ?? adminDoc?.data()['password'] ?? '')
              .toString();

      String facultyName = '';
      final facultyCandidate =
          adminDoc?.data()['faculty_ref'] ??
          adminDoc?.data()['faculty_id'] ??
          adminDoc?.data()['faculty'] ??
          userData['faculty_ref'] ??
          userData['faculty_id'] ??
          userData['faculty'];
      facultyName = await _resolveFacultyName(facultyCandidate);

      _fullNameController.text = mergedName;
      _usernameController.text = mergedUsername;
      final genderVal =
          (adminDoc?.data()['gender'] ?? userData['gender'] ?? 'Male')
              .toString();
      _gender = genderVal.isEmpty ? 'Male' : genderVal;
      _originalUsername = mergedUsername;
      _storedPassword = password;
      _facultyName = facultyName;

      Session.username = mergedUsername;
      Session.name = mergedName;
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

  Future<String> _resolveFacultyName(dynamic candidate) async {
    if (candidate == null) return '';
    try {
      DocumentReference? ref;
      if (candidate is DocumentReference) {
        ref = candidate;
      } else {
        final raw = candidate.toString().trim();
        if (raw.isEmpty) return '';
        if (raw.contains('/')) {
          final parts = raw.split('/').where((p) => p.isNotEmpty).toList();
          if (parts.length >= 2) {
            final col = parts[parts.length - 2];
            final id = parts.last;
            ref = _firestore.collection(col).doc(id);
          } else {
            ref = _firestore.collection('faculties').doc(parts.last);
          }
        } else {
          ref = _firestore.collection('faculties').doc(raw);
        }
      }
      if (ref == null) return '';
      final snap = await ref.get();
      if (!snap.exists) return '';
      final data = snap.data() as Map<String, dynamic>?;
      return (data?['faculty_name'] ?? data?['name'] ?? snap.id).toString();
    } catch (_) {
      return '';
    }
  }

  Future<void> _saveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;

    final nextName = _fullNameController.text.trim();
    final nextUsername = _usernameController.text.trim();
    if (nextName.isEmpty || nextUsername.isEmpty) return;

    setState(() => _savingProfile = true);
    try {
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

      if (_userDocId != null) {
        await _firestore.collection('users').doc(_userDocId).update({
          'username': nextUsername,
          'name': nextName,
          'full_name': nextName,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      if (_adminDocId != null) {
        await _firestore.collection('admins').doc(_adminDocId).update({
          'username': nextUsername,
          'full_name': nextName,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      _originalUsername = nextUsername;
      Session.username = nextUsername;
      Session.name = nextName;

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

    if (current != _storedPassword) {
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
      if (_userDocId != null) {
        await _firestore.collection('users').doc(_userDocId).update({
          'password': next,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
      if (_adminDocId != null) {
        await _firestore.collection('admins').doc(_adminDocId).update({
          'password': next,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      _storedPassword = next;
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
    final palette = Theme.of(context).extension<SuperAdminColors>();
    final scheme = Theme.of(context).colorScheme;
    final surface = palette?.surface ?? scheme.surface;
    final border = palette?.border ?? Theme.of(context).dividerColor;
    final inputFill = palette?.inputFill ?? scheme.surface;
    final titleColor = palette?.textPrimary ?? scheme.onSurface;
    final subColor = palette?.textSecondary ?? scheme.onSurfaceVariant;
    final accent = const Color(0xFF8372FE);

    final fullName = _fullNameController.text.trim();
    final username = _usernameController.text.trim();
    final displayName = fullName.isEmpty
        ? (username.isEmpty ? 'Admin' : username)
        : fullName;
    final displayUsername = username.isEmpty ? 'username' : username;
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
                        // Save button intentionally removed for read-only profile.
                        final saveButton = const SizedBox.shrink();

                        final info = Row(
                          children: [
                            CircleAvatar(
                              radius: 38,
                              backgroundColor: accent,
                              child: Text(
                                initials.isEmpty ? 'A' : initials,
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
                                      widget.roleLabel,
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
              readOnly: true,
              decoration: _inputDecoration(
                inputFill,
                border,
                hint: 'Full Name',
              ),
            ),
            const SizedBox(height: 12),
            _label('Username', titleColor, subColor, required: true),
            const SizedBox(height: 6),
            TextFormField(
              controller: _usernameController,
              readOnly: true,
              decoration: _inputDecoration(inputFill, border, hint: 'Username'),
            ),
            const SizedBox(height: 12),
            _label('Role', titleColor, subColor),
            const SizedBox(height: 6),
            TextFormField(
              initialValue: widget.roleLabel,
              readOnly: true,
              decoration: _inputDecoration(inputFill, border, hint: 'Role'),
            ),
            const SizedBox(height: 12),
            _label('Gender', titleColor, subColor),
            const SizedBox(height: 6),
            TextFormField(
              initialValue: _gender,
              readOnly: true,
              decoration: _inputDecoration(inputFill, border, hint: 'Gender'),
            ),
            if (_facultyName.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _label('Faculty', titleColor, subColor),
              const SizedBox(height: 6),
              TextFormField(
                initialValue: _facultyName,
                readOnly: true,
                decoration: _inputDecoration(
                  inputFill,
                  border,
                  hint: 'Faculty',
                ),
              ),
            ],
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
              decoration:
                  _inputDecoration(
                    inputFill,
                    border,
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
              decoration:
                  _inputDecoration(
                    inputFill,
                    border,
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
                      ),
                    ),
                  ),
              validator: (value) {
                final v = (value ?? '').trim();
                if (v.isEmpty) return 'New password is required';
                if (v.length < 6)
                  return 'New password must be at least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),
            _label('Confirm New Password', titleColor, subColor),
            const SizedBox(height: 6),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !_showConfirmPassword,
              decoration:
                  _inputDecoration(
                    inputFill,
                    border,
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

  Widget _label(
    String text,
    Color titleColor,
    Color subColor, {
    bool required = false,
  }) {
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

  InputDecoration _inputDecoration(
    Color fill,
    Color border, {
    required String hint,
  }) {
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

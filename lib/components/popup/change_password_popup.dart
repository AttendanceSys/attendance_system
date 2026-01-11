import 'package:flutter/material.dart';

/// Result returned from the dialog when the user successfully submits.
class ChangePasswordResult {
  final String oldPassword;
  final String newPassword;

  ChangePasswordResult({required this.oldPassword, required this.newPassword});
}

/// A dialog for changing password: old, new, confirm new.
/// Usage:
/// final result = await showDialog<ChangePasswordResult>(
///   context: context,
///   builder: (_) => ChangePasswordPopup(),
/// );
/// if (result != null) {
///   // perform backend update with result.oldPassword and result.newPassword
/// }
class ChangePasswordPopup extends StatefulWidget {
  /// If [onSubmit] is provided, the popup will call it when the user
  /// taps Save. The callback should return `null` on success or an
  /// error message string to display inline. If [onSubmit] is not
  /// provided the popup will return a [ChangePasswordResult] as before.
  final Future<String?> Function(String oldPassword, String newPassword)?
  onSubmit;

  const ChangePasswordPopup({super.key, this.onSubmit});

  @override
  State<ChangePasswordPopup> createState() => _ChangePasswordPopupState();
}

class _ChangePasswordPopupState extends State<ChangePasswordPopup> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _oldController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _showOld = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _loading = false;
  String? _serverError;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String hint, ThemeData theme) {
    final borderColor = theme.dividerColor;
    final fillColor = theme.inputDecorationTheme.fillColor ?? theme.cardColor;
    final primary = theme.colorScheme.primary;
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: fillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: primary, width: 1.4),
      ),
    );
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    final oldPass = _oldController.text.trim();
    final newPass = _newController.text.trim();

    // If parent provided an async onSubmit, call it and display inline errors.
    if (widget.onSubmit != null) {
      setState(() {
        _loading = true;
        _serverError = null;
      });
      widget.onSubmit!(oldPass, newPass)
          .then((err) {
            if (err == null) {
              // success: close dialog and return true using root navigator
              if (mounted) Navigator.of(context, rootNavigator: true).pop(true);
            } else {
              if (mounted) {
                setState(() {
                  _serverError = err;
                  _loading = false;
                });
              }
            }
          })
          .catchError((e) {
            if (mounted) {
              setState(() {
                _serverError = 'An error occurred';
                _loading = false;
              });
            }
          });
      return;
    }

    Navigator.of(
      context,
      rootNavigator: true,
    ).pop(ChangePasswordResult(oldPassword: oldPass, newPassword: newPass));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dialogWidth = MediaQuery.of(context).size.width > 600
        ? 480.0
        : double.infinity;

    return Dialog(
      elevation: 8,
      backgroundColor: Colors.transparent,
      child: Center(
        child: Container(
          width: dialogWidth,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.dialogBackgroundColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.dividerColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Change Password',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _oldController,
                  decoration: _inputDecoration('Current password', theme)
                      .copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showOld ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () => setState(() => _showOld = !_showOld),
                        ),
                      ),
                  obscureText: !_showOld,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter current password';
                    if (v.length < 6)
                      return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                if (_serverError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _serverError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newController,
                  decoration: _inputDecoration('New password', theme).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showNew ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _showNew = !_showNew),
                    ),
                  ),
                  obscureText: !_showNew,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter new password';
                    if (v.length < 6)
                      return 'New password must be at least 6 characters';
                    if (v == _oldController.text)
                      return 'New password must be different';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmController,
                  decoration: _inputDecoration('Confirm new password', theme)
                      .copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showConfirm
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () =>
                              setState(() => _showConfirm = !_showConfirm),
                        ),
                      ),
                  obscureText: !_showConfirm,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirm new password';
                    if (v != _newController.text)
                      return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(100, 40),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _loading ? null : _onSave,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(100, 40),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

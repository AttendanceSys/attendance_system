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
    final scheme = theme.colorScheme;
    final borderColor = scheme.outline.withOpacity(0.7);
    final fillColor = theme.inputDecorationTheme.fillColor ??
        (scheme.surfaceVariant.withOpacity(0.6));
    final primary = scheme.primary;
    return InputDecoration(
      labelText: hint,
      hintText: hint,
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      labelStyle: theme.textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
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

    final scheme = theme.colorScheme;

    return Dialog(
      elevation: 10,
      backgroundColor: Colors.transparent,
      child: Center(
        child: Container(
          width: dialogWidth,
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outline.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: scheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.lock_reset,
                        color: scheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Change Password',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Use at least 6 characters for your new password.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _oldController,
                  decoration: _inputDecoration('Current password', theme)
                      .copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showOld ? Icons.visibility : Icons.visibility_off,
                            color: scheme.onSurfaceVariant,
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
                        color: scheme.onSurfaceVariant,
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
                            color: scheme.onSurfaceVariant,
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
                        foregroundColor: scheme.onSurface,
                        side: BorderSide(color: scheme.outline),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _loading ? null : _onSave,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(100, 40),
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
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

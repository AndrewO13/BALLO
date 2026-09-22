import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/account_repository.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _accountRepository = AccountRepository();
  bool _isSubmitting = false;
  bool _isPasswordObscured = true;
  bool _isConfirmObscured = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    try {
      await _accountRepository.updatePassword(_passwordController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated')),
      );
      Navigator.of(context).pop();
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update password: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _sendResetEmail() async {
    final email = _accountRepository.currentEmail;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email on this account')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to $email')),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasEmailPassword = _accountRepository.hasEmailPasswordIdentity;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Change password',
          style: textTheme.headlineMedium,
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!hasEmailPassword) ...[
            Material(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(28),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Password managed by your sign-in provider',
                      style: textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You signed in with Google or Apple. Update your password '
                      'in that account\'s settings.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Text(
              'Choose a strong password with at least 8 characters.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _isPasswordObscured,
                    decoration: InputDecoration(
                      labelText: 'New password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordObscured
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _isPasswordObscured = !_isPasswordObscured,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.length < 8) {
                        return 'At least 8 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: _isConfirmObscured,
                    decoration: InputDecoration(
                      labelText: 'Confirm password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmObscured
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _isConfirmObscured = !_isConfirmObscured,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _onSave,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Update password'),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: _isSubmitting ? null : _sendResetEmail,
                child: const Text('Email me a reset link instead'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

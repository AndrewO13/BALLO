import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/account_repository.dart';

class AccountEmailPage extends StatefulWidget {
  const AccountEmailPage({super.key});

  @override
  State<AccountEmailPage> createState() => _AccountEmailPageState();
}

class _AccountEmailPageState extends State<AccountEmailPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _accountRepository = AccountRepository();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = _accountRepository.currentEmail ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final newEmail = _emailController.text.trim();
    if (newEmail == _accountRepository.currentEmail) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That is already your email address')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _accountRepository.updateEmail(newEmail);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Confirmation sent to $newEmail. Check your inbox to finish the change.',
          ),
        ),
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
        SnackBar(content: Text('Could not update email: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Email',
          style: textTheme.headlineMedium,
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Material(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current email',
                    style: textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _accountRepository.currentEmail ?? '—',
                    style: textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'New email',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'We will send a confirmation link to your new address. '
            'Your sign-in email updates after you confirm.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email address',
                hintText: 'you@example.com',
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return 'Enter an email address';
                final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                if (!emailRegex.hasMatch(email)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
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
                  : const Text('Update email'),
            ),
          ),
        ],
      ),
    );
  }
}

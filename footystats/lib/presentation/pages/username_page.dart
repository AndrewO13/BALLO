import 'package:flutter/material.dart';

import '../../core/constants/onboarding_steps.dart';
import '../../core/utils/content_moderation_guards.dart';
import '../../core/utils/username_rules.dart';
import '../../data/repositories/username_repository.dart';
import '../../domain/models/onboarding_draft.dart';
import '../widgets/onboarding_step_scaffold.dart';
import '../widgets/username_availability_field.dart';
import 'onboarding_account_type_page.dart';

class UsernamePage extends StatefulWidget {
  const UsernamePage({super.key, required this.draft});

  final OnboardingDraft draft;

  @override
  State<UsernamePage> createState() => _UsernamePageState();
}

class _UsernamePageState extends State<UsernamePage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  UsernameCheckResult _availability = const UsernameCheckResult(
    status: UsernameAvailability.idle,
  );
  bool _checkingModeration = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  bool get _canContinue =>
      !_checkingModeration &&
      _availability.status == UsernameAvailability.available;

  Future<void> _onContinue() async {
    if (!_canContinue) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final username = _usernameController.text.trim();
    final localError = UsernameRules.usernameError(username);
    if (localError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localError)),
      );
      return;
    }

    setState(() => _checkingModeration = true);
    try {
      await requireAllowedText(username, contentRef: 'username:$username');
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OnboardingAccountTypePage(
            draft: widget.draft.copyWith(username: username),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _checkingModeration = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      step: OnboardingStep.username,
      title: 'Choose your username',
      subtitle:
          'This is how others will find you on Ballo — on profiles, search and match reports.',
      bottomBar: OnboardingContinueButton(
        label: _checkingModeration ? 'Checking…' : 'Continue',
        onPressed: _canContinue ? _onContinue : null,
      ),
      child: Form(
        key: _formKey,
        child: UsernameAvailabilityField(
          controller: _usernameController,
          autofocus: true,
          onFieldSubmitted: (_) => _onContinue(),
          onAvailabilityChanged: (result) {
            setState(() => _availability = result);
          },
        ),
      ),
    );
  }
}

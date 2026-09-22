import 'package:flutter/material.dart';

import '../../core/constants/onboarding_steps.dart';
import '../../core/utils/content_moderation_guards.dart';
import '../../core/utils/username_rules.dart';
import '../../domain/models/onboarding_draft.dart';
import '../widgets/onboarding_step_scaffold.dart';
import 'username_page.dart';

class OnboardingPlayerNamePage extends StatefulWidget {
  const OnboardingPlayerNamePage({super.key});

  @override
  State<OnboardingPlayerNamePage> createState() =>
      _OnboardingPlayerNamePageState();
}

class _OnboardingPlayerNamePageState extends State<OnboardingPlayerNamePage> {
  final _formKey = GlobalKey<FormState>();
  final _playerNameController = TextEditingController();
  bool _checking = false;

  @override
  void dispose() {
    _playerNameController.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_checking) return;

    final name = _playerNameController.text.trim();
    final local = UsernameRules.offensiveContentError(name);
    if (local != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(local)));
      return;
    }

    setState(() => _checking = true);
    try {
      await requireAllowedText(name, contentRef: 'player_name');
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UsernamePage(
            draft: OnboardingDraft(playerName: name),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      step: OnboardingStep.playerName,
      accountType: null,
      title: 'Player name',
      subtitle: 'Give us the name you want on your Ballo card.',
      bottomBar: OnboardingContinueButton(
        label: _checking ? 'Checking…' : 'Continue',
        onPressed: _checking ? null : _onContinue,
      ),
      child: Form(
        key: _formKey,
        child: TextFormField(
          controller: _playerNameController,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Player name',
            hintText: 'e.g. Gareth Munroe',
          ),
          onFieldSubmitted: (_) => _onContinue(),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Enter your player name';
            }
            if (v.trim().length < 2) return 'At least 2 characters';
            return UsernameRules.offensiveContentError(v);
          },
        ),
      ),
    );
  }
}

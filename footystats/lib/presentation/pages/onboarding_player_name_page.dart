import 'package:flutter/material.dart';

import '../../core/constants/onboarding_steps.dart';
import '../../core/utils/content_moderation_guards.dart';
import '../../core/utils/username_rules.dart';
import '../../domain/models/onboarding_draft.dart';
import '../widgets/onboarding_step_scaffold.dart';
import 'username_page.dart';

class OnboardingPlayerNamePage extends StatefulWidget {
  const OnboardingPlayerNamePage({super.key, required this.draft});

  final OnboardingDraft draft;

  @override
  State<OnboardingPlayerNamePage> createState() =>
      _OnboardingPlayerNamePageState();
}

class _OnboardingPlayerNamePageState extends State<OnboardingPlayerNamePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _checking = false;

  bool get _isStaff => widget.draft.isTechnicalStaff;

  String get _title => _isStaff ? 'Your name' : 'Player name';

  String get _subtitle => _isStaff
      ? 'This is how players and clubs will see you on Ballo.'
      : 'Give us the name you want on your Ballo card.';

  String get _fieldLabel => _title;

  String get _hint => _isStaff ? 'e.g. Alex Rivera' : 'e.g. Gareth Munroe';

  String get _emptyError =>
      _isStaff ? 'Enter your name' : 'Enter your player name';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_checking) return;

    final name = _nameController.text.trim();
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
            draft: widget.draft.copyWith(playerName: name),
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
      accountType: widget.draft.accountType,
      title: _title,
      subtitle: _subtitle,
      bottomBar: OnboardingContinueButton(
        label: _checking ? 'Checking…' : 'Continue',
        onPressed: _checking ? null : _onContinue,
      ),
      child: Form(
        key: _formKey,
        child: TextFormField(
          controller: _nameController,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: _fieldLabel,
            hintText: _hint,
          ),
          onFieldSubmitted: (_) => _onContinue(),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return _emptyError;
            }
            if (v.trim().length < 2) return 'At least 2 characters';
            return UsernameRules.offensiveContentError(v);
          },
        ),
      ),
    );
  }
}

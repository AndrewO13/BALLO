import 'package:flutter/material.dart';

import '../../core/constants/onboarding_steps.dart';
import '../../domain/models/onboarding_draft.dart';
import '../widgets/onboarding_step_scaffold.dart';
import 'onboarding_country_page.dart';

const List<String> _positions = [
  'Goalkeeper',
  'Defender',
  'Midfielder',
  'Attacker',
];

class OnboardingPositionPage extends StatefulWidget {
  const OnboardingPositionPage({super.key, required this.draft});

  final OnboardingDraft draft;

  @override
  State<OnboardingPositionPage> createState() => _OnboardingPositionPageState();
}

class _OnboardingPositionPageState extends State<OnboardingPositionPage> {
  String? _selectedPosition;

  void _onContinue() {
    if (_selectedPosition == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OnboardingCountryPage(
          draft: widget.draft.copyWith(position: _selectedPosition!),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      step: OnboardingStep.position,
      accountType: widget.draft.accountType,
      title: 'Your position',
      subtitle:
          'What position do you usually play? This helps with stats and match reports.',
      bottomBar: OnboardingContinueButton(
        label: 'Continue',
        onPressed: _selectedPosition != null ? _onContinue : null,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: _positions.map((pos) {
          final isSelected = _selectedPosition == pos;
          return ChoiceChip(
            label: Text(pos),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                _selectedPosition = selected ? pos : null;
              });
            },
          );
        }).toList(),
      ),
    );
  }
}

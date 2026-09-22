import 'package:flutter/material.dart';

import '../../core/constants/onboarding_steps.dart';
import '../../domain/models/onboarding_draft.dart';
import '../widgets/country_picker_section.dart';
import '../widgets/onboarding_step_scaffold.dart';
import 'signup_page.dart';

class OnboardingCountryPage extends StatefulWidget {
  const OnboardingCountryPage({super.key, required this.draft});

  final OnboardingDraft draft;

  @override
  State<OnboardingCountryPage> createState() => _OnboardingCountryPageState();
}

class _OnboardingCountryPageState extends State<OnboardingCountryPage> {
  String? _selectedCountryCode;

  void _onNext() {
    if (_selectedCountryCode == null) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignUpPage(
          draft: widget.draft.copyWith(countryCode: _selectedCountryCode!),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      step: OnboardingStep.country,
      accountType: widget.draft.accountType,
      title: 'Your location',
      subtitle:
          'Select your country. This helps connect you with local leagues and players.',
      bottomBar: OnboardingContinueButton(
        label: 'Continue',
        onPressed: _selectedCountryCode != null ? _onNext : null,
      ),
      child: CountryPickerSection(
        showSectionTitle: false,
        maxListHeight: 240,
        selectedCountryCode: _selectedCountryCode,
        onCountrySelected: (code) {
          setState(() => _selectedCountryCode = code);
        },
      ),
    );
  }
}

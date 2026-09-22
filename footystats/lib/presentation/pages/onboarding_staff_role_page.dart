import 'package:flutter/material.dart';

import '../../core/constants/onboarding_steps.dart';
import '../../domain/models/account_type.dart';
import '../../domain/models/onboarding_draft.dart';
import '../widgets/onboarding_step_scaffold.dart';
import 'signup_page.dart';

class OnboardingStaffRolePage extends StatefulWidget {
  const OnboardingStaffRolePage({super.key, required this.draft});

  final OnboardingDraft draft;

  @override
  State<OnboardingStaffRolePage> createState() =>
      _OnboardingStaffRolePageState();
}

class _OnboardingStaffRolePageState extends State<OnboardingStaffRolePage> {
  StaffRole? _selectedRole;
  final _otherController = TextEditingController();

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  bool get _canContinue {
    if (_selectedRole == null) return false;
    if (_selectedRole == StaffRole.other) {
      return _otherController.text.trim().length >= 2;
    }
    return true;
  }

  void _onContinue() {
    if (!_canContinue) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignUpPage(
          draft: widget.draft.copyWith(
            staffRole: _selectedRole,
            staffRoleOther: _selectedRole == StaffRole.other
                ? _otherController.text.trim()
                : '',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return OnboardingStepScaffold(
      step: OnboardingStep.staffRole,
      accountType: AccountType.technicalStaff,
      title: 'Your role',
      subtitle:
          'How do you work in football? This helps players understand who is looking at their page.',
      bottomBar: OnboardingContinueButton(
        label: 'Continue',
        onPressed: _canContinue ? _onContinue : null,
      ),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: StaffRole.values.map((role) {
              final isSelected = _selectedRole == role;
              return ChoiceChip(
                label: Text(role.label),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedRole = selected ? role : null;
                  });
                },
              );
            }).toList(),
          ),
          if (_selectedRole == StaffRole.other) ...[
            const SizedBox(height: 20),
            TextField(
              controller: _otherController,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Specify your role',
                hintText: 'e.g. Analyst, Physio, Kit manager',
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.55),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _onContinue(),
            ),
          ],
        ],
      ),
    );
  }
}

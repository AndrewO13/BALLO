import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/onboarding_steps.dart';
import '../../core/utils/auth_helpers.dart';
import '../../data/repositories/onboarding_repository.dart';
import '../../domain/models/onboarding_draft.dart';
import '../widgets/onboarding_step_scaffold.dart';
import '../widgets/content_safety_sheets.dart';
import 'onboarding_player_name_page.dart';
import 'onboarding_profile_image_page.dart';

class VerifyCodePage extends StatefulWidget {
  const VerifyCodePage({
    super.key,
    required this.email,
    required this.draft,
  });

  final String email;
  final OnboardingDraft draft;

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _onboardingRepository = OnboardingRepository();

  bool _isSubmitting = false;
  bool _emailConfirmed = false;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted || _emailConfirmed) return;
      if (data.event == AuthChangeEvent.signedIn && data.session != null) {
        unawaited(_completeVerification());
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _completeVerification() async {
    if (_emailConfirmed || !mounted) return;
    _emailConfirmed = true;

    try {
      await showCommunityGuidelinesModal(context, requireAccept: true);
      if (!mounted) return;

      if (widget.draft.hasPreAuthProfileData) {
        await _onboardingRepository.saveDraftProfile(widget.draft);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OnboardingProfileImagePage(draft: widget.draft),
          ),
        );
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingPlayerNamePage()),
        (route) => false,
      );
    } catch (error) {
      _emailConfirmed = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save your profile: $error')),
      );
    }
  }

  Future<void> _onSubmit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() => _isSubmitting = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.verifyOTP(
        email: widget.email,
        token: _codeController.text.trim(),
        type: OtpType.signup,
      );

      await _completeVerification();
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is AuthException
                ? error.message
                : 'Something went wrong while verifying your code.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _resendCode() async {
    try {
      await resendSignupVerification(widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification code resent.')),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not resend the code.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      step: OnboardingStep.verifyEmail,
      accountType: widget.draft.accountType,
      title: 'Verify your email',
      subtitle:
          "We've sent a link and code to ${widget.email}. Tap Confirm account in the email, or enter the code below.",
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnboardingContinueButton(
            label: 'Continue',
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _onSubmit,
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: _isSubmitting ? null : _resendCode,
              child: const Text('Resend code'),
            ),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: TextFormField(
          controller: _codeController,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          enabled: !_isSubmitting,
          decoration: const InputDecoration(
            labelText: 'Verification code',
          ),
          textAlign: TextAlign.center,
          onFieldSubmitted: (_) {
            if (!_isSubmitting) _onSubmit();
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Enter the code';
            }
            return null;
          },
        ),
      ),
    );
  }
}

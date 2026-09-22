import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/adaptive/adaptive.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/auth_constants.dart';
import '../../core/constants/onboarding_steps.dart';
import '../../core/utils/auth_helpers.dart';
import '../../data/repositories/onboarding_repository.dart';
import '../../domain/models/onboarding_draft.dart';
import '../widgets/auth_or_divider.dart';
import '../widgets/content_safety_sheets.dart';
import '../widgets/onboarding_progress_app_bar.dart';
import '../widgets/social_sign_in_button.dart';
import 'login_page.dart';
import 'onboarding_profile_image_page.dart';
import 'verify_code_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key, required this.draft});

  final OnboardingDraft draft;

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSubmitting = false;
  bool _isOAuthLoading = false;
  OAuthProvider? _oauthProviderLoading;
  String? _emailError;
  bool _showVerificationHelp = false;
  bool _isPasswordObscured = true;
  bool _isConfirmPasswordObscured = true;

  StreamSubscription<AuthState>? _authSubscription;
  bool _awaitingOAuthSignIn = false;
  final _onboardingRepository = OnboardingRepository();

  bool get _isBusy => _isSubmitting || _isOAuthLoading;

  @override
  void initState() {
    super.initState();
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      // Email sign-up verifies on a later screen; only OAuth should jump home.
      if (_awaitingOAuthSignIn &&
          data.event == AuthChangeEvent.signedIn &&
          data.session != null) {
        _awaitingOAuthSignIn = false;
        _onOAuthComplete();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onOAuthComplete() async {
    try {
      await showCommunityGuidelinesModal(context, requireAccept: true);
      if (!mounted) return;
      await _onboardingRepository.saveDraftProfile(widget.draft);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OnboardingProfileImagePage(draft: widget.draft),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save your profile: $error')),
      );
    }
  }

  Future<void> _resendVerificationAndContinue() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await resendSignupVerification(email);
      if (!mounted) return;
      _authSubscription?.cancel();
      _authSubscription = null;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VerifyCodePage(
            email: email,
            draft: widget.draft,
          ),
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send verification code.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _onSubmit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() => _isSubmitting = true);

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        emailRedirectTo: kOAuthRedirectUrl,
      );

      if (!mounted) return;

      if (response.user?.identities?.isEmpty ?? false) {
        setState(() {
          _emailError = 'An account with this email already exists';
          _showVerificationHelp = true;
        });
        _formKey.currentState?.validate();
        return;
      }

      _authSubscription?.cancel();
      _authSubscription = null;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => VerifyCodePage(
            email: _emailController.text.trim(),
            draft: widget.draft,
          ),
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      if (isEmailNotConfirmedError(error)) {
        await _resendVerificationAndContinue();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong while creating your account.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _signInWithOAuth(OAuthProvider provider) async {
    if (_isBusy) return;

    setState(() {
      _awaitingOAuthSignIn = true;
      _isOAuthLoading = true;
      _oauthProviderLoading = provider;
    });

    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: kOAuthRedirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } on AuthException catch (error) {
      _awaitingOAuthSignIn = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      _awaitingOAuthSignIn = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not start sign up. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOAuthLoading = false;
          _oauthProviderLoading = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final showAppleSignIn = !kIsWeb;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: OnboardingProgressAppBar(
        step: OnboardingStep.signUp,
        accountType: widget.draft.accountType,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppResponsive.horizontalInset(context, design: 24),
                8 * AppResponsive.layoutScaleOf(context),
                AppResponsive.horizontalInset(context, design: 24),
                32 * AppResponsive.layoutScaleOf(context),
              ),
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: SvgPicture.asset(
                      AppAssets.balloLogo,
                      height: 36,
                      semanticsLabel: 'Ballo',
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Now let\'s\ncreate your account',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "We'll send a verification code to confirm your email.",
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SocialSignInButton(
                    label: 'Continue with Google',
                    icon: const FaIcon(FontAwesomeIcons.google, size: 20),
                    isLoading: _oauthProviderLoading == OAuthProvider.google,
                    onPressed: _isBusy
                        ? null
                        : () => _signInWithOAuth(OAuthProvider.google),
                  ),
                  if (showAppleSignIn) ...[
                    const SizedBox(height: 12),
                    SocialSignInButton(
                      label: 'Continue with Apple',
                      icon: const FaIcon(FontAwesomeIcons.apple, size: 22),
                      isLoading: _oauthProviderLoading == OAuthProvider.apple,
                      onPressed: _isBusy
                          ? null
                          : () => _signInWithOAuth(OAuthProvider.apple),
                    ),
                  ],
                  const SizedBox(height: 28),
                  const AuthOrDivider(),
                  const SizedBox(height: 28),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          enabled: !_isBusy,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'you@example.com',
                          ),
                          onChanged: (_) {
                            if (_emailError != null || _showVerificationHelp) {
                              setState(() {
                                _emailError = null;
                                _showVerificationHelp = false;
                              });
                            }
                          },
                          validator: (value) {
                            if (_emailError != null) {
                              return _emailError;
                            }
                            if (value == null || value.isEmpty) {
                              return 'Enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _isPasswordObscured,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.newPassword],
                          enabled: !_isBusy,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _isPasswordObscured = !_isPasswordObscured;
                                });
                              },
                              icon: Icon(
                                _isPasswordObscured
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              tooltip: _isPasswordObscured
                                  ? 'Show password'
                                  : 'Hide password',
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Create a password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _isConfirmPasswordObscured,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.newPassword],
                          enabled: !_isBusy,
                          onFieldSubmitted: (_) {
                            if (!_isBusy) _onSubmit();
                          },
                          decoration: InputDecoration(
                            labelText: 'Confirm password',
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _isConfirmPasswordObscured =
                                      !_isConfirmPasswordObscured;
                                });
                              },
                              icon: Icon(
                                _isConfirmPasswordObscured
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              tooltip: _isConfirmPasswordObscured
                                  ? 'Show password'
                                  : 'Hide password',
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        if (_showVerificationHelp) ...[
                          const SizedBox(height: 12),
                          Material(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    "Haven't verified yet?",
                                    style: textTheme.titleSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'We can send a new confirmation code to this email.',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                    onPressed:
                                        _isBusy ? null : _resendVerificationAndContinue,
                                    child: const Text('Resend verification code'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _isBusy ? null : _onSubmit,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: _isSubmitting
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.onPrimary,
                                  ),
                                )
                              : const Text('Continue'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: _isBusy
                          ? null
                          : () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const LoginPage(),
                                ),
                              );
                            },
                      child: const Text('Already have an account? Log in'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

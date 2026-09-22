import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/adaptive/adaptive.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/auth_constants.dart';
import '../../core/utils/auth_helpers.dart';
import '../../domain/models/onboarding_draft.dart';
import '../widgets/auth_or_divider.dart';
import '../widgets/social_sign_in_button.dart';
import 'home_page.dart';
import 'onboarding_player_name_page.dart';
import 'verify_code_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  bool _isResetting = false;
  bool _isPasswordObscured = true;
  bool _isOAuthLoading = false;
  OAuthProvider? _oauthProviderLoading;

  StreamSubscription<AuthState>? _authSubscription;

  bool get _isBusy => _isSubmitting || _isOAuthLoading;

  @override
  void initState() {
    super.initState();
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      // Guests are already signed in anonymously. The auth stream replays
      // that `signedIn` event to new listeners, which would bounce this
      // page straight back to HomePage.
      final session = data.session;
      if (data.event == AuthChangeEvent.signedIn &&
          session != null &&
          !session.user.isAnonymous) {
        _goToHome();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goToHome() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  Future<void> _openEmailVerification(String email) async {
    final pageContext = context;
    final send = await showDialog<bool>(
      context: pageContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Verify your email'),
        content: Text(
          'Your account at $email is not verified yet. '
          'We can send a new confirmation code so you can finish signing up.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Send code'),
          ),
        ],
      ),
    );

    if (send != true || !pageContext.mounted) return;

    setState(() => _isSubmitting = true);
    try {
      await resendSignupVerification(email);
      if (!pageContext.mounted) return;
      Navigator.of(pageContext).push(
        MaterialPageRoute(
          builder: (_) => VerifyCodePage(
            email: email,
            draft: const OnboardingDraft(),
          ),
        ),
      );
    } on AuthException catch (error) {
      if (!pageContext.mounted) return;
      ScaffoldMessenger.of(pageContext).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!pageContext.mounted) return;
      ScaffoldMessenger.of(pageContext).showSnackBar(
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
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      _goToHome();
    } on AuthException catch (error) {
      if (!mounted) return;
      if (isEmailNotConfirmedError(error)) {
        setState(() => _isSubmitting = false);
        await _openEmailVerification(_emailController.text.trim());
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong while logging in.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _onForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email to reset password.')),
      );
      return;
    }

    setState(() => _isResetting = true);
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send reset email.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isResetting = false);
      }
    }
  }

  Future<void> _signInWithOAuth(OAuthProvider provider) async {
    if (_isBusy) return;

    setState(() {
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not start sign in. Please try again.'),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                    'Welcome back',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Log in to see your latest tackles, assists and clean sheets.',
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
                          validator: (value) {
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
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          enabled: !_isBusy,
                          onFieldSubmitted: (_) {
                            if (!_isBusy) _onSubmit();
                          },
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
                              return 'Enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed:
                                _isResetting || _isBusy ? null : _onForgotPassword,
                            child: _isResetting
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.primary,
                                    ),
                                  )
                                : const Text('Forgot password?'),
                          ),
                        ),
                        const SizedBox(height: 8),
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
                              : const Text('Log in'),
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
                                  builder: (_) => const OnboardingPlayerNamePage(),
                                ),
                              );
                            },
                      child: const Text("Don't have an account? Sign up"),
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

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../widgets/content_safety_sheets.dart';
import 'account_email_page.dart';
import 'change_password_page.dart';
import 'edit_profile_page.dart';
import 'welcome_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _showInfoDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _openExternalUrl(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $uri')),
      );
    }
  }

  Future<void> _openEditProfile(BuildContext context) async {
    final pageContext = context;
    final profile = await UserProfileRepository().getCurrentProfile();
    if (!pageContext.mounted) return;
    if (profile == null) {
      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(content: Text('Sign in to edit your profile')),
      );
      return;
    }
    await Navigator.of(pageContext).push(
      MaterialPageRoute(
        builder: (_) => EditProfilePage(profile: profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        centerTitle: false,
        automaticallyImplyLeading: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _SettingsSection(
            title: 'Account',
            items: [
              _SettingsItem(
                icon: Icons.person_outline,
                title: 'Edit Profile',
                subtitle: 'Name, photo, position, socials, delete account',
                onTap: () => _openEditProfile(context),
              ),
              _SettingsItem(
                icon: Icons.email_outlined,
                title: 'Email',
                subtitle: email ?? 'Not set',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AccountEmailPage(),
                    ),
                  );
                },
              ),
              _SettingsItem(
                icon: Icons.lock_outline,
                title: 'Change Password',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChangePasswordPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SettingsSection(
            title: 'About',
            items: [
              _SettingsItem(
                icon: Icons.info_outline,
                title: 'About Ballo',
                onTap: () {
                  _showInfoDialog(
                    context,
                    'About Ballo',
                    'Ballo helps you track matches, player stats, '
                        'and league performance.',
                  );
                },
              ),
              _SettingsItem(
                icon: Icons.help_outline,
                title: 'Help & Support',
                subtitle: AppConstants.supportEmail,
                onTap: () async {
                  final uri = Uri(
                    scheme: 'mailto',
                    path: AppConstants.supportEmail,
                    queryParameters: {'subject': 'Ballo support'},
                  );
                  await launchUrl(uri);
                },
              ),
              _SettingsItem(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                subtitle: AppConstants.privacyPolicyUri.toString(),
                onTap: () => _openExternalUrl(
                  context,
                  AppConstants.privacyPolicyUri,
                ),
              ),
              _SettingsItem(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                subtitle: AppConstants.termsOfServiceUri.toString(),
                onTap: () => _openExternalUrl(
                  context,
                  AppConstants.termsOfServiceUri,
                ),
              ),
              _SettingsItem(
                icon: Icons.gavel_outlined,
                title: 'Community Guidelines',
                onTap: () => showCommunityGuidelinesModal(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SettingsSection(
            title: 'Actions',
            items: [
              _SettingsItem(
                icon: Icons.logout_outlined,
                title: 'Sign Out',
                titleColor: colorScheme.error,
                onTap: () {
                  final pageContext = context;
                  showDialog(
                    context: pageContext,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Sign Out'),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.of(dialogContext).pop();
                            try {
                              await Supabase.instance.client.auth.signOut();
                              if (!pageContext.mounted) return;
                              Navigator.of(pageContext).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const WelcomePage(),
                                ),
                                (route) => false,
                              );
                            } catch (error) {
                              if (!pageContext.mounted) return;
                              ScaffoldMessenger.of(pageContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Error signing out: ${error.toString()}',
                                  ),
                                ),
                              );
                            }
                          },
                          child: Text(
                            'Sign Out',
                            style: TextStyle(
                              color: Theme.of(pageContext).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;

  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                items[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.titleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        leading: Icon(
          icon,
          color: titleColor ?? colorScheme.onSurface,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: titleColor ?? colorScheme.onSurface,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            : null,
        trailing: Icon(
          Icons.chevron_right,
          color: colorScheme.onSurfaceVariant,
        ),
        onTap: onTap,
      ),
    );
  }
}

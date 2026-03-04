import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'welcome_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _showComingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label coming soon')),
    );
  }

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

  @override
  Widget build(BuildContext context) {
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
                onTap: () {
                  _showComingSoon(context, 'Edit profile');
                },
              ),
              _SettingsItem(
                icon: Icons.email_outlined,
                title: 'Email',
                subtitle: 'user@example.com',
                onTap: () {
                  _showComingSoon(context, 'Email settings');
                },
              ),
              _SettingsItem(
                icon: Icons.lock_outline,
                title: 'Change Password',
                onTap: () {
                  _showComingSoon(context, 'Change password');
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SettingsSection(
            title: 'Preferences',
            items: [
              _SettingsItem(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                onTap: () {
                  _showComingSoon(context, 'Notifications');
                },
              ),
              _SettingsItem(
                icon: Icons.dark_mode_outlined,
                title: 'Theme',
                subtitle: 'System',
                onTap: () {
                  _showComingSoon(context, 'Theme settings');
                },
              ),
              _SettingsItem(
                icon: Icons.language_outlined,
                title: 'Language',
                subtitle: 'English',
                onTap: () {
                  _showComingSoon(context, 'Language settings');
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
                title: 'About FootyStats',
                onTap: () {
                  _showInfoDialog(
                    context,
                    'About FootyStats',
                    'FootyStats helps you track matches, player stats, '
                        'and league performance.',
                  );
                },
              ),
              _SettingsItem(
                icon: Icons.help_outline,
                title: 'Help & Support',
                onTap: () {
                  _showInfoDialog(
                    context,
                    'Help & Support',
                    'Reach out to support@footystats.app for assistance.',
                  );
                },
              ),
              _SettingsItem(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () {
                  _showInfoDialog(
                    context,
                    'Privacy Policy',
                    'Your data is handled securely. Full policy coming soon.',
                  );
                },
              ),
              _SettingsItem(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                onTap: () {
                  _showInfoDialog(
                    context,
                    'Terms of Service',
                    'Please use the app responsibly. Full terms coming soon.',
                  );
                },
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
                titleColor: Theme.of(context).colorScheme.error,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Sign Out'),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            try {
                              await Supabase.instance.client.auth.signOut();
                              if (!context.mounted) return;
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const WelcomePage(),
                                ),
                                (route) => false,
                              );
                            } catch (error) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
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
                              color: Theme.of(context).colorScheme.error,
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
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(children: items),
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
    return ListTile(
      leading: Icon(
        icon,
        color: titleColor ?? Theme.of(context).colorScheme.onSurface,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: Icon(
        Icons.chevron_right,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

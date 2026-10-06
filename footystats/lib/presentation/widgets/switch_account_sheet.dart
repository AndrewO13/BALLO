import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/widgets/media_placeholders.dart';
import '../../data/repositories/device_accounts_repository.dart';
import '../../domain/models/device_account.dart';
import '../pages/home_page.dart';
import '../pages/welcome_page.dart';

Future<void> showSwitchAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _SwitchAccountSheet(),
  );
}

class _SwitchAccountSheet extends StatefulWidget {
  const _SwitchAccountSheet();

  @override
  State<_SwitchAccountSheet> createState() => _SwitchAccountSheetState();
}

class _SwitchAccountSheetState extends State<_SwitchAccountSheet> {
  final _repo = DeviceAccountsRepository();
  List<DeviceAccount> _accounts = const [];
  bool _loading = true;
  String? _busyUserId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _repo.captureCurrent();
    final accounts = await _repo.list();
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _loading = false;
    });
  }

  Future<void> _switchTo(DeviceAccount account) async {
    final currentId = Supabase.instance.client.auth.currentUser?.id;
    if (account.userId == currentId) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _busyUserId = account.userId);
    try {
      await _repo.switchTo(account);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => HomePage(key: ValueKey(account.userId)),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busyUserId = null);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is AuthException
                ? error.message
                : 'Could not switch account. Sign in again.',
          ),
        ),
      );
    }
  }

  Future<void> _addAccount() async {
    await _repo.captureCurrent();
    if (!mounted) return;
    final accounts = await _repo.list();
    if (!mounted) return;
    if (accounts.length >= DeviceAccountsRepository.maxStoredAccounts) {
      await _showAccountLimitWall();
      return;
    }
    Navigator.of(context).pop();
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const WelcomePage()));
  }

  Future<void> _showAccountLimitWall() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            icon: Icon(
              Icons.block,
              size: 36,
              color: colorScheme.onSurface,
            ),
            title: const Text('Account limit reached'),
            content: Text(
              'This device can keep ${DeviceAccountsRepository.maxStoredAccounts} '
              'accounts signed in at once. Sign out of one to add another.',
              style: textTheme.bodyMedium,
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentId = Supabase.instance.client.auth.currentUser?.id;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 0, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Switch account', style: textTheme.titleMedium),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: CircularProgressIndicator(),
              )
            else ...[
              for (final account in _accounts)
                _AccountTile(
                  account: account,
                  selected: account.userId == currentId,
                  busy: _busyUserId == account.userId,
                  onTap: _busyUserId == null ? () => _switchTo(account) : null,
                ),
              ListTile(
                enabled: _busyUserId == null,
                leading: CircleAvatar(
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.add, color: colorScheme.onSurface),
                ),
                title: const Text('Add account'),
                onTap: _busyUserId == null ? _addAccount : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.selected,
    required this.busy,
    required this.onTap,
  });

  final DeviceAccount account;
  final bool selected;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = account.imageUrl?.trim() ?? '';
    final hasImage = resolvePlayerImagePath(imageUrl) != null;

    return ListTile(
      leading: hasImage
          ? buildPlayerAvatar(
              imagePath: imageUrl,
              size: 40,
              backgroundColor: colorScheme.primaryContainer,
              iconColor: colorScheme.onPrimaryContainer,
            )
          : CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              child: Text(account.initial),
            ),
      title: Text(
        account.displayHandle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : selected
          ? Icon(Icons.check, color: colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}

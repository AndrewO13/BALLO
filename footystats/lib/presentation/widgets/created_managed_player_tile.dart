import 'package:flutter/material.dart';

import '../../core/widgets/media_placeholders.dart';
import '../../data/repositories/managed_players_repository.dart';
import '../../domain/models/managed_player.dart';

class CreatedManagedPlayerTile extends StatelessWidget {
  const CreatedManagedPlayerTile({
    super.key,
    required this.player,
    required this.onOpenProfile,
    required this.onSetLogin,
    this.onEdit,
  });

  final ManagedPlayer player;
  final VoidCallback onOpenProfile;
  final VoidCallback onSetLogin;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.hardEdge,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: InkWell(
        splashColor: colorScheme.primary.withAlpha(30),
        onTap: onOpenProfile,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              buildPlayerAvatar(imagePath: player.imageUrl, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(player.playerName, style: textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (player.username.isNotEmpty) '@${player.username}',
                        if (player.position != null) player.position,
                      ].join(' · '),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      player.hasLogin
                          ? 'Login ready — they can sign in with the email you set'
                          : 'No login yet',
                      style: textTheme.bodySmall?.copyWith(
                        color: player.hasLogin
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (player.canCreatorEdit && onEdit != null)
                    TextButton(
                      onPressed: onEdit,
                      child: const Text('Edit'),
                    ),
                  TextButton(
                    onPressed: onSetLogin,
                    child: Text(player.hasLogin ? 'Update login' : 'Set login'),
                  ),
                ],
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> showSetManagedPlayerLoginDialog({
  required BuildContext context,
  required ManagedPlayer player,
}) async {
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => _SetManagedPlayerLoginDialog(player: player),
  );
  return saved == true;
}

class _SetManagedPlayerLoginDialog extends StatefulWidget {
  const _SetManagedPlayerLoginDialog({required this.player});

  final ManagedPlayer player;

  @override
  State<_SetManagedPlayerLoginDialog> createState() =>
      _SetManagedPlayerLoginDialogState();
}

class _SetManagedPlayerLoginDialogState
    extends State<_SetManagedPlayerLoginDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _repository = ManagedPlayersRepository();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _saving = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await _repository.enableLogin(
        playerId: widget.player.id,
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.player.hasLogin ? 'Update login' : 'Set login'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add the email and a temporary password for ${widget.player.playerName}. '
                'They can use these to sign in and claim the account.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Enter an email';
                  if (!email.contains('@') || !email.contains('.')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                enabled: !_saving,
                decoration: InputDecoration(
                  labelText: 'Temporary password',
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Create a temporary password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                enabled: !_saving,
                onFieldSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => _obscureConfirm = !_obscureConfirm);
                    },
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Confirm the password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

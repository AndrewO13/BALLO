import 'package:flutter/material.dart';

const _kCreateSeasonHelperText =
    'Start and end dates are set automatically from season matches.';

/// Bottom sheet for naming a new league season.
/// Pops `{'name': String}` on success, or `null` when dismissed.
class CreateSeasonBottomSheet extends StatefulWidget {
  const CreateSeasonBottomSheet({
    super.key,
    this.helperText = _kCreateSeasonHelperText,
  });

  final String helperText;

  @override
  State<CreateSeasonBottomSheet> createState() => _CreateSeasonBottomSheetState();
}

class _CreateSeasonBottomSheetState extends State<CreateSeasonBottomSheet> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a season name')),
      );
      return;
    }
    Navigator.of(context).pop({'name': name});
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create season',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Season name',
              hintText: 'e.g. Season 2024',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          Text(
            widget.helperText,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text('Create'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

Future<Map<String, dynamic>?> showCreateSeasonBottomSheet(
  BuildContext context, {
  String helperText = _kCreateSeasonHelperText,
}) {
  return showModalBottomSheet<Map<String, dynamic>?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => CreateSeasonBottomSheet(helperText: helperText),
  );
}

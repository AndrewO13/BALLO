import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_assets.dart';
import '../../core/utils/content_moderation_guards.dart';
import '../../core/utils/username_rules.dart';
import '../../core/widgets/media_placeholders.dart';
import '../../data/repositories/managed_players_repository.dart';
import '../../data/repositories/username_repository.dart';
import '../../domain/models/managed_player.dart';
import '../widgets/media_access_sheet.dart';
import '../widgets/username_availability_field.dart';

const _positions = ['Goalkeeper', 'Defender', 'Midfielder', 'Attacker'];

const _avatarAssets = [
  AppAssets.avatar13,
  AppAssets.avatar18,
  AppAssets.avatar20,
  AppAssets.avatar1,
  AppAssets.avatar6,
  AppAssets.avatar8,
  AppAssets.avatar10,
  AppAssets.avatar19,
  AppAssets.avatar21,
  AppAssets.avatar23,
  AppAssets.avatar22,
  AppAssets.avatar26,
  AppAssets.avatar28,
  AppAssets.avatar29,
  AppAssets.avatar24,
];

class CreatePlayersPage extends StatefulWidget {
  const CreatePlayersPage({super.key});

  @override
  State<CreatePlayersPage> createState() => _CreatePlayersPageState();
}

class _CreatePlayersPageState extends State<CreatePlayersPage> {
  final _formKey = GlobalKey<FormState>();
  final _repository = ManagedPlayersRepository();
  final List<_PlayerDraft> _drafts = [_PlayerDraft()];
  bool _isSubmitting = false;

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  void _addDraft() {
    if (_drafts.length >= 20) return;
    setState(() => _drafts.add(_PlayerDraft()));
  }

  void _removeDraft(_PlayerDraft draft) {
    if (_drafts.length <= 1) return;
    setState(() {
      _drafts.remove(draft);
      draft.dispose();
    });
  }

  Future<void> _onCreate() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final usernames = <String>[];
    final inputs = <ManagedPlayerDraftInput>[];
    for (var i = 0; i < _drafts.length; i++) {
      final draft = _drafts[i];
      final name = draft.nameController.text.trim();
      final username = UsernameRules.normalize(draft.usernameController.text);
      final nameBlock = UsernameRules.offensiveContentError(name);
      if (nameBlock != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(nameBlock)));
        return;
      }
      if (draft.availability.status != UsernameAvailability.available) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wait until every username is available')),
        );
        return;
      }
      final key = username.toLowerCase();
      if (usernames.contains(key)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Username @$username is used more than once')),
        );
        return;
      }
      if (draft.position == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Select a position for player ${i + 1}'),
          ),
        );
        return;
      }
      final imageUrl = draft.imageUrl?.trim() ?? '';
      if (imageUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Add a photo for player ${i + 1} so match officials can identify them',
            ),
          ),
        );
        return;
      }
      usernames.add(key);
      inputs.add(
        ManagedPlayerDraftInput(
          playerName: name,
          username: username,
          position: draft.position!,
          imageUrl: imageUrl,
        ),
      );
    }

    setState(() => _isSubmitting = true);
    try {
      for (final input in inputs) {
        await requireAllowedText(input.playerName, contentRef: 'player_name');
        await requireAllowedText(input.username, contentRef: 'username:${input.username}');
      }
      final created = await _repository.createPlayers(inputs);
      if (!mounted) return;
      for (final draft in _drafts) {
        draft.dispose();
      }
      setState(() {
        _drafts
          ..clear()
          ..add(_PlayerDraft());
        _isSubmitting = false;
      });
      final count = created.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 1
                ? 'Created ${created.first.playerName}'
                : 'Created $count players',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Bad state: ', ''),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Create players', style: textTheme.headlineMedium),
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Create player profiles you can add to teams and matches. '
              'If they later want to use Ballo themselves, add their email and a temporary password here.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            ..._drafts.asMap().entries.map((entry) {
              final index = entry.key;
              final draft = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PlayerDraftCard(
                  key: draft.key,
                  index: index,
                  draft: draft,
                  canRemove: _drafts.length > 1,
                  onRemove: () => _removeDraft(draft),
                  onChanged: () => setState(() {}),
                ),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _drafts.length >= 20 || _isSubmitting ? null : _addDraft,
                icon: const Icon(Icons.add),
                label: const Text('Add another player'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _onCreate,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _drafts.length == 1
                            ? 'Create player'
                            : 'Create ${_drafts.length} players',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerDraft {
  _PlayerDraft()
      : key = UniqueKey(),
        nameController = TextEditingController(),
        usernameController = TextEditingController();

  final Key key;
  final TextEditingController nameController;
  final TextEditingController usernameController;
  String? position;
  String? imageUrl;
  UsernameCheckResult availability = const UsernameCheckResult(
    status: UsernameAvailability.idle,
  );

  void dispose() {
    nameController.dispose();
    usernameController.dispose();
  }
}

class _PlayerDraftCard extends StatefulWidget {
  const _PlayerDraftCard({
    super.key,
    required this.index,
    required this.draft,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  final int index;
  final _PlayerDraft draft;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  State<_PlayerDraftCard> createState() => _PlayerDraftCardState();
}

class _PlayerDraftCardState extends State<_PlayerDraftCard> {
  final _imagePicker = ImagePicker();
  bool _isUploading = false;

  _PlayerDraft get draft => widget.draft;

  Future<void> _pickImage(ImageSource source) async {
    if (!await ensureMediaAccessForImageSource(context, source)) return;
    if (!mounted) return;
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (image == null) return;

      setState(() => _isUploading = true);

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be signed in to upload')),
        );
        setState(() => _isUploading = false);
        return;
      }

      final fileName =
          '${user.id}_${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';
      final filePath = 'avatars/$fileName';
      final fileBytes = await image.readAsBytes();
      await requireAllowedImage(fileBytes, contentRef: 'avatar:${user.id}');
      await supabase.storage.from('Profile images').uploadBinary(filePath, fileBytes);
      final url = supabase.storage.from('Profile images').getPublicUrl(filePath);

      if (!mounted) return;
      setState(() {
        draft.imageUrl = url;
        _isUploading = false;
      });
      widget.onChanged();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      if (await presentMediaAccessSheetIfNeeded(
        context,
        error,
        mediaAccessKindForImageSource(source),
      )) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading: $error')),
      );
    }
  }

  Future<void> _showImageSourceDialog() async {
    if (_isUploading) return;
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select image source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickImage(source);
  }

  Widget _buildPhotoPreview(ColorScheme colorScheme) {
    final url = draft.imageUrl;
    if (url == null || url.isEmpty) {
      return Icon(Icons.person, size: 60, color: colorScheme.onSurfaceVariant);
    }
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image(
        image: appCachedImageProvider(url),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            Icon(Icons.person, size: 60, color: colorScheme.onSurfaceVariant),
      );
    }
    return Image.asset(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          Icon(Icons.person, size: 60, color: colorScheme.onSurfaceVariant),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Player ${widget.index + 1}',
                  style: textTheme.titleMedium,
                ),
              ),
              if (widget.canRemove)
                IconButton(
                  tooltip: 'Remove',
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          Text('Photo', style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Match officials use this to identify the player.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  DottedBorder(
                    borderType: BorderType.Circle,
                    dashPattern: const [8, 4],
                    color: colorScheme.outline.withValues(alpha: 0.6),
                    strokeWidth: 2,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.surfaceContainerHighest,
                      ),
                      child: ClipOval(child: _buildPhotoPreview(colorScheme)),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: colorScheme.primary,
                      shape: const CircleBorder(),
                      elevation: 4,
                      child: InkWell(
                        onTap: _isUploading ? null : _showImageSourceDialog,
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          child: _isUploading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.onPrimary,
                                  ),
                                )
                              : Icon(
                                  Icons.add,
                                  color: colorScheme.onPrimary,
                                  size: 24,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Or choose an avatar:',
            style: textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: _avatarAssets.map((assetPath) {
              final isSelected = draft.imageUrl == assetPath;
              return GestureDetector(
                onTap: () {
                  setState(() => draft.imageUrl = assetPath);
                  widget.onChanged();
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? colorScheme.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(assetPath, fit: BoxFit.cover),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: draft.nameController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Player name'),
            validator: (value) {
              final name = value?.trim() ?? '';
              if (name.length < 2) return 'Enter a player name';
              return UsernameRules.offensiveContentError(name);
            },
          ),
          const SizedBox(height: 12),
          UsernameAvailabilityField(
            controller: draft.usernameController,
            showStatusBanner: false,
            textInputAction: TextInputAction.next,
            onAvailabilityChanged: (result) {
              draft.availability = result;
              widget.onChanged();
            },
          ),
          const SizedBox(height: 16),
          Text('Position', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _positions.map((pos) {
              final isSelected = draft.position == pos;
              return ChoiceChip(
                label: Text(pos),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => draft.position = pos);
                  widget.onChanged();
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}


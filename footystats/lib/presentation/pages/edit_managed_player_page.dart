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

class EditManagedPlayerPage extends StatefulWidget {
  const EditManagedPlayerPage({super.key, required this.player});

  final ManagedPlayer player;

  @override
  State<EditManagedPlayerPage> createState() => _EditManagedPlayerPageState();
}

class _EditManagedPlayerPageState extends State<EditManagedPlayerPage> {
  final _formKey = GlobalKey<FormState>();
  final _repository = ManagedPlayersRepository();
  final _imagePicker = ImagePicker();
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late String? _position;
  late String? _imageUrl;
  UsernameCheckResult _availability = const UsernameCheckResult(
    status: UsernameAvailability.idle,
  );
  bool _isUploading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.player.playerName);
    _usernameController = TextEditingController(text: widget.player.username);
    _position = widget.player.position;
    _imageUrl = widget.player.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

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
      final fileBytes = await image.readAsBytes();
      await requireAllowedImage(fileBytes, contentRef: 'avatar:${user.id}');
      await supabase.storage
          .from('Profile images')
          .uploadBinary('avatars/$fileName', fileBytes);
      final url = supabase.storage
          .from('Profile images')
          .getPublicUrl('avatars/$fileName');
      if (!mounted) return;
      setState(() {
        _imageUrl = url;
        _isUploading = false;
      });
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
    final url = _imageUrl;
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

  Future<void> _onSave() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _nameController.text.trim();
    final username = UsernameRules.normalize(_usernameController.text);
    final nameBlock = UsernameRules.offensiveContentError(name);
    if (nameBlock != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(nameBlock)));
      return;
    }
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a position')),
      );
      return;
    }
    final imageUrl = _imageUrl?.trim() ?? '';
    if (imageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add a photo so match officials can identify this player',
          ),
        ),
      );
      return;
    }
    final currentUsername = widget.player.username.trim().toLowerCase();
    if (username.toLowerCase() != currentUsername &&
        _availability.status != UsernameAvailability.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wait until the username is available')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await requireAllowedText(name, contentRef: 'player_name');
      await requireAllowedText(username, contentRef: 'username:$username');
      await _repository.updatePlayer(
        playerId: widget.player.id,
        details: ManagedPlayerDraftInput(
          playerName: name,
          username: username,
          position: _position!,
          imageUrl: imageUrl,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit player', style: textTheme.headlineMedium),
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'You can change these details until you add a login for this player.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
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
                final isSelected = _imageUrl == assetPath;
                return GestureDetector(
                  onTap: () => setState(() => _imageUrl = assetPath),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : Colors.transparent,
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
              controller: _nameController,
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
              controller: _usernameController,
              excludePlayerId: widget.player.id,
              showStatusBanner: false,
              onAvailabilityChanged: (result) {
                setState(() => _availability = result);
              },
            ),
            const SizedBox(height: 16),
            Text('Position', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _positions.map((pos) {
                final isSelected = _position == pos;
                return ChoiceChip(
                  label: Text(pos),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _position = pos),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _onSave,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

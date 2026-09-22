import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/media_placeholders.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_assets.dart';
import '../../core/utils/content_moderation_guards.dart';
import '../../core/utils/username_rules.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../../data/repositories/username_repository.dart';
import '../../domain/models/account_type.dart';
import '../../domain/models/user_profile.dart';
import '../widgets/country_picker_section.dart';
import '../widgets/delete_account_dialog.dart';
import '../widgets/media_access_sheet.dart';
import '../widgets/username_availability_field.dart';

const List<String> _positions = ['Goalkeeper', 'Defender', 'Midfielder', 'Attacker'];

const List<String> _avatarAssets = [
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

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _playerNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _socialInstagramController;
  late final TextEditingController _socialTiktokController;
  late final TextEditingController _socialXController;
  late final TextEditingController _staffRoleOtherController;
  late final TextEditingController _aboutController;
  late String? _position;
  late String? _imageUrl;
  late String? _countryCode;
  late StaffRole? _staffRole;
  bool _isSubmitting = false;
  bool _isUploading = false;
  UsernameCheckResult _usernameAvailability = const UsernameCheckResult(
    status: UsernameAvailability.idle,
  );
  final _imagePicker = ImagePicker();
  final _profileRepository = UserProfileRepository();

  @override
  void initState() {
    super.initState();
    _playerNameController = TextEditingController(text: widget.profile.playerName ?? '');
    _usernameController = TextEditingController(text: widget.profile.username ?? '');
    _socialInstagramController =
        TextEditingController(text: widget.profile.socialInstagram ?? '');
    _socialTiktokController = TextEditingController(text: widget.profile.socialTiktok ?? '');
    _socialXController = TextEditingController(text: widget.profile.socialX ?? '');
    _staffRoleOtherController =
        TextEditingController(text: widget.profile.staffRoleOther ?? '');
    _aboutController = TextEditingController(text: widget.profile.about ?? '');
    _position = widget.profile.position;
    _imageUrl = widget.profile.imageUrl;
    _countryCode = widget.profile.country;
    _staffRole = StaffRole.fromDb(widget.profile.staffRole);
  }

  @override
  void dispose() {
    _playerNameController.dispose();
    _usernameController.dispose();
    _socialInstagramController.dispose();
    _socialTiktokController.dispose();
    _socialXController.dispose();
    _staffRoleOtherController.dispose();
    _aboutController.dispose();
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
      const folderName = 'avatars';
      final filePath = '$folderName/$fileName';
      final fileBytes = await image.readAsBytes();

      await requireAllowedImage(fileBytes, contentRef: 'avatar:${user.id}');

      await supabase.storage.from('Profile images').uploadBinary(filePath, fileBytes);
      final url = supabase.storage.from('Profile images').getPublicUrl(filePath);

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

  bool get _canSaveUsername {
    final current = widget.profile.username?.trim() ?? '';
    final next = _usernameController.text.trim();
    if (current.isNotEmpty && current.toLowerCase() == next.toLowerCase()) {
      return true;
    }
    return _usernameAvailability.status == UsernameAvailability.available;
  }

  Future<void> _onSave() async {
    if (!_canSaveUsername) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (widget.profile.isTechnicalStaff && _staffRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select your role')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final playerName = _playerNameController.text.trim();
      final username = _usernameController.text.trim();
      final localName = UsernameRules.offensiveContentError(playerName);
      final localUser = UsernameRules.usernameError(username);
      if (localName != null || localUser != null) {
        throw StateError(localName ?? localUser!);
      }
      await requireAllowedText(playerName, contentRef: 'player_name');
      await requireAllowedText(username, contentRef: 'username:$username');

      await _profileRepository.upsertCurrentProfile(
        username: username,
        playerName: playerName,
        position: widget.profile.isTechnicalStaff ? widget.profile.position : _position,
        imageUrl: _imageUrl,
        country: _countryCode,
        socialInstagram: _socialInstagramController.text,
        socialTiktok: _socialTiktokController.text,
        socialX: _socialXController.text,
        updateSocialLinks: true,
        accountType: widget.profile.isTechnicalStaff
            ? 'technical_staff'
            : (widget.profile.accountType ?? 'player'),
        staffRole: widget.profile.isTechnicalStaff ? _staffRole?.dbValue : null,
        staffRoleOther: widget.profile.isTechnicalStaff
            ? _staffRoleOtherController.text
            : null,
        updateStaffRole: widget.profile.isTechnicalStaff,
        about: widget.profile.isTechnicalStaff
            ? _aboutController.text
            : widget.profile.about,
        updateAbout: widget.profile.isTechnicalStaff,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          IconButton(
            tooltip: 'Save',
            onPressed: _isSubmitting || !_canSaveUsername ? null : _onSave,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile image
              Text('Profile picture', style: textTheme.titleMedium),
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
                          child: ClipOval(
                            child: _buildProfileImage(),
                          ),
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
                                  : Icon(Icons.add, color: colorScheme.onPrimary, size: 24),
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
              const SizedBox(height: 24),
              // Player name
              TextFormField(
                controller: _playerNameController,
                decoration: InputDecoration(
                  labelText: widget.profile.isTechnicalStaff ? 'Name' : 'Player name',
                  hintText: 'e.g. Gareth Munroe',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return widget.profile.isTechnicalStaff
                        ? 'Enter your name'
                        : 'Enter your player name';
                  }
                  if (v.trim().length < 2) return 'At least 2 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              UsernameAvailabilityField(
                controller: _usernameController,
                excludePlayerId: widget.profile.id,
                onAvailabilityChanged: (result) {
                  setState(() => _usernameAvailability = result);
                },
              ),
              const SizedBox(height: 24),
              if (widget.profile.isTechnicalStaff) ...[
                Text('Role', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: StaffRole.values.map((role) {
                    final isSelected = _staffRole == role;
                    return ChoiceChip(
                      label: Text(role.label),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _staffRole = selected ? role : null);
                      },
                    );
                  }).toList(),
                ),
                if (_staffRole == StaffRole.other) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _staffRoleOtherController,
                    decoration: const InputDecoration(
                      labelText: 'Specify your role',
                      hintText: 'e.g. Analyst, Physio',
                    ),
                    validator: (v) {
                      if (_staffRole != StaffRole.other) return null;
                      if (v == null || v.trim().length < 2) {
                        return 'Enter your role';
                      }
                      return null;
                    },
                  ),
                ],
              ] else ...[
                Text('Position', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _positions.map((pos) {
                    final isSelected = _position == pos;
                    return ChoiceChip(
                      label: Text(pos),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _position = selected ? pos : null);
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 24),
              CountryPickerSection(
                selectedCountryCode: _countryCode,
                onCountrySelected: (code) => setState(() => _countryCode = code),
              ),
              if (widget.profile.isTechnicalStaff) ...[
                const SizedBox(height: 24),
                Text('About', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _aboutController,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 280,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Tell players who you are and how you work in football.',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text('Social links (optional)', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                'Use full URLs starting with https://',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _socialInstagramController,
                decoration: const InputDecoration(
                  labelText: 'Instagram',
                  hintText: 'https://instagram.com/…',
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
                validator: _optionalHttpsUrlValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _socialTiktokController,
                decoration: const InputDecoration(
                  labelText: 'TikTok',
                  hintText: 'https://www.tiktok.com/@…',
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
                validator: _optionalHttpsUrlValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _socialXController,
                decoration: const InputDecoration(
                  labelText: 'X (Twitter)',
                  hintText: 'https://x.com/…',
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
                validator: _optionalHttpsUrlValidator,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      _isSubmitting || !_canSaveUsername ? null : _onSave,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save changes'),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Danger zone',
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Permanently delete your account and personal data.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => showDeleteAccountDialog(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(color: colorScheme.error),
                  ),
                  child: const Text('Delete account'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  static String? _optionalHttpsUrlValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme) {
      return 'Enter a valid URL';
    }
    if (!(uri.isScheme('http') || uri.isScheme('https'))) {
      return 'URL must start with http:// or https://';
    }
    return null;
  }

  Widget _buildProfileImage() {
    if (_imageUrl == null || _imageUrl!.isEmpty) {
      return Icon(Icons.person, size: 60, color: Theme.of(context).colorScheme.onSurfaceVariant);
    }
    final url = _imageUrl!;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image(
        image: appCachedImageProvider(url),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            Icon(Icons.person, size: 60, color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    return Image.asset(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          Icon(Icons.person, size: 60, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

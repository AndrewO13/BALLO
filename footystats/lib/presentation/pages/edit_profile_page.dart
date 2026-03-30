import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/countries.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../../domain/models/user_profile.dart';

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
  late String? _position;
  late String? _imageUrl;
  late String? _countryCode;
  String? _searchQuery;
  bool _isSubmitting = false;
  bool _isUploading = false;
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
    _position = widget.profile.position;
    _imageUrl = widget.profile.imageUrl;
    _countryCode = widget.profile.country;
  }

  @override
  void dispose() {
    _playerNameController.dispose();
    _usernameController.dispose();
    _socialInstagramController.dispose();
    _socialTiktokController.dispose();
    _socialXController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 512,
        maxHeight: 512,
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

      await supabase.storage.from('Profile images').uploadBinary(filePath, fileBytes);
      final url = supabase.storage.from('Profile images').getPublicUrl(filePath);

      setState(() {
        _imageUrl = url;
        _isUploading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isUploading = false);
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

  Future<void> _onSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    try {
      await _profileRepository.upsertCurrentProfile(
        username: _usernameController.text.trim(),
        playerName: _playerNameController.text.trim(),
        position: _position,
        imageUrl: _imageUrl,
        country: _countryCode,
        socialInstagram: _socialInstagramController.text,
        socialTiktok: _socialTiktokController.text,
        socialX: _socialXController.text,
        updateSocialLinks: true,
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

  List<Map<String, String>> get _filteredCountries {
    if (_searchQuery == null || _searchQuery!.trim().isEmpty) return countries;
    final q = _searchQuery!.toLowerCase();
    return countries
        .where((c) =>
            c['name']!.toLowerCase().contains(q) ||
            c['code']!.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _onSave,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
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
                        color: colorScheme.outline.withOpacity(0.6),
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
                decoration: const InputDecoration(
                  labelText: 'Player name',
                  hintText: 'e.g. Gareth Munroe',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter your player name';
                  if (v.trim().length < 2) return 'At least 2 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Username
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'e.g. TurfGeneral',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter a username';
                  if (v.trim().length < 3) return 'At least 3 characters';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // Position
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
              const SizedBox(height: 24),
              // Country
              Text('Country', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Search country',
                  hintText: 'Type to search...',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filteredCountries.length,
                  itemBuilder: (context, index) {
                    final c = _filteredCountries[index];
                    final code = c['code']!;
                    final name = c['name']!;
                    final isSelected = _countryCode == code;
                    return ListTile(
                      leading: Text(countryCodeToFlag(code), style: const TextStyle(fontSize: 20)),
                      title: Text(name),
                      selected: isSelected,
                      onTap: () => setState(() => _countryCode = code),
                    );
                  },
                ),
              ),
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
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.person, size: 60, color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    return Image.asset(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.person, size: 60, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

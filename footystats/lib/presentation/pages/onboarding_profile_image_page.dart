import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import '../../core/adaptive/adaptive.dart';
import '../../core/widgets/media_placeholders.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_assets.dart';
import '../../core/constants/onboarding_steps.dart';
import '../../core/onboarding/onboarding_completion.dart';
import '../../core/utils/content_moderation_guards.dart';
import '../../data/repositories/onboarding_repository.dart';
import '../../domain/models/onboarding_draft.dart';
import '../widgets/onboarding_progress_app_bar.dart';
import '../widgets/media_access_sheet.dart';
import 'home_page.dart';
import 'onboarding_join_team_page.dart';

/// Avatars available for selection (app assets). User can add more.
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

class OnboardingProfileImagePage extends StatefulWidget {
  const OnboardingProfileImagePage({
    super.key,
    required this.draft,
  });

  final OnboardingDraft draft;

  @override
  State<OnboardingProfileImagePage> createState() =>
      _OnboardingProfileImagePageState();
}

class _OnboardingProfileImagePageState extends State<OnboardingProfileImagePage> {
  String? _imageUrl;
  bool _isUploading = false;
  bool _isFinishing = false;
  final _imagePicker = ImagePicker();
  final _onboardingRepository = OnboardingRepository();

  /// _imageUrl can be: network URL (uploaded), or asset path (e.g. lib/assets/images/avatars/3d_avatar_13.png)
  bool get _hasSelection => _imageUrl != null && _imageUrl!.isNotEmpty;

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

  void _onSkip() {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Skip profile picture?'),
        content: const Text(
          'You can always upload a profile picture later in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Skip'),
          ),
        ],
      ),
    ).then((skip) {
      if (skip == true && mounted) {
        _finish();
      }
    });
  }

  Future<void> _finish({String? imageUrl}) async {
    if (_isFinishing) return;

    setState(() => _isFinishing = true);
    try {
      final resolvedImage = imageUrl ?? _imageUrl;
      if (resolvedImage != null && resolvedImage.isNotEmpty) {
        await _onboardingRepository.saveDraftProfile(
          widget.draft,
          imageUrl: resolvedImage,
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile picture: $error')),
        );
      }
    }

    if (!mounted) return;
    if (widget.draft.isTechnicalStaff) {
      await OnboardingCompletion.markComplete();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OnboardingJoinTeamPage(draft: widget.draft),
      ),
    );

    if (mounted) setState(() => _isFinishing = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: OnboardingProgressAppBar(
        step: OnboardingStep.profileImage,
        accountType: widget.draft.accountType,
        actions: [
          TextButton(
            onPressed: _onSkip,
            child: Text('Skip', style: TextStyle(color: colorScheme.onSurface)),
          ),
        ],
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppResponsive.horizontalInset(context, design: 24),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                      'Choose profile picture',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose a photo that represents you!',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          DottedBorder(
                            borderType: BorderType.Circle,
                            dashPattern: const [8, 4],
                            color: colorScheme.outline.withValues(alpha: 0.6),
                            strokeWidth: 2,
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colorScheme.surfaceContainerHigh
                                    .withValues(alpha: 0.3),
                              ),
                              child: ClipOval(
                                child: _hasSelection
                                    ? _buildImage()
                                    : Icon(
                                        Icons.person_outline,
                                        size: 80,
                                        color: colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.6),
                                      ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 20,
                            top: 20,
                            child: Material(
                              color: colorScheme.primary,
                              shape: const CircleBorder(),
                              elevation: 4,
                              child: InkWell(
                                onTap:
                                    _isUploading ? null : _showImageSourceDialog,
                                customBorder: const CircleBorder(),
                                child: Container(
                                  width: 44,
                                  height: 44,
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
                                          size: 28,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Or choose an avatar:',
                      style: textTheme.titleSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 16,
                      runSpacing: 16,
                      children: _avatarAssets.map((assetPath) {
                        final isSelected = _imageUrl == assetPath;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _imageUrl = assetPath);
                          },
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? colorScheme.primary
                                    : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: colorScheme.primary
                                            .withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                assetPath,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _hasSelection && !_isFinishing
                            ? () => _finish()
                            : null,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: _isFinishing
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onPrimary,
                                ),
                              )
                            : const Text('Finish'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (_imageUrl!.startsWith('http://') || _imageUrl!.startsWith('https://')) {
      return Image(
        image: appCachedImageProvider(_imageUrl!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(
          Icons.person_outline,
          size: 80,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Image.asset(_imageUrl!, fit: BoxFit.cover);
  }
}

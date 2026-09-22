import 'package:flutter/material.dart';
import '../../core/widgets/media_placeholders.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import '../../core/utils/content_moderation_guards.dart';
import '../../core/utils/username_rules.dart';
import '../../data/repositories/leagues_repository.dart';
import '../../data/repositories/teams_repository.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../widgets/country_picker_section.dart';
import '../widgets/media_access_sheet.dart';
import 'create_match_entry_page.dart';
import 'team_detail_page.dart';
import 'league_detail_page.dart';

class CreateTeamOrLeaguePage extends StatefulWidget {
  const CreateTeamOrLeaguePage({super.key});

  @override
  State<CreateTeamOrLeaguePage> createState() => _CreateTeamOrLeaguePageState();
}

class _CreateTeamOrLeaguePageState extends State<CreateTeamOrLeaguePage> {
  List<Map<String, dynamic>> _leagues = [];
  List<Map<String, dynamic>> _teams = [];
  bool _isLoading = true;

  final _leaguesRepository = LeaguesRepository();
  final _teamsRepository = TeamsRepository();

  @override
  void initState() {
    super.initState();
    _loadUserContent(showFullPageLoader: true);
  }

  Future<void> _loadUserContent({bool showFullPageLoader = false}) async {
    if (showFullPageLoader && mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final leagues = await _leaguesRepository.getLeaguesForUser(user.id);
      final teams = await _teamsRepository.getTeamsForUser(user.id);

      if (mounted) {
        setState(() {
          _leagues = leagues
              .map(
                (league) => <String, dynamic>{
                  'id': league.id,
                  'league_name': league.leagueName,
                  'logo_id': league.logoId,
                },
              )
              .toList();
          _teams = teams
              .map(
                (team) => <String, dynamic>{
                  'id': team.id,
                  'team_name': team.displayName,
                  'logo_id': team.logoId,
                },
              )
              .toList();
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading content: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add to matches',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserContent,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section 1: What would you like to create?
                      Text(
                        'What would you like to create?',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      _ChoiceCard(
                        icon: Icons.sports_score,
                        title: 'Create match',
                        subtitle:
                            'Set up a match between teams and assign league details.',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CreateMatchEntryPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      _ChoiceCard(
                        icon: Icons.groups_outlined,
                        title: 'Create team',
                        subtitle:
                            'Add a team you can later use when creating and tracking matches.',
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CreateTeamPage(),
                            ),
                          );
                          // Reload after returning from create page
                          _loadUserContent();
                        },
                      ),
                      const SizedBox(height: 12),
                      _ChoiceCard(
                        icon: Icons.emoji_events_outlined,
                        title: 'Create league',
                        subtitle:
                            'Set up a league to group matches and view standings.',
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CreateLeaguePage(),
                            ),
                          );
                          // Reload after returning from create page
                          _loadUserContent();
                        },
                      ),
                      const SizedBox(height: 32),
                      // Section 2: Leagues
                      Text(
                        'Leagues',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      if (_leagues.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'No leagues available yet',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        ..._leagues.map(
                          (league) => Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: _ItemCard(
                              name:
                                  league['league_name'] as String? ?? 'Unknown',
                              logoUrl: league['logo_id'] as String?,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => LeagueDetailPage(
                                      leagueId: league['id'] as String,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      const SizedBox(height: 32),
                      // Section 3: Teams
                      Text(
                        'Teams',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      if (_teams.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'No teams available yet',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        ..._teams.map(
                          (team) => Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: _ItemCard(
                              name: team['team_name'] as String? ?? 'Unknown',
                              logoUrl: team['logo_id'] as String?,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TeamDetailPage(
                                      teamId: team['id'] as String,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.name, this.logoUrl, required this.onTap});

  final String name;
  final String? logoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.hardEdge,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: InkWell(
        splashColor: colorScheme.primary.withAlpha(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: logoUrl != null && logoUrl!.isNotEmpty
                    ? ClipOval(
                        child: Image(
                          image: appCachedImageProvider(logoUrl!),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.image_not_supported,
                              size: 24,
                              color: colorScheme.onSurfaceVariant,
                            );
                          },
                        ),
                      )
                    : Icon(
                        Icons.image_outlined,
                        size: 24,
                        color: colorScheme.onSurfaceVariant,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(name, style: Theme.of(context).textTheme.bodyLarge),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoUploadWidget extends StatefulWidget {
  const _LogoUploadWidget({
    required this.onLogoSelected,
    required this.folderName,
    this.label = 'Logo',
    this.emptyIcon = Icons.person,
    this.isBannerStyle = false,
  });

  final ValueChanged<String?> onLogoSelected;
  final String folderName;
  final String label;
  final IconData emptyIcon;
  final bool isBannerStyle;

  @override
  State<_LogoUploadWidget> createState() => _LogoUploadWidgetState();
}

class _LogoUploadWidgetState extends State<_LogoUploadWidget> {
  String? _logoUrl;
  bool _isUploading = false;
  final _imagePicker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    if (!await ensureMediaAccessForImageSource(context, source)) return;
    if (!mounted) return;
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be signed in to upload images'),
          ),
        );
        setState(() => _isUploading = false);
        return;
      }

      // Generate unique filename
      final fileName =
          '${user.id}_${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';
      final filePath = '${widget.folderName}/$fileName';

      // Read file bytes
      final fileBytes = await image.readAsBytes();
      await requireAllowedImage(
        fileBytes,
        contentRef: 'image:${widget.folderName}',
      );

      // Upload to Supabase storage
      await supabase.storage
          .from('Profile images')
          .uploadBinary(filePath, fileBytes);

      // Get public URL
      final url = supabase.storage
          .from('Profile images')
          .getPublicUrl(filePath);

      setState(() {
        _logoUrl = url;
        _isUploading = false;
      });

      widget.onLogoSelected(url);
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

      String errorMessage = 'Error uploading image';
      if (error.toString().contains('row-level security') ||
          error.toString().contains('403') ||
          error.toString().contains('Unauthorized')) {
        errorMessage =
            'Upload failed: Storage permissions not configured. '
            'Please check your Supabase storage bucket RLS policies.';
      } else {
        errorMessage = 'Error uploading image: $error';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 5),
        ),
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

    if (source != null) {
      await _pickImage(source);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text(widget.label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
        ],
        widget.isBannerStyle
            ? GestureDetector(
                onTap: _isUploading ? null : _showImageSourceDialog,
                child: Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _isUploading
                      ? const Center(child: CircularProgressIndicator())
                      : _logoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image(
                            image: appCachedImageProvider(_logoUrl!),
                            fit: BoxFit.fill,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.image_not_supported,
                                size: 40,
                                color: colorScheme.onSurfaceVariant,
                              );
                            },
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.emptyIcon,
                              size: 36,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap to upload background',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                ),
              )
            : Center(
                child: GestureDetector(
                  onTap: _isUploading ? null : _showImageSourceDialog,
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: _isUploading
                            ? const Center(child: CircularProgressIndicator())
                            : _logoUrl != null
                            ? ClipOval(
                                child: Image(
                                  image: appCachedImageProvider(_logoUrl!),
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.image_not_supported,
                                      size: 60,
                                      color: colorScheme.onSurfaceVariant,
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                widget.emptyIcon,
                                size: 60,
                                color: colorScheme.onSurfaceVariant,
                              ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHigh,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.surface,
                              width: 2,
                            ),
                          ),
                          child: _isUploading
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              : Icon(
                                  _logoUrl != null ? Icons.edit : Icons.add,
                                  color: colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ],
    );
  }
}

class _BannerUploadWidget extends StatefulWidget {
  const _BannerUploadWidget({
    required this.onBannerSelected,
    required this.folderName,
  });

  final ValueChanged<String?> onBannerSelected;
  final String folderName;

  @override
  State<_BannerUploadWidget> createState() => _BannerUploadWidgetState();
}

class _BannerUploadWidgetState extends State<_BannerUploadWidget> {
  String? _bannerUrl;
  bool _isUploading = false;
  final _imagePicker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    if (!await ensureMediaAccessForImageSource(context, source)) return;
    if (!mounted) return;
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1800,
        maxHeight: 1200,
      );
      if (image == null) return;
      setState(() => _isUploading = true);

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be signed in to upload images'),
          ),
        );
        setState(() => _isUploading = false);
        return;
      }

      final fileName =
          '${user.id}_${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}';
      final filePath = '${widget.folderName}/$fileName';
      final fileBytes = await image.readAsBytes();
      await requireAllowedImage(
        fileBytes,
        contentRef: 'image:${widget.folderName}',
      );
      await supabase.storage
          .from('Profile images')
          .uploadBinary(filePath, fileBytes);
      final url = supabase.storage
          .from('Profile images')
          .getPublicUrl(filePath);

      setState(() {
        _bannerUrl = url;
        _isUploading = false;
      });
      widget.onBannerSelected(url);
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading banner: $error')));
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
    if (source != null) {
      await _pickImage(source);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Team banner', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _isUploading ? null : _showImageSourceDialog,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              height: 150,
              color: colorScheme.surfaceContainerHighest,
              child: _isUploading
                  ? const Center(child: CircularProgressIndicator())
                  : (_bannerUrl != null && _bannerUrl!.isNotEmpty)
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image(
                          image: appCachedImageProvider(_bannerUrl!),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.image_not_supported,
                              size: 36,
                              color: colorScheme.onSurfaceVariant,
                            );
                          },
                        ),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: CircleAvatar(
                              backgroundColor: colorScheme.surface.withValues(
                                alpha: 0.9,
                              ),
                              child: Icon(
                                Icons.edit,
                                size: 16,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 36,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to upload team banner',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class CreateMatchPage extends StatelessWidget {
  const CreateMatchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Create match', style: textTheme.headlineMedium),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Match creation will be available here.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class CreateTeamPage extends StatefulWidget {
  const CreateTeamPage({super.key, this.onTeamCreated});

  /// When set, team creation pops back instead of opening team detail.
  final void Function(String teamId)? onTeamCreated;

  @override
  State<CreateTeamPage> createState() => _CreateTeamPageState();
}

class _CreateTeamPageState extends State<CreateTeamPage> {
  final _formKey = GlobalKey<FormState>();
  final _teamNameController = TextEditingController();
  final _shortFormController = TextEditingController();
  String? _logoUrl;
  String? _bannerUrl;

  bool _isSubmitting = false;

  static const int _shortFormMaxLength = 4;

  @override
  void dispose() {
    _shortFormController.dispose();
    _teamNameController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    setState(() => _isSubmitting = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be signed in to create a team'),
          ),
        );
        return;
      }

      final teamName = _teamNameController.text.trim();
      final shortForm = _shortFormController.text.trim();
      final nameBlock = UsernameRules.offensiveContentError(teamName) ??
          UsernameRules.offensiveContentError(shortForm);
      if (nameBlock != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(nameBlock)),
        );
        return;
      }
      await requireAllowedText(teamName, contentRef: 'team_name');

      final response = await supabase
          .from('teams')
          .insert({
            'team_name': teamName,
            'short_form': shortForm,
            'logo_id': _logoUrl,
            'banner_id': _bannerUrl,
            'created_by': user.id,
          })
          .select('id')
          .single();

      if (!mounted) return;
      final teamId = response['id'] as String;
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      if (widget.onTeamCreated != null) {
        widget.onTeamCreated!(teamId);
        navigator.pop(teamId);
        messenger.showSnackBar(
          const SnackBar(content: Text('Team created')),
        );
        return;
      }
      // Replace create only — keep "Add to matches" (or prior route) underneath.
      // Do not pop() first; that + pushReplacement corrupts the stack and can
      // leave Add to matches stuck after a background reload.
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => TeamDetailPage(teamId: teamId),
        ),
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Team created')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating team: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Create team', style: textTheme.headlineMedium),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LogoUploadWidget(
                  folderName: 'team logos',
                  emptyIcon: Icons.shield_outlined,
                  onLogoSelected: (url) {
                    setState(() {
                      _logoUrl = url;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _teamNameController,
                  decoration: const InputDecoration(
                    labelText: 'Team name',
                    hintText: 'e.g. Lefters CF',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a team name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _shortFormController,
                  maxLength: _shortFormMaxLength,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(_shortFormMaxLength),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Short form',
                    hintText: 'e.g. LCF',
                    helperText: 'Maximum 4 characters',
                  ),
                  buildCounter: (
                    context, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) {
                    final limit = maxLength ?? _shortFormMaxLength;
                    final remaining = limit - currentLength;
                    final atLimit = currentLength >= limit;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              currentLength == 0
                                  ? 'Used on match cards and standings'
                                  : atLimit
                                  ? 'Maximum length reached'
                                  : '$remaining character${remaining == 1 ? '' : 's'} left',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Text(
                            '$currentLength/$limit',
                            style: textTheme.labelLarge?.copyWith(
                              color: atLimit
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a short form';
                    }
                    if (value.trim().length > _shortFormMaxLength) {
                      return 'Maximum $_shortFormMaxLength characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _BannerUploadWidget(
                  folderName: 'team banners',
                  onBannerSelected: (url) {
                    setState(() {
                      _bannerUrl = url;
                    });
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _onSubmit,
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
                        : const Text('Create team'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Only you (the creator) will be allowed to manage this team.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreateLeaguePage extends StatefulWidget {
  const CreateLeaguePage({super.key});

  @override
  State<CreateLeaguePage> createState() => _CreateLeaguePageState();
}

class _CreateLeaguePageState extends State<CreateLeaguePage> {
  final _formKey = GlobalKey<FormState>();
  final _leagueNameController = TextEditingController();
  String? _logoUrl;
  String? _defaultVenueImageUrl;
  String? _countryCode;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _prefillCountryFromProfile();
  }

  Future<void> _prefillCountryFromProfile() async {
    try {
      final profile = await UserProfileRepository().getCurrentProfile();
      if (!mounted) return;
      final code = profile?.country?.trim();
      if (code != null && code.isNotEmpty) {
        setState(() => _countryCode = code);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _leagueNameController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() => _isSubmitting = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be signed in to create a league'),
          ),
        );
        return;
      }

      final leagueName = _leagueNameController.text.trim();
      final nameBlock = UsernameRules.offensiveContentError(leagueName);
      if (nameBlock != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(nameBlock)),
        );
        return;
      }
      await requireAllowedText(leagueName, contentRef: 'league_name');

      final insertData = <String, dynamic>{
        'league_name': leagueName,
        'logo_id': _logoUrl,
        'default_venue_image_url': _defaultVenueImageUrl,
        'created_by': user.id,
        'country': _countryCode,
      };

      final response = await supabase
          .from('leagues')
          .insert(insertData)
          .select('id')
          .single();

      if (!mounted) return;
      final leagueId = response['id'] as String;
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      // Replace create only — keep "Add to matches" underneath.
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => LeagueDetailPage(leagueId: leagueId),
        ),
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('League created')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating league: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Create league', style: textTheme.headlineMedium),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('League logo', style: textTheme.titleMedium),
                const SizedBox(height: 16),
                _LogoUploadWidget(
                  folderName: 'league logos',
                  label: '',
                  emptyIcon: Icons.emoji_events_outlined,
                  onLogoSelected: (url) {
                    setState(() {
                      _logoUrl = url;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _leagueNameController,
                  decoration: const InputDecoration(
                    labelText: 'League name',
                    hintText: 'e.g. Turf Champi',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter a league name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                FormField<String>(
                  validator: (_) {
                    if (_countryCode == null || _countryCode!.isEmpty) {
                      return 'Select a country';
                    }
                    return null;
                  },
                  builder: (state) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CountryPickerSection(
                          selectedCountryCode: _countryCode,
                          maxListHeight: 220,
                          onCountrySelected: (code) {
                            setState(() => _countryCode = code);
                            state.didChange(code);
                          },
                        ),
                        if (state.hasError) ...[
                          const SizedBox(height: 8),
                          Text(
                            state.errorText!,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _LogoUploadWidget(
                  folderName: 'venue images',
                  label: 'Default location background',
                  emptyIcon: Icons.stadium_outlined,
                  isBannerStyle: true,
                  onLogoSelected: (url) {
                    setState(() {
                      _defaultVenueImageUrl = url;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  'Season dates are now tracked automatically from the first and last match in each season.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _onSubmit,
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
                        : const Text('Create league'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Only you (the creator) will be allowed to manage this league.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

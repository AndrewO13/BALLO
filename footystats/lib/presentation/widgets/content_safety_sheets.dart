import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../data/repositories/content_safety_repository.dart';

/// Community guidelines copy used in-app and linked from settings/site.
class CommunityGuidelines {
  static const title = 'Community Guidelines';

  static const responseSlaHours = 24;

  static const supportEmail = AppConstants.supportEmail;

  static const body = '''
Ballo is for amateur football — stats, teams, leagues, and match highlights.

Be respectful
• No harassment, hate speech, threats, or bullying.
• No discrimination based on race, religion, gender, sexuality, nationality, or disability.

Keep it football
• Upload real match highlights, not pornographic, graphic, or shocking content.
• Hard tackles and match intensity are fine; real-world violence and gore are not.

No spam or scams
• Don’t impersonate others or post misleading content.
• Don’t use Ballo to promote illegal activity.

Report & block
• Use Report on any video to flag abuse.
• Block a user to hide their content from your feed immediately.

We review reports within $responseSlaHours hours. Serious violations can lead to content removal or account action.

Contact: $supportEmail
''';

  static String get webPath => AppConstants.communityGuidelinesPath;

  static Uri get webUri => AppConstants.communityGuidelinesUri;
}

Future<void> showCommunityGuidelinesModal(
  BuildContext context, {
  bool requireAccept = false,
}) async {
  final repo = ContentSafetyRepository();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: !requireAccept,
    enableDrag: !requireAccept,
    useSafeArea: true,
    builder: (sheetContext) {
      final maxH = MediaQuery.sizeOf(sheetContext).height * 0.85;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      CommunityGuidelines.title,
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                  ),
                  if (!requireAccept)
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    CommunityGuidelines.body,
                    style:
                        Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                              height: 1.45,
                            ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  final uri = Uri(
                    scheme: 'mailto',
                    path: CommunityGuidelines.supportEmail,
                    queryParameters: {'subject': 'Ballo support'},
                  );
                  await launchUrl(uri);
                },
                child: Text('Contact ${CommunityGuidelines.supportEmail}'),
              ),
              if (requireAccept) ...[
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () async {
                    try {
                      await repo.acceptCommunityGuidelines();
                    } catch (_) {}
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                  child: const Text('I agree — Continue'),
                ),
              ] else
                FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Close'),
                ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showReportContentSheet(
  BuildContext context, {
  required String videoId,
  String? uploaderUserId,
  String? uploaderName,
}) async {
  final repo = ContentSafetyRepository();
  String selected = 'spam';
  final detailsController = TextEditingController();
  var submitting = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final maxH = MediaQuery.sizeOf(sheetContext).height * 0.9;
      return StatefulBuilder(
        builder: (context, setModalState) {
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Report content',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We review reports within ${CommunityGuidelines.responseSlaHours} hours.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: [
                        ...ContentSafetyRepository.reportReasons.entries.map(
                          (e) {
                            return RadioListTile<String>(
                              value: e.key,
                              groupValue: selected,
                              title: Text(e.value),
                              onChanged: submitting
                                  ? null
                                  : (v) => setModalState(
                                        () => selected = v ?? selected,
                                      ),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            );
                          },
                        ),
                        TextField(
                          controller: detailsController,
                          maxLines: 2,
                          maxLength: 400,
                          enabled: !submitting,
                          decoration: const InputDecoration(
                            labelText: 'Details (optional)',
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            setModalState(() => submitting = true);
                            try {
                              await repo.reportVideo(
                                videoId: videoId,
                                reason: selected,
                                details: detailsController.text,
                              );
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Thanks — we received your report.',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              setModalState(() => submitting = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Could not report: $e'),
                                  ),
                                );
                              }
                            }
                          },
                    child: submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit report'),
                  ),
                  if (uploaderUserId != null &&
                      uploaderUserId.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: submitting
                          ? null
                          : () async {
                              await showBlockUserDialog(
                                context,
                                userId: uploaderUserId,
                                displayName: uploaderName,
                              );
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                              }
                            },
                      icon: const Icon(Icons.block),
                      label: Text('Block ${uploaderName ?? 'user'}'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      );
    },
  );

  detailsController.dispose();
}

Future<void> showBlockUserDialog(
  BuildContext context, {
  required String userId,
  String? displayName,
}) async {
  final name = displayName ?? 'this user';
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Block user?'),
      content: Text(
        'You will no longer see videos from $name. They will not be notified. '
        'Blocking is the most effective way to stop abusive content in your '
        'feed — reported content is reviewed within '
        '${CommunityGuidelines.responseSlaHours} hours, but block takes effect '
        'immediately for you.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Block'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    await ContentSafetyRepository().blockUser(userId);
    if (!context.mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name blocked')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not block: $e')),
    );
  }
}

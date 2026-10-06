import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/video_upload_queue_provider.dart';

/// Live upload status for a fixture clip, meant to sit inside a SnackBar.
class VideoUploadProgressSnackContent extends ConsumerWidget {
  const VideoUploadProgressSnackContent({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = ref
        .watch(videoUploadQueueProvider)
        .where((candidate) => candidate.matchId == matchId)
        .firstOrNull;
    final colorScheme = Theme.of(context).colorScheme;
    final percent = ((job?.progress ?? 0) * 100).round().clamp(0, 100);
    final determinate =
        job != null && job.progress > 0.05 && !job.isFailed;
    final label = switch (job?.phase) {
      VideoUploadPhase.preparing => 'Preparing clip…',
      VideoUploadPhase.moderating => 'Checking clip…',
      VideoUploadPhase.uploading => 'Uploading $percent%',
      VideoUploadPhase.finishing => 'Finishing…',
      VideoUploadPhase.failed => 'Upload failed',
      null => 'Uploading…',
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 4,
            value: determinate ? job.progress.clamp(0.0, 1.0) : null,
            color: colorScheme.inversePrimary,
            backgroundColor: colorScheme.onInverseSurface.withValues(
              alpha: 0.22,
            ),
          ),
        ),
      ],
    );
  }
}

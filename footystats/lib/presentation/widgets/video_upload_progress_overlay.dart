import 'package:flutter/material.dart';

import '../providers/video_upload_queue_provider.dart';

/// Dark overlay with centered percent, meant to sit on a video thumbnail.
class VideoUploadProgressOverlay extends StatelessWidget {
  const VideoUploadProgressOverlay({
    super.key,
    required this.job,
    this.compact = false,
  });

  final VideoUploadJob job;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final percent = (job.progress.clamp(0.0, 1.0) * 100).round();
    final determinate = job.progress > 0.05 && !job.isFailed;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black54,
        child: Center(
          child: job.isFailed
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: compact ? 18 : 32,
                    ),
                    SizedBox(height: compact ? 2 : 8),
                    Text(
                      compact ? 'Failed' : 'Upload failed',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 9 : 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Tap to dismiss',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: compact ? 22 : 40,
                      height: compact ? 22 : 40,
                      child: CircularProgressIndicator(
                        value: determinate ? job.progress.clamp(0.0, 1.0) : null,
                        strokeWidth: compact ? 2.2 : 3,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 10),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 10 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

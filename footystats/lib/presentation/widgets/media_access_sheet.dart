import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Device permission needed before camera / library access.
enum MediaAccessKind {
  camera,
  photos,
  videos,
}

extension MediaAccessKindX on MediaAccessKind {
  String get title {
    switch (this) {
      case MediaAccessKind.camera:
        return 'Allow camera access';
      case MediaAccessKind.photos:
        return 'Allow photo access';
      case MediaAccessKind.videos:
        return 'Allow video access';
    }
  }

  String get message {
    switch (this) {
      case MediaAccessKind.camera:
        return 'Ballo needs camera access so you can take a photo. '
            'Turn it on in Settings to continue.';
      case MediaAccessKind.photos:
        return 'Ballo needs access to your photos so you can upload an image. '
            'Turn it on in Settings to continue.';
      case MediaAccessKind.videos:
        return 'Ballo needs access to your videos so you can upload a clip. '
            'Turn it on in Settings to continue.';
    }
  }

  IconData get icon {
    switch (this) {
      case MediaAccessKind.camera:
        return Icons.photo_camera_outlined;
      case MediaAccessKind.photos:
        return Icons.photo_library_outlined;
      case MediaAccessKind.videos:
        return Icons.videocam_outlined;
    }
  }

  Permission get permission {
    switch (this) {
      case MediaAccessKind.camera:
        return Permission.camera;
      case MediaAccessKind.photos:
        return Permission.photos;
      case MediaAccessKind.videos:
        final bool isCupertino = !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.macOS);
        return isCupertino ? Permission.photos : Permission.videos;
    }
  }
}

MediaAccessKind mediaAccessKindForImageSource(ImageSource source) {
  return source == ImageSource.camera
      ? MediaAccessKind.camera
      : MediaAccessKind.photos;
}

/// Requests the permission for [kind]. If it is still blocked, shows a
/// settings prompt. Returns true only when the picker can proceed.
Future<bool> ensureMediaAccess(
  BuildContext context,
  MediaAccessKind kind,
) async {
  if (kIsWeb) return true;

  try {
    var status = await kind.permission.status;
    if (_isUsable(status)) return true;

    if (status.isDenied) {
      status = await kind.permission.request();
      if (_isUsable(status)) return true;
    }

    if (!context.mounted) return false;
    await showMediaAccessSheet(context, kind: kind);
    return false;
  } catch (_) {
    if (!context.mounted) return false;
    await showMediaAccessSheet(context, kind: kind);
    return false;
  }
}

Future<bool> ensureMediaAccessForImageSource(
  BuildContext context,
  ImageSource source,
) {
  return ensureMediaAccess(context, mediaAccessKindForImageSource(source));
}

bool _isUsable(PermissionStatus status) =>
    status.isGranted || status.isLimited || status.isProvisional;

bool isMediaPermissionError(Object error) {
  if (error is PlatformException) {
    final code = error.code.toLowerCase();
    final message = (error.message ?? '').toLowerCase();
    return code.contains('access_denied') ||
        code.contains('access_restricted') ||
        code.contains('permission') ||
        message.contains('access_denied') ||
        message.contains('permission');
  }
  final text = error.toString().toLowerCase();
  return text.contains('access_denied') ||
      text.contains('photo_access') ||
      text.contains('camera_access') ||
      text.contains('permission_denied');
}

/// Shows the settings sheet when [error] is a camera/photos/videos denial.
/// Returns true when the error was handled this way.
Future<bool> presentMediaAccessSheetIfNeeded(
  BuildContext context,
  Object error,
  MediaAccessKind kind,
) async {
  if (!isMediaPermissionError(error)) return false;
  if (!context.mounted) return true;
  await showMediaAccessSheet(context, kind: kind);
  return true;
}

/// Bottom sheet matching [showGuestAccountSheet]: icon, title, copy, primary
/// action to open system Settings.
Future<void> showMediaAccessSheet(
  BuildContext context, {
  required MediaAccessKind kind,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                kind.icon,
                size: 40,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                kind.title,
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                kind.message,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  await openAppSettings();
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text('Open settings'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

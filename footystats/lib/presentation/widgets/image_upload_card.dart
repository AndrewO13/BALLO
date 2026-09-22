import 'package:flutter/material.dart';
import '../../core/widgets/media_placeholders.dart';

class ImageUploadCard extends StatelessWidget {
  const ImageUploadCard({
    super.key,
    required this.imageUrl,
    required this.isUploading,
    required this.emptyLabel,
    required this.onTap,
    this.isCircular = false,
    this.onClear,
    this.overlayLabel,
    this.emptySubtitle,
    this.emptyIcon,
  });

  final String? imageUrl;
  final bool isUploading;
  final String emptyLabel;
  final VoidCallback onTap;
  final bool isCircular;
  final VoidCallback? onClear;
  final String? overlayLabel;
  final String? emptySubtitle;
  final IconData? emptyIcon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final trimmed = imageUrl?.trim() ?? '';
    final hasImage = trimmed.isNotEmpty;
    final isNetwork =
        trimmed.startsWith('http://') || trimmed.startsWith('https://');

    Widget buildImage({required bool circular}) {
      if (!hasImage) return const SizedBox.shrink();
      final child = isNetwork
          ? Image(
              image: appCachedImageProvider(trimmed),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: colorScheme.error,
                ),
              ),
            )
          : Image.asset(
              trimmed,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: colorScheme.error,
                ),
              ),
            );
      return circular ? ClipOval(child: child) : child;
    }

    if (isCircular) {
      return Center(
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: isUploading ? null : onTap,
          child: SizedBox(
            width: 132,
            height: 132,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.surfaceContainerHigh,
                    border: Border.all(
                      color: hasImage
                          ? colorScheme.primary.withValues(alpha: 0.5)
                          : colorScheme.outlineVariant,
                      width: hasImage ? 1.5 : 1,
                    ),
                  ),
                  child: isUploading
                      ? const Center(child: CircularProgressIndicator())
                      : hasImage
                      ? buildImage(circular: true)
                      : Center(
                          child: Icon(
                            Icons.add_a_photo_outlined,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
                if (!isUploading)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                if (onClear != null && hasImage)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: CircleAvatar(
                      backgroundColor: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.92),
                      child: IconButton(
                        onPressed: onClear,
                        icon: const Icon(Icons.close),
                        iconSize: 14,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: isUploading ? null : onTap,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasImage
                ? colorScheme.primary.withValues(alpha: 0.5)
                : colorScheme.outlineVariant,
            width: hasImage ? 1.5 : 1,
          ),
        ),
        child: isUploading
            ? const Center(child: CircularProgressIndicator())
            : hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: buildImage(circular: false),
                  ),
                  if (overlayLabel != null && overlayLabel!.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.0),
                              Colors.black.withValues(alpha: 0.45),
                            ],
                          ),
                        ),
                        child: Text(
                          overlayLabel!,
                          style: textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  if (onClear != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filledTonal(
                        onPressed: onClear,
                        icon: const Icon(Icons.close),
                      ),
                    ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      emptyIcon ?? Icons.stadium_outlined,
                      size: 34,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      emptyLabel,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (emptySubtitle != null && emptySubtitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        emptySubtitle!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

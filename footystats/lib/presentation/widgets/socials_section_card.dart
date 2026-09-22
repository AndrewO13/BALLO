import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Card with a title and circular Instagram / TikTok / X buttons (matches Overview styling).
///
/// Always shows all three platforms; taps work only when a URL is set. When all are empty,
/// [emptyHint] (or a default line) appears under the row.
class SocialsSectionCard extends StatelessWidget {
  const SocialsSectionCard({
    super.key,
    required this.title,
    this.instagramUrl,
    this.tiktokUrl,
    this.xUrl,
    this.emptyHint,
  });

  final String title;
  final String? instagramUrl;
  final String? tiktokUrl;
  final String? xUrl;

  /// Shown when every URL is missing (e.g. how to add links on the profile tab).
  final String? emptyHint;

  static String? normalizeUrl(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    return s.isEmpty ? null : s;
  }

  static Future<void> tryOpenUrl(BuildContext context, String? raw) async {
    final url = normalizeUrl(raw);
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https'))) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid link')),
        );
      }
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ig = normalizeUrl(instagramUrl);
    final tt = normalizeUrl(tiktokUrl);
    final x = normalizeUrl(xUrl);
    final allEmpty = ig == null && tt == null && x == null;

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget circleButton({
      required FaIconData icon,
      required String? url,
    }) {
      final enabled = url != null;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? () => tryOpenUrl(context, url) : null,
          child: Ink(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: enabled ? 1.0 : 0.45,
              ),
            ),
            child: Center(
              child: FaIcon(
                icon,
                size: 22,
                color: enabled
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              circleButton(icon: FontAwesomeIcons.instagram, url: ig),
              const SizedBox(width: 12),
              circleButton(icon: FontAwesomeIcons.tiktok, url: tt),
              const SizedBox(width: 12),
              circleButton(icon: FontAwesomeIcons.xTwitter, url: x),
            ],
          ),
          if (allEmpty) ...[
            const SizedBox(height: 12),
            Text(
              emptyHint ?? 'No social links added yet.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

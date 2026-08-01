import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';

/// A settings row with a tinted icon chip - the same visual language as the
/// stat cards, so these read as part of the app rather than a bare list.
class SettingsNavTile extends StatelessWidget {
  /// Built with the resolved tone colour. A builder rather than an
  /// [IconData] because the WhatsApp glyph is a FontAwesome brand icon,
  /// which only renders inside `FaIcon`.
  final Widget Function(Color color) icon;
  final AppTone tone;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const SettingsNavTile({
    super.key,
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  /// Convenience for the common case of a plain Material icon.
  static Widget Function(Color) material(IconData data) =>
      (color) => Icon(data, size: 18, color: color);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = context.tones;
    final toneColors = tones.byTone(tone);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageGutter,
        vertical: AppSpacing.xxs,
      ),
      leading: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: toneColors.bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: toneColors.border),
        ),
        child: icon(toneColors.fg),
      ),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(color: tones.textTertiary),
      ),
      trailing: Icon(Icons.chevron_right, color: tones.textTertiary),
      onTap: onTap,
    );
  }
}

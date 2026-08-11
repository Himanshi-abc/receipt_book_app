import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../models/support_content.dart';
import '../../../l10n/app_localizations.dart';

/// Renders any [LegalDocument] - About, Privacy Policy, Terms.
///
/// One screen for all three because they differ only in words. Long-form
/// text gets a reading-width cap and generous line height: these are the
/// screens users actually have to read, and a 1400dp-wide line on the
/// Windows build is genuinely hard to follow.
class LegalDocumentScreen extends StatelessWidget {
  final LegalDocument document;

  const LegalDocumentScreen({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = context.tones;

    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: tones.textSecondary,
      height: 1.55,
    );

    return Scaffold(
      appBar: AppBar(title: Text(document.title)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageGutter,
              AppSpacing.lg,
              AppSpacing.pageGutter,
              AppSpacing.giant,
            ),
            children: [
              Text(document.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppLocalizations.of(context)
                    .lastUpdatedOn(document.lastUpdated),
                style: theme.textTheme.labelSmall?.copyWith(color: tones.textTertiary),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final section in document.sections) ...[
                if (section.heading != null) ...[
                  Text(
                    section.heading!,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                for (final paragraph in section.paragraphs) ...[
                  Text(paragraph, style: bodyStyle),
                  const SizedBox(height: AppSpacing.md),
                ],
                for (final bullet in section.bullets) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // A dot glyph inside the Text would wrap under itself
                        // on the second line; a fixed-width leading column
                        // keeps the hanging indent.
                        SizedBox(
                          width: 18,
                          child: Text('•', style: bodyStyle),
                        ),
                        Expanded(child: Text(bullet, style: bodyStyle)),
                      ],
                    ),
                  ),
                ],
                if (section.bullets.isNotEmpty) const SizedBox(height: AppSpacing.sm),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

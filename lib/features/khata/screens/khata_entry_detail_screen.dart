import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/models/contact_model.dart';
import '../../../core/models/khata_entry_model.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/detail_row.dart';
import '../../../l10n/app_localizations.dart';

/// Read-only view of a single ledger entry ("View Invoice" from the
/// entry action sheet - see PartyDetailScreen). Labeled "Invoice" in the UI
/// to match how the user refers to a ledger entry, even though it's not the
/// app's separate multi-line-item GST Invoice feature.
///
/// The label/value rows come from [DetailRow], which already handles the
/// phone case (caption above a full-width value) - so all this screen has to
/// get right for a phone is capping the attachment preview, which is
/// otherwise laid out at the image's own size.
class KhataEntryDetailScreen extends StatelessWidget {
  final KhataEntry entry;
  final Contact contact;
  const KhataEntryDetailScreen({required this.entry, required this.contact, super.key});

  /// A tall receipt photo used to render at full height, pushing everything
  /// else off a phone screen. Capped and cropped to a consistent preview
  /// band instead; the file itself is unchanged.
  static const double _attachmentPreviewHeight = 320;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tones = context.tones;
    final isGave = entry.type == KhataEntryType.youGave;
    final typeLabel = isGave ? l10n.khataYouGave : l10n.khataYouGot;

    final attachmentSection = entry.attachments.isEmpty
        ? <Widget>[
            Text(
              l10n.noFileAttached,
              style: theme.textTheme.bodyMedium?.copyWith(color: tones.textTertiary),
            )
          ]
        : entry.attachments
            .map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: a.isImageFile
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: _attachmentPreviewHeight,
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              child: a.localPath != null
                                  ? Image.file(File(a.localPath!), fit: BoxFit.cover)
                                  : Image.network(a.url, fit: BoxFit.cover),
                            ),
                          ),
                        )
                      : Card(
                          child: ListTile(
                            leading: const Icon(Icons.insert_drive_file, size: 32),
                            title: Text(
                              a.fileName ?? l10n.attachedFile,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                ))
            .toList();

    return Scaffold(
      appBar: AppBar(title: Text(typeLabel)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          DetailRow(label: l10n.fieldParty, value: contact.name),
          DetailRow(label: l10n.fieldType, value: typeLabel),
          DetailRow(label: l10n.fieldAmount, value: Money.format(entry.amountPaise)),
          DetailRow(
              label: l10n.date,
              value: '${entry.date.day}/${entry.date.month}/${entry.date.year}'),
          if (entry.description != null && entry.description!.trim().isNotEmpty)
            DetailRow(label: l10n.fieldDescription, value: entry.description!),
          if (entry.pendingSync)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xxs),
              child: Row(
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 16, color: tones.textTertiary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    l10n.waitingToSync,
                    style: theme.textTheme.bodySmall?.copyWith(color: tones.textTertiary),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.attachment, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          ...attachmentSection,
        ],
      ),
    );
  }
}
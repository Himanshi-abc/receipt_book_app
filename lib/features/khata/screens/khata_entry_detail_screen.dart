import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/models/contact_model.dart';
import '../../../core/models/khata_entry_model.dart';
import '../../../core/utils/money.dart';

/// Read-only view of a single ledger entry ("View Invoice" from the
/// entry action sheet - see PartyDetailScreen). Labeled "Invoice" in the UI
/// to match how the user refers to a ledger entry, even though it's not the
/// app's separate multi-line-item GST Invoice feature.
class KhataEntryDetailScreen extends StatelessWidget {
  final KhataEntry entry;
  final Contact contact;
  const KhataEntryDetailScreen({required this.entry, required this.contact, super.key});

  @override
  Widget build(BuildContext context) {
    final isGave = entry.type == KhataEntryType.youGave;

    final attachmentSection = entry.attachments.isEmpty
        ? <Widget>[Text('No file attached', style: TextStyle(color: Colors.grey.shade600))]
        : entry.attachments
            .map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: a.isImageFile
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: a.localPath != null
                              ? Image.file(File(a.localPath!))
                              : Image.network(a.url),
                        )
                      : Card(
                          child: ListTile(
                            leading: const Icon(Icons.insert_drive_file, size: 32),
                            title: Text(a.fileName ?? 'Attached file'),
                          ),
                        ),
                ))
            .toList();

    return Scaffold(
      appBar: AppBar(title: Text(isGave ? 'You Gave' : 'You Got')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _row('Party', contact.name),
          _row('Type', isGave ? 'You Gave' : 'You Got'),
          _row('Amount', Money.format(entry.amountPaise)),
          _row('Date', '${entry.date.day}/${entry.date.month}/${entry.date.year}'),
          if (entry.description != null && entry.description!.trim().isNotEmpty)
            _row('Description', entry.description!),
          if (entry.pendingSync)
            const Padding(
              padding: EdgeInsets.only(top: 12, bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 16, color: Colors.grey),
                  SizedBox(width: 6),
                  Text('Waiting to sync', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Text('Attachment', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...attachmentSection,
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 140, child: Text(label, style: const TextStyle(color: Colors.grey))),
            Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
          ],
        ),
      );
}

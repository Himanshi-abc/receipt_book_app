import 'package:flutter/material.dart';

/// Compact, one-row representation of a receipt attachment: a file-type
/// icon (never a rendered inline preview), the file name, and up to four
/// actions (View/Share/Delete/Download). Used on both the transaction entry
/// form and the transaction detail screen (Individual Book and Business
/// Book alike) so a receipt never takes over the screen with a full-size
/// image.
class AttachmentCard extends StatelessWidget {
  final String fileName;
  final bool isImage;
  final VoidCallback? onView;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;
  final VoidCallback? onDownload;

  const AttachmentCard({
    super.key,
    required this.fileName,
    required this.isImage,
    this.onView,
    this.onShare,
    this.onDelete,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined),
        title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onView != null)
              IconButton(
                tooltip: 'View',
                icon: const Icon(Icons.visibility_outlined),
                onPressed: onView,
              ),
            if (onShare != null)
              IconButton(
                tooltip: 'Share',
                icon: const Icon(Icons.share_outlined),
                onPressed: onShare,
              ),
            if (onDelete != null)
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
            if (onDownload != null)
              IconButton(
                tooltip: 'Download',
                icon: const Icon(Icons.download_outlined),
                onPressed: onDownload,
              ),
          ],
        ),
      ),
    );
  }
}

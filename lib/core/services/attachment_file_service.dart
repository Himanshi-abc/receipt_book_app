import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show NetworkAssetBundle;
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/transaction_model.dart';
import '../widgets/full_screen_image_viewer.dart';

/// Individual Book and Business Book alike: lets the user View, Share,
/// Download, or permanently remove a receipt attachment from the
/// transaction entry form and the transaction detail screen - whether it's
/// still local-only (pre-sync) or already uploaded to Storage. Deliberately
/// never renders a full inline preview; images are only shown full-screen
/// on explicit "View" tap (see AttachmentCard).
class AttachmentFileService {
  AttachmentFileService._();

  static Future<Uint8List> _bytesFor(ReceiptImage img) async {
    if (img.localPath != null) {
      return File(img.localPath!).readAsBytes();
    }
    final data = await NetworkAssetBundle(Uri.parse(img.imageUrl)).load(img.imageUrl);
    return data.buffer.asUint8List();
  }

  static String fileNameFor(ReceiptImage img) {
    if (img.fileName != null && img.fileName!.isNotEmpty) return img.fileName!;
    if (img.localPath != null) return p.basename(img.localPath!);
    final urlName = p.basename(Uri.parse(img.imageUrl).path);
    return urlName.isNotEmpty ? urlName : 'receipt_${img.uploadedAt.millisecondsSinceEpoch}';
  }

  static Future<void> share(ReceiptImage img) async {
    final bytes = await _bytesFor(img);
    final name = fileNameFor(img);
    await Share.shareXFiles([XFile.fromData(bytes, name: name)]);
  }

  /// Saves a copy straight to device storage (no share-sheet round trip) -
  /// via file_picker's native "Save As" dialog, so the user picks (and can
  /// see) exactly where it lands, e.g. Downloads. Returns false if the user
  /// cancelled the dialog; throws if the save itself fails.
  static Future<bool> download(ReceiptImage img) async {
    final bytes = await _bytesFor(img);
    final name = fileNameFor(img);
    final path = await FilePicker.platform.saveFile(fileName: name, bytes: bytes);
    return path != null;
  }

  /// Images open in a full-screen in-app viewer. Anything else (PDF, doc,
  /// etc.) is handed off to the device's default app for that file type;
  /// if nothing can open it, the caller is told via a snackbar.
  static Future<void> view(BuildContext context, ReceiptImage img) async {
    if (img.isImageFile) {
      final provider = img.localPath != null
          ? FileImage(File(img.localPath!)) as ImageProvider
          : NetworkImage(img.imageUrl);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageProvider: provider)),
      );
      return;
    }

    final uri = img.localPath != null ? Uri.file(img.localPath!) : Uri.parse(img.imageUrl);
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open this file. Try Share instead.")),
      );
    }
  }

  /// Best-effort cleanup of the underlying file once its reference has been
  /// removed from a saved transaction - never surfaced as an error, since
  /// the reference removal (the part the user actually asked for) already
  /// succeeded regardless of whether this cleanup does.
  static Future<void> deleteUnderlyingFile(ReceiptImage img) async {
    if (img.localPath != null) {
      try {
        await File(img.localPath!).delete();
      } catch (_) {}
    }
    if (img.imageUrl.isNotEmpty) {
      try {
        await FirebaseStorage.instance.refFromURL(img.imageUrl).delete();
      } catch (_) {}
    }
  }
}

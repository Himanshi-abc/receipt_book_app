import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/transaction_model.dart';
import '../services/ocr_service.dart';
import 'ocr_review_form_screen.dart';

/// SRS 4.2: "Camera opens (or pick photo from gallery)... simple frame
/// guide for aligning the receipt" (screen 4 in Section 6).
///
/// This MVP uses image_picker's native camera UI (fast, works out of the
/// box on both platforms). A custom live-preview with an on-screen frame
/// overlay can be swapped in later using the `camera` package without
/// touching anything downstream of the picked file.
class CameraCaptureScreen extends StatefulWidget {
  final TxType type;
  const CameraCaptureScreen({super.key, required this.type});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  final _picker = ImagePicker();
  bool _processing = false;

  Future<void> _pick(ImageSource source) async {
    final xfile = await _picker.pickImage(source: source, imageQuality: 85);
    if (xfile == null) return;
    setState(() => _processing = true);

    final file = File(xfile.path);
    final ocrService = OcrService();
    // SRS 8: "OCR is a convenience, not a requirement." If this throws or
    // returns nothing useful, OcrResult.success is false and the review
    // form simply opens blank - saving is never blocked by this call.
    final result = await ocrService.scanReceipt(file);
    ocrService.dispose();

    if (!mounted) return;
    setState(() => _processing = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OcrReviewFormScreen(
          type: widget.type,
          imageFile: file,
          ocrResult: result,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.type == TxType.income ? 'Scan Income Receipt' : 'Scan Expense Receipt')),
      body: Center(
        child: _processing
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Reading receipt...'),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 260,
                    height: 340,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('Align receipt\nwithin frame', textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                    onPressed: () => _pick(ImageSource.camera),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Choose from Gallery'),
                    onPressed: () => _pick(ImageSource.gallery),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OcrReviewFormScreen(
                          type: widget.type,
                          imageFile: null,
                          ocrResult: OcrResult.failed(),
                        ),
                      ),
                    ),
                    child: const Text('Enter manually instead'),
                  ),
                ],
              ),
      ),
    );
  }
}

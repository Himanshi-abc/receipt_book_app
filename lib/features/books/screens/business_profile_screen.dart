import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../../core/models/book_model.dart';
import '../providers/book_provider.dart';
import 'add_business_book_screen.dart' show kIndianStates;

/// Turns a raw Storage exception into something actionable, for the logo/
/// signature uploads below.
///
/// `unauthorized` / `unauthenticated` / `object-not-found` / `unknown` here
/// (as opposed to a rule genuinely denying one particular user) almost
/// always means the *whole project* lost access to Cloud Storage - the most
/// common cause, as of the Feb 2026 policy change, is the Firebase project
/// still being on the free Spark plan, which no longer gets any Storage
/// access at all (reads and writes both return 402/403, on every platform -
/// this has nothing to do with logo/signature specifically, or with
/// Windows). If that's it, every other Storage upload in the app -
/// receipts, invoice PDFs - is failing exactly the same way; they just
/// retry silently in the background instead of telling anyone, which is
/// why this screen is the one place the problem actually gets seen.
///
/// A free function, not a method, so this logic can be tested without a
/// widget around it - see [_BusinessProfileScreenState._pickAndUploadImage],
/// its only caller.
String businessProfileStorageErrorMessage(
  FirebaseException e, {
  required bool isSignature,
}) {
  final what = isSignature ? 'signature' : 'logo';
  const billingLikelyCodes = {'unauthorized', 'unauthenticated', 'object-not-found', 'unknown'};
  if (billingLikelyCodes.contains(e.code)) {
    return "Couldn't upload the $what - Cloud Storage isn't reachable "
        '(${e.code}). If this project is still on Firebase\'s free Spark '
        'plan, Storage requires the Blaze plan as of Feb 2026 - check '
        'Firebase Console > Project Settings > Usage and billing.';
  }
  return "Couldn't upload the $what: ${e.code} - ${e.message ?? 'no further detail from Firebase.'}";
}

/// Full Business Profile for the current Business Book - reached from
/// Settings. Unlike AddBusinessBookScreen (which only captures the
/// minimum needed to create a book), this covers everything a business
/// wants printed on its invoices: identity, branding, both addresses,
/// online presence, and payment/signature details.
class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  late final Book _book;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _gstinCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _brandNameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _shippingAddressCtrl;
  late final TextEditingController _websiteCtrl;
  late final TextEditingController _bankHolderCtrl;
  late final TextEditingController _bankNameCtrl;
  late final TextEditingController _bankAccountCtrl;
  late final TextEditingController _ifscCtrl;

  String? _state;
  bool _shippingSameAsBilling = true;
  String? _logoUrl;
  String? _signatureUrl;
  bool _uploadingLogo = false;
  bool _uploadingSignature = false;
  bool _saving = false;

  bool get _canSave =>
      !_saving &&
      _nameCtrl.text.trim().isNotEmpty &&
      _phoneCtrl.text.trim().isNotEmpty &&
      _state != null &&
      _addressCtrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _book = context.read<BookProvider>().currentBook!;

    _nameCtrl = TextEditingController(text: _book.name);
    _gstinCtrl = TextEditingController(text: _book.gstin ?? '');
    _phoneCtrl = TextEditingController(text: _book.phone ?? '');
    _brandNameCtrl = TextEditingController(text: _book.brandName ?? '');
    _addressCtrl = TextEditingController(text: _book.address ?? '');
    _shippingAddressCtrl = TextEditingController(text: _book.shippingAddress ?? '');
    _websiteCtrl = TextEditingController(text: _book.website ?? '');
    _bankHolderCtrl = TextEditingController(text: _book.bankDetails.accountHolderName ?? '');
    _bankNameCtrl = TextEditingController(text: _book.bankDetails.bankName ?? '');
    _bankAccountCtrl = TextEditingController(text: _book.bankDetails.accountNumber ?? '');
    _ifscCtrl = TextEditingController(text: _book.bankDetails.ifscCode ?? '');

    _state = _book.state;
    _shippingSameAsBilling =
        _book.shippingAddress == null || _book.shippingAddress!.trim().isEmpty;
    _logoUrl = _book.logoUrl;
    _signatureUrl = _book.signatureUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _gstinCtrl.dispose();
    _phoneCtrl.dispose();
    _brandNameCtrl.dispose();
    _addressCtrl.dispose();
    _shippingAddressCtrl.dispose();
    _websiteCtrl.dispose();
    _bankHolderCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccountCtrl.dispose();
    _ifscCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage({required bool isSignature}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final xfile = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (xfile == null || !mounted) return;

    setState(() {
      if (isSignature) {
        _uploadingSignature = true;
      } else {
        _uploadingLogo = true;
      }
    });

    try {
      final ext = p.extension(xfile.path).isEmpty ? '.jpg' : p.extension(xfile.path);
      final folder = isSignature ? 'book_signatures' : 'book_logos';
      final fileName = isSignature ? 'signature' : 'logo';
      final ref = FirebaseStorage.instance.ref('$folder/${_book.id}/$fileName$ext');
      await ref.putFile(File(xfile.path));
      final url = await ref.getDownloadURL();
      if (!mounted) return;
      setState(() {
        if (isSignature) {
          _signatureUrl = url;
        } else {
          _logoUrl = url;
        }
      });
    } on FirebaseException catch (e) {
      // This is the only Storage upload path in the app that surfaces its
      // failure to the user at all - the receipt-photo and invoice-PDF
      // uploads elsewhere both fail silently and retry later in the
      // background (deliberately - see OcrReviewFormScreen's
      // _uploadReceiptInBackground). So a Storage problem that's actually
      // affecting the whole project - not just this screen - will only
      // ever be *seen* here, which makes the raw exception worth turning
      // into something a non-technical user (and future-us) can act on.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(businessProfileStorageErrorMessage(e, isSignature: isSignature)),
          duration: const Duration(seconds: 10),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not upload ${isSignature ? 'signature' : 'logo'}: $e'),
          duration: const Duration(seconds: 6),
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          if (isSignature) {
            _uploadingSignature = false;
          } else {
            _uploadingLogo = false;
          }
        });
      }
    }
  }

  void _removeImage({required bool isSignature}) {
    setState(() {
      if (isSignature) {
        _signatureUrl = null;
      } else {
        _logoUrl = null;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final bookProvider = context.read<BookProvider>();

    final shippingAddress = _shippingSameAsBilling
        ? null
        : (_shippingAddressCtrl.text.trim().isEmpty ? null : _shippingAddressCtrl.text.trim());

    final bankDetails = BankAccountDetails(
      accountHolderName:
          _bankHolderCtrl.text.trim().isEmpty ? null : _bankHolderCtrl.text.trim(),
      bankName: _bankNameCtrl.text.trim().isEmpty ? null : _bankNameCtrl.text.trim(),
      accountNumber:
          _bankAccountCtrl.text.trim().isEmpty ? null : _bankAccountCtrl.text.trim(),
      ifscCode: _ifscCtrl.text.trim().isEmpty ? null : _ifscCtrl.text.trim(),
    );

    await bookProvider.updateBook(_book.id, {
      'name': _nameCtrl.text.trim(),
      'gstin': _gstinCtrl.text.trim().isEmpty ? null : _gstinCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'brandName': _brandNameCtrl.text.trim().isEmpty ? null : _brandNameCtrl.text.trim(),
      'logoUrl': _logoUrl,
      'state': _state,
      'address': _addressCtrl.text.trim(),
      'shippingAddress': shippingAddress,
      'website': _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
      'bankDetails': bankDetails.toMap(),
      'signatureUrl': _signatureUrl,
    });

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Business profile saved')));
      Navigator.of(context).pop();
    }
  }

  Widget _sectionCard({required String title, String? subtitle, required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: Text(subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker({
    required String label,
    required String? url,
    required bool uploading,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 72,
          height: 72,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: uploading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : url != null
                  ? Image.network(url, fit: BoxFit.cover)
                  : Icon(Icons.image_outlined, color: Colors.grey.shade400, size: 32),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  OutlinedButton(
                    onPressed: uploading ? null : onPick,
                    child: Text(url == null ? 'Upload' : 'Change'),
                  ),
                  if (url != null)
                    TextButton(
                      onPressed: uploading ? null : onRemove,
                      child: const Text('Remove'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionCard(
            title: 'Business Details',
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Business/Company Name *'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _gstinCtrl,
                decoration: const InputDecoration(labelText: 'GST Number (optional)'),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Business Phone Number *',
                  prefixIcon: Icon(Icons.call_outlined),
                ),
                keyboardType: TextInputType.phone,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          _sectionCard(
            title: 'Branding',
            subtitle: 'Shown on your invoices and other customer-facing documents.',
            children: [
              TextField(
                controller: _brandNameCtrl,
                decoration: const InputDecoration(labelText: 'Brand Name (optional)'),
              ),
              const SizedBox(height: 16),
              _buildImagePicker(
                label: 'Brand Logo (optional)',
                url: _logoUrl,
                uploading: _uploadingLogo,
                onPick: () => _pickAndUploadImage(isSignature: false),
                onRemove: () => _removeImage(isSignature: false),
              ),
            ],
          ),
          _sectionCard(
            title: 'Billing Address',
            children: [
              DropdownButtonFormField<String>(
                initialValue: _state,
                decoration: const InputDecoration(labelText: 'State *'),
                items: kIndianStates.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _state = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'Billing Address *'),
                maxLines: 3,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          _sectionCard(
            title: 'Shipping Address',
            subtitle: 'Optional - shown on invoices only if different from billing.',
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _shippingSameAsBilling,
                title: const Text('Same as billing address'),
                onChanged: (v) => setState(() => _shippingSameAsBilling = v ?? true),
              ),
              if (!_shippingSameAsBilling)
                TextField(
                  controller: _shippingAddressCtrl,
                  decoration: const InputDecoration(labelText: 'Shipping Address'),
                  maxLines: 3,
                ),
            ],
          ),
          _sectionCard(
            title: 'Online Presence',
            children: [
              TextField(
                controller: _websiteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Website (optional)',
                  prefixIcon: Icon(Icons.language_outlined),
                ),
                keyboardType: TextInputType.url,
              ),
            ],
          ),
          _sectionCard(
            title: 'Bank Account Details',
            subtitle: 'Optional - shown on invoices so customers can pay you directly.',
            children: [
              TextField(
                controller: _bankHolderCtrl,
                decoration: const InputDecoration(labelText: 'Account Holder Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bankNameCtrl,
                decoration: const InputDecoration(labelText: 'Bank Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bankAccountCtrl,
                decoration: const InputDecoration(labelText: 'Account Number'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ifscCtrl,
                decoration: const InputDecoration(labelText: 'IFSC Code'),
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ),
          _sectionCard(
            title: 'Signature',
            subtitle: 'Optional - appears on invoices as an authorized signatory mark.',
            children: [
              _buildImagePicker(
                label: 'Signature Image',
                url: _signatureUrl,
                uploading: _uploadingSignature,
                onPick: () => _pickAndUploadImage(isSignature: true),
                onRemove: () => _removeImage(isSignature: true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _canSave ? _save : null,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save Business Profile'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

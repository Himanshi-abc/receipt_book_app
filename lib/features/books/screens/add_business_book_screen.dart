import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/book_provider.dart';

/// Deliberately NOT localized. This value is persisted on the Book and on
/// every invoice, and `GstService.computeBreakup` decides CGST+SGST vs IGST
/// by string-comparing the business state against the customer state. If
/// the picker wrote a translated name, a book created in Hindi and a
/// customer added in English would never compare equal and every invoice
/// would silently switch to IGST. State names are also written in English
/// on the GST portal, so this matches what users see on their filings.
const kIndianStates = [
  'Andhra Pradesh', 'Bihar', 'Delhi', 'Gujarat', 'Karnataka', 'Kerala',
  'Madhya Pradesh', 'Maharashtra', 'Punjab', 'Rajasthan', 'Tamil Nadu',
  'Telangana', 'Uttar Pradesh', 'West Bengal',
];

class AddBusinessBookScreen extends StatefulWidget {
  const AddBusinessBookScreen({super.key});

  @override
  State<AddBusinessBookScreen> createState() => _AddBusinessBookScreenState();
}

class _AddBusinessBookScreenState extends State<AddBusinessBookScreen> {
  final _nameCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String? _state;
  bool _busy = false;

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty || _state == null) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    final userId = context.read<AuthProvider>().user!.uid;
    final bookProvider = context.read<BookProvider>();
    final isFirstBusinessBook =
        !bookProvider.books.any((b) => b.isBusiness);

    await bookProvider.createBusinessBook(
      userId: userId,
      name: _nameCtrl.text.trim(),
      gstin: _gstinCtrl.text.trim().isEmpty ? null : _gstinCtrl.text.trim(),
      state: _state!,
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      l10n: l10n,
    );

    if (!mounted) return;
    if (isFirstBusinessBook) {
      // SRS 5.1: "Your 1-month free trial has started..."
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.freeTrialStartedTitle),
          content: Text(l10n.freeTrialStartedMessage),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx), child: Text(l10n.gotIt))
          ],
        ),
      );
    }
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.addBusinessBook)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: l10n.businessNameRequired)),
          const SizedBox(height: 12),
          TextField(
              controller: _gstinCtrl,
              decoration: InputDecoration(labelText: l10n.gstinOptional)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _state,
            decoration: InputDecoration(labelText: l10n.stateRequired),
            items: kIndianStates
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _state = v),
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _addressCtrl,
              decoration:
                  InputDecoration(labelText: l10n.businessAddressOptional)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _create,
            child: _busy
                ? const SizedBox(
                    height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.createBusinessBook),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/book_provider.dart';

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
    );

    if (!mounted) return;
    if (isFirstBusinessBook) {
      // SRS 5.1: "Your 1-month free trial has started..."
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Free trial started 🎉'),
          content: const Text(
              'Your 1-month free trial has started — create as many business books as you like during your trial.'),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Got it'))
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
    return Scaffold(
      appBar: AppBar(title: const Text('Add Business Book')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Business name *')),
          const SizedBox(height: 12),
          TextField(
              controller: _gstinCtrl,
              decoration: const InputDecoration(labelText: 'GSTIN (optional)')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _state,
            decoration: const InputDecoration(labelText: 'State *'),
            items: kIndianStates
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _state = v),
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(labelText: 'Business address (optional)')),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _create,
            child: _busy
                ? const SizedBox(
                    height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create Business Book'),
          ),
        ],
      ),
    );
  }
}

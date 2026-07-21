import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/services/transaction_repository.dart';
import '../../../core/utils/money.dart';
import '../../books/providers/book_provider.dart';

class TransactionDetailScreen extends StatefulWidget {
  final String transactionId;
  final String bookId;

  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
    required this.bookId,
  });

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final _repo = TransactionRepository();
  AppTransaction? _tx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _repo.loadTransactions(widget.bookId);
    setState(() {
      _tx = all.where((t) => t.id == widget.transactionId).firstOrNull;
    });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this transaction?'),
        content: const Text('This can be recovered from support within the retention window.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true && _tx != null) {
      await _repo.softDelete(_tx!);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final writable = context.watch<BookProvider>().currentBookIsWritable;
    if (_tx == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final tx = _tx!;
    final isIncome = tx.type == TxType.income;

    return Scaffold(
      appBar: AppBar(
        title: Text(isIncome ? 'Income' : 'Expense'),
        actions: [
          if (writable)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (tx.receiptImages.isNotEmpty)
            ...tx.receiptImages.map((img) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: img.localPath != null
                        ? Image.file(File(img.localPath!))
                        : Image.network(img.imageUrl),
                  ),
                ))
          else
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text('No receipt on file. Reason: ${tx.noReceiptReason ?? "-"}'),
              ),
            ),
          _row('Amount', Money.format(tx.amountPaise)),
          _row('Tax', Money.format(tx.taxAmountPaise)),
          _row(isIncome ? 'Payer / Customer' : 'Vendor', tx.vendorOrCustomerName),
          _row('Date', '${tx.date.day}/${tx.date.month}/${tx.date.year}'),
          _row('Financial Year', tx.financialYear),
          if (tx.notes != null) _row('Notes', tx.notes!),
          if (tx.businessUsePercent != null)
            _row('Business use', '${tx.businessUsePercent}%'),
          if (tx.pendingSync)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 16, color: Colors.grey),
                  SizedBox(width: 6),
                  Text('Waiting to sync', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

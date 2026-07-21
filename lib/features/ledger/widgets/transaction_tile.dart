import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/utils/money.dart';

class TransactionTile extends StatelessWidget {
  final AppTransaction transaction;
  final VoidCallback onTap;

  const TransactionTile({super.key, required this.transaction, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TxType.income;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: isIncome ? Colors.green.shade100 : Colors.red.shade100,
        child: Icon(
          isIncome ? Icons.arrow_downward : Icons.arrow_upward,
          color: isIncome ? Colors.green.shade800 : Colors.red.shade800,
        ),
      ),
      title: Text(transaction.vendorOrCustomerName.isEmpty
          ? '(No name)'
          : transaction.vendorOrCustomerName),
      subtitle: Text(DateFormat('dd MMM yyyy').format(transaction.date)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Money.format(transaction.amountPaise),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isIncome ? Colors.green.shade800 : Colors.red.shade800,
            ),
          ),
          if (transaction.pendingSync)
            const Icon(Icons.cloud_upload_outlined, size: 14, color: Colors.grey),
        ],
      ),
    );
  }
}

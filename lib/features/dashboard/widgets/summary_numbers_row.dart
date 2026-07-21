import 'package:flutter/material.dart';
import '../../../core/utils/money.dart';

class SummaryNumbersRow extends StatelessWidget {
  final int incomePaise;
  final int expensePaise;
  final int netPaise;

  const SummaryNumbersRow({
    super.key,
    required this.incomePaise,
    required this.expensePaise,
    required this.netPaise,
  });

  @override
  Widget build(BuildContext context) {
    final isProfit = netPaise >= 0;
    return Row(
      children: [
        Expanded(
          child: _NumberCard(
            label: 'Income',
            value: Money.format(incomePaise),
            color: Colors.green,
            icon: Icons.arrow_downward,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _NumberCard(
            label: 'Expense',
            value: Money.format(expensePaise),
            color: Colors.red,
            icon: Icons.arrow_upward,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _NumberCard(
            label: isProfit ? 'Net Profit' : 'Net Loss',
            value: Money.format(netPaise.abs()),
            color: isProfit ? Colors.teal : Colors.deepOrange,
            icon: isProfit ? Icons.trending_up : Icons.trending_down,
          ),
        ),
      ],
    );
  }
}

class _NumberCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _NumberCard(
      {required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(label,
                      style: TextStyle(fontSize: 12, color: color.withOpacity(0.9)),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

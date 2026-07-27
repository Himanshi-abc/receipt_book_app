import 'package:flutter/material.dart';
import '../../../core/utils/money.dart';

/// Three focused "till date" stat cards, same row: money owed TO the
/// business (from unpaid/partial Sales invoices), money the business owes
/// suppliers (from unpaid/partial Purchase bills), and Business Cashflow
/// (actual amount received from customers minus actual amount paid to
/// suppliers - real cash movement, not what's still owed). Same visual
/// language as the Bills section's own Total/Pending cards and the
/// Customers/Suppliers "You Collect"/"You Pay" cards, so the pattern reads
/// consistently everywhere it shows up in the app.
class OutstandingSummaryCards extends StatelessWidget {
  final int totalOutstandingPaise;
  final int outstandingBillsCount;
  final int totalPendingToSuppliersPaise;
  final int pendingSupplierBillsCount;
  final int businessCashflowPaise;

  const OutstandingSummaryCards({
    super.key,
    required this.totalOutstandingPaise,
    required this.outstandingBillsCount,
    required this.totalPendingToSuppliersPaise,
    required this.pendingSupplierBillsCount,
    required this.businessCashflowPaise,
  });

  @override
  Widget build(BuildContext context) {
    final cashflowPositive = businessCashflowPaise >= 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _StatCard(
            label: 'Total Outstanding Amount',
            sublabel: 'To Collect',
            amountPaise: totalOutstandingPaise,
            caption: outstandingBillsCount == 0
                ? 'No sales bills pending'
                : '$outstandingBillsCount sales bill(s) pending',
            color: Colors.green.shade700,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Total Unpaid Bills',
            sublabel: 'To Pay Suppliers',
            amountPaise: totalPendingToSuppliersPaise,
            caption: pendingSupplierBillsCount == 0
                ? 'No purchase bills pending'
                : '$pendingSupplierBillsCount purchase bill(s) pending',
            color: Colors.red.shade700,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Business Cashflow',
            sublabel: 'Received - Paid',
            amountPaise: businessCashflowPaise,
            caption: 'Till date',
            color: cashflowPositive ? Colors.green.shade700 : Colors.red.shade700,
            icon: cashflowPositive ? Icons.trending_up : Icons.trending_down,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String sublabel;
  final int amountPaise;
  final String caption;
  final Color color;
  final IconData? icon;

  const _StatCard({
    required this.label,
    required this.sublabel,
    required this.amountPaise,
    required this.caption,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(
                  icon ?? (color == Colors.green.shade700 ? Icons.call_received : Icons.call_made),
                  size: 14,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(sublabel, style: TextStyle(fontSize: 10, color: color.withOpacity(0.75))),
          ),
          const SizedBox(height: 10),
          Text(
            Money.format(amountPaise),
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(caption, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
        ],
      ),
    );
  }
}

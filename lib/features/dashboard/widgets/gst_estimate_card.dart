import 'package:flutter/material.dart';
import '../../../core/utils/money.dart';

/// SRS 4.4 + Section 8: GST payable must be "clearly labeled 'estimate
/// only'" - this disclaimer is not optional, so it's baked into the widget
/// rather than left to whoever calls it.
class GstEstimateCard extends StatelessWidget {
  final int estimatedGstPayablePaise;
  final int unpaidInvoicesTotalPaise;
  final int unpaidInvoicesCount;

  const GstEstimateCard({
    super.key,
    required this.estimatedGstPayablePaise,
    required this.unpaidInvoicesTotalPaise,
    required this.unpaidInvoicesCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Estimated GST Payable',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(Money.format(estimatedGstPayablePaise),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text(
                    'Estimate only — verify with your GST practitioner before filing.',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Unpaid Bills',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(Money.format(unpaidInvoicesTotalPaise),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('$unpaidInvoicesCount bill(s)',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

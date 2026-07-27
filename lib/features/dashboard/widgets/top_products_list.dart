import 'package:flutter/material.dart';
import '../models/dashboard_data.dart';

/// Mirrors TopContactsList's layout, keyed on quantity sold instead of an
/// amount - used for the Fast Moving / Slow Moving Products lists.
class TopProductsList extends StatelessWidget {
  final String title;
  final List<ProductQty> products;

  const TopProductsList({super.key, required this.title, required this.products});

  String _formatQty(double qty) =>
      qty == qty.roundToDouble() ? qty.toStringAsFixed(0) : qty.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        if (products.isEmpty)
          const Text('No data yet.', style: TextStyle(color: Colors.grey, fontSize: 12))
        else
          ...products.map((p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(p.name,
                          style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                    ),
                    Text('${_formatQty(p.qty)} sold',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
      ],
    );
  }
}

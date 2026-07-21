import 'package:flutter/material.dart';
import '../../../core/utils/money.dart';
import '../models/dashboard_data.dart';

class TopContactsList extends StatelessWidget {
  final String title;
  final List<ContactTotal> contacts;

  const TopContactsList({super.key, required this.title, required this.contacts});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 6),
        if (contacts.isEmpty)
          const Text('No data yet.', style: TextStyle(color: Colors.grey, fontSize: 12))
        else
          ...contacts.map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(c.name,
                          style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                    ),
                    Text(Money.format(c.amountPaise),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
      ],
    );
  }
}

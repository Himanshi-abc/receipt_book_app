import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/design/app_breakpoints.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../l10n/app_localizations.dart';
import '../models/dashboard_data.dart';

const _sliceColors = [
  Colors.teal,
  Colors.orange,
  Colors.indigo,
  Colors.pink,
  Colors.brown,
  Colors.blueGrey,
];

class ExpenseCategoryBreakdown extends StatelessWidget {
  final List<CategorySlice> slices; // already sorted desc by the service

  const ExpenseCategoryBreakdown({super.key, required this.slices});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (slices.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(l10n.noExpensesInPeriod),
      );
    }

    final top5 = slices.take(5).toList();
    final total = slices.fold<int>(0, (a, b) => a + b.amountPaise);

    final pie = SizedBox(
      height: 140,
      width: 140,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 32,
          sections: [
            for (int i = 0; i < top5.length; i++)
              PieChartSectionData(
                value: top5[i].amountPaise.toDouble(),
                color: _sliceColors[i % _sliceColors.length],
                title: '',
                radius: 28,
              ),
          ],
        ),
      ),
    );

    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < top5.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _sliceColors[i % _sliceColors.length],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(top5[i].categoryName,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
                Text(
                  Money.format(top5[i].amountPaise),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        if (total > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(l10n.totalWithAmount(Money.format(total)),
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ),
      ],
    );

    // On a phone the 140dp pie + a squeezed legend leaves category names
    // truncated, so the pie sits centered above a full-width legend instead.
    if (context.isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: pie),
          const SizedBox(height: AppSpacing.lg),
          legend,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        pie,
        const SizedBox(width: 16),
        Expanded(child: legend),
      ],
    );
  }
}

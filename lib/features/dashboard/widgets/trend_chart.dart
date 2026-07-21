import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/utils/money.dart';
import '../models/dashboard_data.dart';

class TrendChart extends StatelessWidget {
  final List<TrendPoint> points;

  const TrendChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('No transactions in this period yet.')),
      );
    }

    final maxVal = points
        .map((p) => p.incomePaise > p.expensePaise ? p.incomePaise : p.expensePaise)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final maxY = maxVal == 0 ? 100.0 : (maxVal / 100) * 1.2;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final isIncome = rodIndex == 0;
                return BarTooltipItem(
                  '${isIncome ? "Income" : "Expense"}\n${Money.format(rod.toY.round() * 100)}',
                  const TextStyle(color: Colors.white, fontSize: 11),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= points.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(points[i].label, style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barGroups: [
            for (int i = 0; i < points.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: points[i].incomePaise / 100,
                    color: Colors.green,
                    width: 7,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  BarChartRodData(
                    toY: points[i].expensePaise / 100,
                    color: Colors.red,
                    width: 7,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

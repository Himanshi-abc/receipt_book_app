import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../l10n/app_localizations.dart';
import '../models/dashboard_data.dart';

/// Income vs Expense, grouped by period. Two series only, so per the app's
/// chart conventions: theme-tied color (the same positive/negative tones
/// every stat card and tile already uses, not ad-hoc green/red), a legend
/// since two series always need one, recessive gridlines, and axis labels
/// in compact Indian notation (₹1.2L) instead of bare numbers - the things
/// a plain default fl_chart bar chart doesn't give you for free, which is
/// what made this "look weird" next to the rest of the dashboard.
///
/// A daily range can produce ~30 buckets, which at phone width leaves each
/// group ~9dp - less than the 16dp its own two bars occupy, so they collide
/// and the date labels overlap into mush. Below [_minGroupWidth] per group
/// the plot therefore scrolls horizontally at its natural size instead of
/// being crushed to fit; when everything fits, it lays out exactly as
/// before with no scroll view in the tree.
class TrendChart extends StatelessWidget {
  final List<TrendPoint> points;

  const TrendChart({super.key, required this.points});

  /// Room for one group's two 8dp bars plus breathing space, and for its
  /// date label ("12/8") to sit under it without touching its neighbour.
  static const double _minGroupWidth = 38;

  /// Kept in sync with `leftTitles.reservedSize` - the axis gutter isn't
  /// available to the plot, so it has to come off the measured width.
  static const double _axisGutter = 48;

  static const double _chartHeight = 220;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (points.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(child: Text(l10n.noTransactionsInPeriod)),
      );
    }

    final theme = Theme.of(context);
    final tones = context.tones;
    final incomeColor = tones.positive.fg;
    final expenseColor = tones.negative.fg;
    final gridColor = tones.border;
    final axisTextStyle = theme.textTheme.labelSmall?.copyWith(color: tones.textTertiary);

    final maxVal = points
        .map((p) => p.incomePaise > p.expensePaise ? p.incomePaise : p.expensePaise)
        .fold<int>(0, (a, b) => a > b ? a : b);
    // Rounded to a "nice" step (1/2/5/10 x a power of ten) rather than an
    // arbitrary *1.2 fudge, so the gridlines land on clean values like
    // ₹20K/₹40K/₹60K instead of ₹17,340.
    final step = _niceStep(maxVal / 100);
    final maxY = step * 4;

    // Built once and handed to whichever branch below wins, so the fitted
    // and scrolling layouts can never drift into two different charts.
    final barChart = BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => theme.colorScheme.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final isIncome = rodIndex == 0;
              return BarTooltipItem(
                '${points[groupIndex].label}\n',
                TextStyle(
                  color: theme.colorScheme.onInverseSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  TextSpan(
                    text: '${isIncome ? l10n.typeIncome : l10n.typeExpense}: '
                        '${Money.format((rod.toY * 100).round())}',
                    style: TextStyle(
                      color: theme.colorScheme.onInverseSurface,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              interval: step,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text(
                  Money.compact((value * 100).round()),
                  style: axisTextStyle,
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(points[i].label, style: axisTextStyle),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: step,
          getDrawingHorizontalLine: (_) => FlLine(color: gridColor, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (int i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 3,
              barRods: [
                BarChartRodData(
                  toY: points[i].incomePaise / 100,
                  color: incomeColor,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                ),
                BarChartRodData(
                  toY: points[i].expensePaise / 100,
                  color: expenseColor,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                ),
              ],
            ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _LegendEntry(color: incomeColor, label: l10n.typeIncome),
            const SizedBox(width: AppSpacing.lg),
            _LegendEntry(color: expenseColor, label: l10n.typeExpense),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final needed = points.length * _minGroupWidth + _axisGutter;
            final available = constraints.maxWidth;
            // Only scroll when the plot genuinely doesn't fit: a 6-bucket
            // monthly range on a phone still gets the full width it has.
            if (!available.isFinite || needed <= available) {
              return SizedBox(height: _chartHeight, child: barChart);
            }

            return SizedBox(
              height: _chartHeight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: needed, child: barChart),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Rounds [raw] up to the nearest "nice" 1/2/5x10^n step so 4 gridlines
  /// land on round numbers (₹20K, ₹40K, ₹60K, ₹80K) instead of whatever
  /// the data's actual max happens to be.
  static double _niceStep(double raw) {
    if (raw <= 0) return 25;
    final target = raw / 4;
    final magnitude = math.pow(10, (math.log(target) / math.ln10).floor()).toDouble();
    final residual = target / magnitude;
    final niceResidual = residual <= 1
        ? 1
        : residual <= 2
            ? 2
            : residual <= 5
                ? 5
                : 10;
    return niceResidual * magnitude;
  }
}

class _LegendEntry extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendEntry({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

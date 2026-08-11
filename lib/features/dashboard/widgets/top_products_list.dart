import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final tones = context.tones;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        if (products.isEmpty)
          Text(
            l10n.noDataYet,
            style: theme.textTheme.bodySmall?.copyWith(color: tones.textTertiary),
          )
        else
          ...products.map((p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.name,
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      l10n.qtySold(_formatQty(p.qty)),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )),
      ],
    );
  }
}

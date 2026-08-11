import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../models/dashboard_data.dart';

/// One "who is driving the business" panel - Top Customers or Top Vendors.
///
/// The parent decides whether two of these sit side by side or stack (see
/// `_twoUp` in business_dashboard_screen.dart), so this only has to be a
/// good citizen at whatever width it's handed: the name takes the slack and
/// ellipsizes, and the amount keeps its full width so it never truncates.
class TopContactsList extends StatelessWidget {
  final String title;
  final List<ContactTotal> contacts;

  const TopContactsList({super.key, required this.title, required this.contacts});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = context.tones;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        if (contacts.isEmpty)
          Text(
            AppLocalizations.of(context).noDataYet,
            style: theme.textTheme.bodySmall?.copyWith(color: tones.textTertiary),
          )
        else
          ...contacts.map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.name,
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      Money.format(c.amountPaise),
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

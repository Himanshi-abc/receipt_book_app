import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/widgets/money_text.dart';

/// A single income/expense row.
///
/// This is the most-repeated element in the product, so it earns the most
/// scrutiny. Three deliberate changes from the previous `ListTile`:
///
/// 1. **Sign, not just colour.** Amounts now read "+₹500" / "−₹500".
///    Colour alone fails for the ~8% of men with colour-vision deficiency
///    and is invisible in a printed/screenshotted list - WCAG 1.4.1 says
///    colour must never be the sole carrier of meaning.
/// 2. **Attachment as an icon, not an emoji.** The 📎 emoji rendered at a
///    different baseline and size on every platform.
/// 3. **Tabular amounts,** so the column of figures aligns down the list
///    instead of wobbling with each digit width.
class TransactionTile extends StatelessWidget {
  final AppTransaction transaction;
  final VoidCallback onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = context.tones;
    final isIncome = transaction.type == TxType.income;
    final tone = isIncome ? AppTone.positive : AppTone.negative;
    final toneColors = tones.byTone(tone);

    final name = transaction.vendorOrCustomerName.trim();
    final hasAttachment = transaction.receiptImages.isNotEmpty;

    return Material(
      color: tones.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: tones.border),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: toneColors.bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: toneColors.border),
                ),
                child: Icon(
                  isIncome ? Icons.south_west : Icons.north_east,
                  size: 18,
                  color: toneColors.fg,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name.isEmpty ? 'No name' : name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        // An unnamed entry is a data gap, not a real name -
                        // de-emphasise rather than shouting "(No name)".
                        color: name.isEmpty ? tones.textTertiary : null,
                        fontStyle: name.isEmpty ? FontStyle.italic : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      children: [
                        Text(
                          DateFormat('dd MMM yyyy').format(transaction.date),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: tones.textTertiary),
                        ),
                        if (hasAttachment) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Icon(
                            Icons.attach_file,
                            size: 13,
                            color: tones.textTertiary,
                            semanticLabel: 'Has attachment',
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Prefix carries the direction independently of colour.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isIncome ? '+' : '−',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: toneColors.fg, fontWeight: FontWeight.w700),
                      ),
                      MoneyText(
                        transaction.amountPaise,
                        tone: tone,
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                  if (transaction.pendingSync) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_upload_outlined,
                            size: 12, color: tones.textTertiary),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Syncing',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: tones.textTertiary),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

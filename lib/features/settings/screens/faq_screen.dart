import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_search_field.dart';
import '../models/support_content.dart';

/// The FAQ list: questions grouped by category, each expanding in place.
///
/// Search matters more than it looks like it should - someone arriving here
/// has a specific problem and a category they will not think to guess ("why
/// is my invoice showing CGST" is not filed under "Bills & invoices" in
/// their head). Matching on the answer text as well as the question means
/// a search for "IGST" finds the entry that never says it in its title.
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<FaqItem> get _filtered {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return kFaqs;
    return kFaqs
        .where((f) =>
            f.question.toLowerCase().contains(query) ||
            f.answer.toLowerCase().contains(query) ||
            f.category.toLowerCase().contains(query))
        .toList();
  }

  /// Categories in the order they first appear in [kFaqs].
  List<String> _categoriesOf(List<FaqItem> items) {
    final seen = <String>[];
    for (final item in items) {
      if (!seen.contains(item.category)) seen.add(item.category);
    }
    return seen;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = context.tones;
    final items = _filtered;
    final categories = _categoriesOf(items);
    final searching = _searchCtrl.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).faqs)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageGutter,
                  AppSpacing.md,
                  AppSpacing.pageGutter,
                  AppSpacing.sm,
                ),
                child: AppSearchField(
                  controller: _searchCtrl,
                  hintText: AppLocalizations.of(context).searchHelpTopics,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? AppEmptyState(
                        icon: Icons.search_off,
                        title: AppLocalizations.of(context).noAnswersMatched,
                        message:
                            AppLocalizations.of(context).noAnswersMatchedMessage,
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: AppSpacing.giant),
                        children: [
                          for (final category in categories) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.pageGutter,
                                AppSpacing.lg,
                                AppSpacing.pageGutter,
                                AppSpacing.xs,
                              ),
                              child: Text(
                                category.toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: tones.textTertiary,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            for (final faq
                                in items.where((f) => f.category == category))
                              _FaqTile(
                                item: faq,
                                // While searching there are few results and
                                // the user wants to read, not keep tapping.
                                initiallyExpanded: searching,
                              ),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final FaqItem item;
  final bool initiallyExpanded;

  const _FaqTile({required this.item, required this.initiallyExpanded});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = context.tones;

    return Theme(
      // The default ExpansionTile divider fights the section headings.
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        // Rebuilds the tile when a search flips initiallyExpanded, which
        // ExpansionTile otherwise ignores after first build.
        key: PageStorageKey('${item.question}-$initiallyExpanded'),
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.pageGutter,
          0,
          AppSpacing.pageGutter,
          AppSpacing.md,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text(item.question, style: theme.textTheme.titleSmall),
        children: [
          Text(
            item.answer,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: tones.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

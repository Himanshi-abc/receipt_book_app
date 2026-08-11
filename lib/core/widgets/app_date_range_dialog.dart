import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';

/// A compact "From / To" date-range dialog.
///
/// Replaces `showDateRangePicker` for the section filters. Flutter's range
/// picker takes over the whole screen with a scrolling multi-month calendar
/// and asks the user to understand a two-tap selection model - far more
/// machinery than "pick a start and an end", and jarring when it's launched
/// from a small dropdown. This stays a dialog: two fields, each opening the
/// ordinary single-date calendar people already know.
///
/// Returns the chosen range, or null if dismissed.
class AppDateRangeDialog extends StatefulWidget {
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final DateTime firstDate;
  final DateTime lastDate;

  /// Null means "use the default title for the active locale". It can't be
  /// defaulted in the constructor because the default has to be looked up
  /// against a BuildContext, which const initialisers can't do.
  final String? title;

  const AppDateRangeDialog({
    super.key,
    this.initialStart,
    this.initialEnd,
    required this.firstDate,
    required this.lastDate,
    this.title,
  });

  static Future<DateTimeRange?> show(
    BuildContext context, {
    DateTime? initialStart,
    DateTime? initialEnd,
    required DateTime firstDate,
    required DateTime lastDate,
    String? title,
  }) {
    return showDialog<DateTimeRange>(
      context: context,
      builder: (_) => AppDateRangeDialog(
        initialStart: initialStart,
        initialEnd: initialEnd,
        firstDate: firstDate,
        lastDate: lastDate,
        title: title,
      ),
    );
  }

  @override
  State<AppDateRangeDialog> createState() => _AppDateRangeDialogState();
}

class _AppDateRangeDialogState extends State<AppDateRangeDialog> {
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    // Clamped: a caller's stored range can predate firstDate (e.g. an
    // "All Time" range starting in 2000), and handing showDatePicker an
    // out-of-bounds initialDate throws.
    _from = _clamp(widget.initialStart ?? _dateOnly(widget.lastDate));
    _to = _clamp(widget.initialEnd ?? _from);
    if (_to.isBefore(_from)) _to = _from;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _clamp(DateTime d) {
    final date = _dateOnly(d);
    if (date.isBefore(_dateOnly(widget.firstDate))) return _dateOnly(widget.firstDate);
    if (date.isAfter(_dateOnly(widget.lastDate))) return _dateOnly(widget.lastDate);
    return date;
  }

  int get _dayCount => _to.difference(_from).inDays + 1;

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      helpText: AppLocalizations.of(context).fromDate,
    );
    if (picked == null) return;
    setState(() {
      _from = _dateOnly(picked);
      // Pushing the start past the end would leave an impossible range on
      // screen; carrying the end along is what the user meant.
      if (_to.isBefore(_from)) _to = _from;
    });
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to.isBefore(_from) ? _from : _to,
      // The end can never precede the start, so don't offer dates that do.
      firstDate: _from,
      lastDate: widget.lastDate,
      helpText: AppLocalizations.of(context).toDate,
    );
    if (picked == null) return;
    setState(() => _to = _dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = context.tones;
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(widget.title ?? l10n.customDateRangeTitle),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.lg,
        AppSpacing.xxl,
        0,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DateBox(label: l10n.rangeFrom, date: _from, onTap: _pickFrom),
          // An arrow between the two boxes says "range" faster than the
          // labels alone do.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Icon(Icons.arrow_downward, size: 16, color: tones.textTertiary),
          ),
          _DateBox(label: l10n.rangeTo, date: _to, onTap: _pickTo),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.daysSelected(_dayCount),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(color: tones.textTertiary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          // Always enabled: the pickers make an invalid range unreachable,
          // so there's no error state to guard against here.
          onPressed: () => Navigator.pop(context, DateTimeRange(start: _from, end: _to)),
          child: Text(l10n.actionApply),
        ),
      ],
    );
  }
}

/// One labelled, tap-to-pick date. Reads as a field rather than a button so
/// the pair looks like a form the user is filling in.
class _DateBox extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateBox({required this.label, required this.date, required this.onTap});

  /// "05 Aug 2026" - unambiguous, unlike 5/8 vs 8/5.
  ///
  /// The month name comes from `intl` for the active locale rather than a
  /// hardcoded English table, so it reads in the app's language. Date
  /// symbols for the locale are registered by GlobalMaterialLocalizations
  /// before this ever builds.
  static String _format(BuildContext context, DateTime d) => DateFormat(
        'dd MMM yyyy',
        Localizations.localeOf(context).toString(),
      ).format(d);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = context.tones;

    return Material(
      color: tones.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: tones.border),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: tones.textTertiary),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      _format(context, date),
                      style: theme.textTheme.titleSmall?.tabular,
                    ),
                  ],
                ),
              ),
              Icon(Icons.calendar_today, size: 18, color: tones.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

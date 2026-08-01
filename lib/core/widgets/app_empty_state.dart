import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_spacing.dart';

/// Empty / locked / error state.
///
/// The app previously rendered these as a bare `Center(child: Text('No
/// transactions yet.'))`. A blank screen with one grey sentence reads as a
/// bug, and - more importantly - it's a dead end: it never tells the user
/// what to do next. Every state here pairs an explanation with the action
/// that resolves it, which is the difference between a dead end and a
/// starting point.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;

  /// One sentence explaining *why* it's empty and what will fill it.
  final String message;

  /// The action that resolves the state. Omit only when there genuinely
  /// isn't one (e.g. "no search matches" - clearing is already adjacent).
  final String? actionLabel;
  final VoidCallback? onAction;

  final AppTone tone;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.tone = AppTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = context.tones;
    final toneColors = tones.byTone(tone);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: ConstrainedBox(
          // Caps the measure so the message never runs into an unreadable
          // full-width line on tablet/desktop.
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: toneColors.bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: toneColors.border),
                ),
                child: Icon(icon, size: 26, color: toneColors.fg),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: tones.textSecondary),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.xl),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

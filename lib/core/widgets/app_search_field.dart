import 'package:flutter/material.dart';

import '../design/app_motion.dart';

/// The one search input.
///
/// Five screens each hand-rolled this with slightly different radii and
/// hints. Beyond consistency, this adds the affordance every one of them
/// was missing: a clear ("×") button that appears once there's a query.
/// Without it the only way to reset a filter was to backspace the field,
/// which is a real friction point on mobile.
class AppSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  const AppSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
  });

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  // Rebuilds only this widget so the clear button can appear/disappear,
  // without forcing the whole screen to rebuild on every keystroke.
  void _onTextChanged() => setState(() {});

  void _clear() {
    widget.controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;

    return TextField(
      controller: widget.controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: AnimatedSwitcher(
          duration: AppMotion.fast,
          switchInCurve: AppMotion.enter,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: hasText
              ? IconButton(
                  key: const ValueKey('clear'),
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Clear search',
                  onPressed: _clear,
                )
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),
      ),
    );
  }
}

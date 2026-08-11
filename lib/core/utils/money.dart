import 'package:intl/intl.dart';

/// SRS Section 8 rule: "store all amounts as integers in paise (smallest
/// unit), never as floating point, to avoid rounding bugs. Convert to ₹
/// only for display."
///
/// Every amount in the data layer (Transaction.amountPaise,
/// InvoiceLineItem.amountPaise, etc.) MUST be an int representing paise.
/// Only this class should ever convert to/from rupees for display or user
/// input parsing.
class Money {
  Money._();

  static final NumberFormat _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  /// Convert paise (int) -> a formatted ₹ string for display, e.g. ₹1,234.50
  static String format(int paise) {
    final rupees = paise / 100;
    return _inr.format(rupees);
  }

  /// Compact Indian-numbering form for tight spaces (chart axes, dense
  /// tiles) - ₹45K, ₹1.2L, ₹3Cr - where [format]'s full ₹1,23,45,600.00
  /// would overflow or crowd out the rest of the layout.
  static String compact(int paise) {
    final rupees = paise / 100;
    final abs = rupees.abs();
    final sign = rupees < 0 ? '-' : '';
    if (abs >= 10000000) return '$sign₹${_trimmed(abs / 10000000)}Cr';
    if (abs >= 100000) return '$sign₹${_trimmed(abs / 100000)}L';
    if (abs >= 1000) return '$sign₹${_trimmed(abs / 1000)}K';
    return '$sign₹${abs.toStringAsFixed(0)}';
  }

  /// One decimal place, dropped when it's a whole number - "1.2" but "2",
  /// not "2.0".
  static String _trimmed(double value) {
    final rounded = (value * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1);
  }

  /// Convert a user-typed rupee string (e.g. "1234.5" from a text field)
  /// into paise (int). Never parse user input directly as double and store
  /// it - always go through this so rounding happens in exactly one place.
  static int rupeesStringToPaise(String input) {
    final cleaned = input.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return 0;
    final value = double.tryParse(cleaned) ?? 0;
    return (value * 100).round();
  }

  /// paise -> plain rupee double, only for feeding a form field's initial
  /// value. Do not store the result of this anywhere - re-derive from
  /// paise every time.
  static double paiseToRupees(int paise) => paise / 100;

  static String paiseToEditableString(int paise) {
    final rupees = paise / 100;
    // Avoid trailing .00 clutter in edit fields but keep real decimals.
    if (rupees == rupees.roundToDouble()) {
      return rupees.toStringAsFixed(0);
    }
    return rupees.toStringAsFixed(2);
  }
}

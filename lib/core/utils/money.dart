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

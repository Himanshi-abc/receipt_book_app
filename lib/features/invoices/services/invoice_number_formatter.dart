/// SRS 4.5: format configurable per Business Book, e.g. "INV-{YYYY}-{0000}"
/// -> "INV-2026-0007". `{YYYY}` is replaced with the invoice's financial
/// year's starting calendar year; any run of `0`s (e.g. `{0000}`) is
/// replaced with the running number, zero-padded to that same width.
class InvoiceNumberFormatter {
  InvoiceNumberFormatter._();

  static String format({
    required String template,
    required int number,
    required int financialYearStart,
  }) {
    var result = template.replaceAll('{YYYY}', financialYearStart.toString());

    final placeholder = RegExp(r'\{0+\}');
    final match = placeholder.firstMatch(result);
    if (match == null) {
      // No numeric placeholder in the template - just append the number.
      return '$result-$number';
    }
    final width = match.group(0)!.length - 2; // minus the braces
    final padded = number.toString().padLeft(width, '0');
    return result.replaceRange(match.start, match.end, padded);
  }
}

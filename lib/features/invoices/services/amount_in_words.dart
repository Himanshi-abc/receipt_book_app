/// SRS 4.5: invoice PDF must show "total in words". India uses the
/// lakh/crore grouping (not thousand/million), so this is a small
/// standalone converter rather than reaching for a generic English
/// number-to-words package that would get the grouping wrong.
class AmountInWords {
  AmountInWords._();

  static const _ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen',
  ];
  static const _tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety',
  ];

  static String _twoDigits(int n) {
    if (n < 20) return _ones[n];
    return '${_tens[n ~/ 10]}${n % 10 != 0 ? ' ${_ones[n % 10]}' : ''}'.trim();
  }

  static String _threeDigits(int n) {
    if (n < 100) return _twoDigits(n);
    final hundred = n ~/ 100;
    final rest = n % 100;
    return '${_ones[hundred]} Hundred${rest != 0 ? ' ${_twoDigits(rest)}' : ''}';
  }

  /// [rupees] must be a non-negative whole number of rupees.
  static String rupeesToWords(int rupees) {
    if (rupees == 0) return 'Zero Rupees Only';

    final crore = rupees ~/ 10000000;
    final lakh = (rupees ~/ 100000) % 100;
    final thousand = (rupees ~/ 1000) % 100;
    final hundred = rupees % 1000;

    final parts = <String>[];
    if (crore > 0) parts.add('${_threeDigits(crore)} Crore');
    if (lakh > 0) parts.add('${_twoDigits(lakh)} Lakh');
    if (thousand > 0) parts.add('${_twoDigits(thousand)} Thousand');
    if (hundred > 0) parts.add(_threeDigits(hundred));

    return '${parts.join(' ')} Rupees Only';
  }

  /// Convenience for a paise amount straight from the data layer.
  static String paiseToWords(int paise) => rupeesToWords((paise / 100).round());
}

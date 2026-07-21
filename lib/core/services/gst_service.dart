/// SRS Section 8:
/// - Same state (business state == customer state) -> CGST + SGST, split
///   50/50 of the total rate.
/// - Different state -> IGST at full rate.
/// Tax rate itself must come from a config list (TaxRuleConfig), never
/// hardcoded, since GST rates change over time (Union Budget / GST Council).
class GstBreakup {
  final int cgstPaise;
  final int sgstPaise;
  final int igstPaise;
  final int totalTaxPaise;

  GstBreakup({
    required this.cgstPaise,
    required this.sgstPaise,
    required this.igstPaise,
  }) : totalTaxPaise = cgstPaise + sgstPaise + igstPaise;

  bool get isInterState => igstPaise > 0;
}

class GstService {
  GstService._();

  /// [taxableAmountPaise] is the line/invoice amount before tax.
  /// [ratePercent] comes from TaxRuleConfig for the relevant financial year
  /// (e.g. 18 for 18%), never hardcoded at the call site.
  static GstBreakup computeBreakup({
    required int taxableAmountPaise,
    required double ratePercent,
    required String businessState,
    required String customerState,
  }) {
    final totalTax = (taxableAmountPaise * ratePercent / 100).round();
    final sameState = businessState.trim().toLowerCase() ==
        customerState.trim().toLowerCase();

    if (sameState) {
      final half = (totalTax / 2).round();
      // Ensure cgst+sgst reconciles exactly to totalTax even with rounding.
      final sgst = totalTax - half;
      return GstBreakup(cgstPaise: half, sgstPaise: sgst, igstPaise: 0);
    } else {
      return GstBreakup(cgstPaise: 0, sgstPaise: 0, igstPaise: totalTax);
    }
  }
}

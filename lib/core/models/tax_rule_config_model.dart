/// SRS Section 7 (TaxRuleConfig) + Section 8:
/// "Tax rates/GST slabs must live in a config table, not hardcoded in app
/// code - GST rates and rules change (Union Budget, GST Council meetings),
/// and a config change shouldn't need an app store release."
///
/// In production this is read from Firestore (`taxRuleConfig` collection)
/// so it can be updated remotely. `TaxRuleConfigRepository` falls back to
/// [defaultRates] only if that collection is empty (e.g. first run before
/// anyone has seeded it), so the app never hard-fails on a missing config.
class TaxRuleConfig {
  final String id;
  final String financialYear; // e.g. "2026-27"
  final List<double> gstRates; // e.g. [0, 5, 12, 18, 28]
  final DateTime effectiveFrom;

  TaxRuleConfig({
    required this.id,
    required this.financialYear,
    required this.gstRates,
    required this.effectiveFrom,
  });

  factory TaxRuleConfig.fromMap(String id, Map<String, dynamic> map) => TaxRuleConfig(
        id: id,
        financialYear: map['financialYear'] as String? ?? '',
        gstRates: ((map['gstRates'] as List?) ?? [])
            .map((e) => (e as num).toDouble())
            .toList(),
        effectiveFrom: DateTime.tryParse(map['effectiveFrom']?.toString() ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'financialYear': financialYear,
        'gstRates': gstRates,
        'effectiveFrom': effectiveFrom.toIso8601String(),
      };

  /// Used only if Firestore has no config doc yet - keeps the app usable
  /// on a fresh install, never a substitute for the real remote config.
  static List<double> defaultRates() => const [0, 0.25, 3, 5, 12, 18, 28];
}

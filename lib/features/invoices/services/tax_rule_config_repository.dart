import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/tax_rule_config_model.dart';
import '../../../core/models/transaction_model.dart';

/// SRS Section 8: GST rates must come from a config table, never hardcoded,
/// since GST Council/Union Budget changes shouldn't need an app release.
/// Firestore doc path: taxRuleConfig/{financialYear}
class TaxRuleConfigRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<double>> ratesForDate(DateTime date) async {
    final fy = financialYearFor(date);
    try {
      final snap = await _db.collection('taxRuleConfig').doc(fy).get();
      if (snap.exists) {
        final config = TaxRuleConfig.fromMap(fy, snap.data()!);
        if (config.gstRates.isNotEmpty) return config.gstRates;
      }
    } catch (_) {
      // Fall through to defaults - a config-fetch failure must never block
      // invoice creation.
    }
    return TaxRuleConfig.defaultRates();
  }

  /// Seeds a default config doc for a financial year if none exists yet.
  /// Call this once from an admin tool / Cloud Function in production;
  /// exposed here so the app can self-seed on first run in dev.
  Future<void> seedDefaultIfMissing(String financialYear) async {
    final ref = _db.collection('taxRuleConfig').doc(financialYear);
    final snap = await ref.get();
    if (snap.exists) return;
    final config = TaxRuleConfig(
      id: financialYear,
      financialYear: financialYear,
      gstRates: TaxRuleConfig.defaultRates(),
      effectiveFrom: DateTime.now(),
    );
    await ref.set(config.toMap());
  }
}

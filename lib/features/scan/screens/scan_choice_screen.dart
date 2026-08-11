import 'package:flutter/material.dart';
import '../../../core/models/transaction_model.dart';
import '../../../l10n/app_localizations.dart';
import 'camera_capture_screen.dart';

class ScanChoiceScreen extends StatelessWidget {
  const ScanChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).newTransaction)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ChoiceCard(
              label: AppLocalizations.of(context).typeIncome,
              icon: Icons.arrow_downward,
              color: Colors.green,
              onTap: () => _goToCamera(context, TxType.income),
            ),
            const SizedBox(height: 16),
            _ChoiceCard(
              label: AppLocalizations.of(context).typeExpense,
              icon: Icons.arrow_upward,
              color: Colors.red,
              onTap: () => _goToCamera(context, TxType.expense),
            ),
          ],
        ),
      ),
    );
  }

  void _goToCamera(BuildContext context, TxType type) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CameraCaptureScreen(type: type)),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ChoiceCard(
      {required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

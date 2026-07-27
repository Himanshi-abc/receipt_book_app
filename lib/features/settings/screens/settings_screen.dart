import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../books/providers/book_provider.dart';
import '../../../core/models/subscription_model.dart';

/// Covers "Manage Books" (plan/trial state + switch active book), since
/// that's the piece the SRS calls out as safety-critical, plus the
/// Business Book-only Business Profile / Invoice Template screens.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isBusiness = context.watch<BookProvider>().currentBook?.isBusiness == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          if (isBusiness)
            ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('Business Profile'),
              subtitle: const Text('Company details shown on your invoices'),
              onTap: () => Navigator.pushNamed(context, '/settings/business-profile'),
            ),
          if (isBusiness)
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Invoice Template'),
              subtitle: const Text('Choose how your invoices look'),
              onTap: () => Navigator.pushNamed(context, '/settings/invoice-template'),
            ),
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: const Text('Manage Books'),
            subtitle: const Text('Plan, trial status, active Business Book'),
            onTap: () => Navigator.pushNamed(context, '/settings/manage-books'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log out', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await context.read<AuthProvider>().signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
              }
            },
          ),
        ],
      ),
    );
  }
}

class ManageBooksScreen extends StatelessWidget {
  const ManageBooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();
    final sub = bookProvider.subscription;
    final userId = context.read<AuthProvider>().user!.uid;
    final businessBooks = bookProvider.books.where((b) => b.isBusiness).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Books')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Plan: ${_planLabel(sub)}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (sub != null && sub.isOnActiveTrial)
                    Text('${sub.trialDaysLeft} days left in trial'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Business Books', style: TextStyle(fontWeight: FontWeight.bold)),
          ...businessBooks.map((b) {
            final isActive = sub?.activeBusinessBookId == b.id;
            return ListTile(
              title: Text(b.name),
              subtitle: Text(sub?.planType == PlanType.singleBook
                  ? (isActive ? 'Active' : 'Locked')
                  : 'Active'),
              trailing: (sub?.planType == PlanType.singleBook && !isActive)
                  ? TextButton(
                      onPressed: () => bookProvider.setActiveBusinessBook(userId, b.id),
                      child: const Text('Make Active'),
                    )
                  : null,
            );
          }),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _showUpgradeSheet(context, bookProvider, userId),
            child: const Text('Upgrade / Change Plan'),
          ),
        ],
      ),
    );
  }

  String _planLabel(sub) {
    if (sub == null) return 'None';
    switch (sub.planType) {
      case PlanType.trial:
        return 'Free Trial';
      case PlanType.singleBook:
        return 'Single Book Plan';
      case PlanType.multiBook:
        return 'Multi-Book Plan';
      case PlanType.none:
        return 'No plan';
    }
    return 'No plan';
  }

  void _showUpgradeSheet(BuildContext context, BookProvider bookProvider, String userId) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Single Book Plan (monthly)'),
              onTap: () {
                bookProvider.choosePlan(
                    userId: userId,
                    planType: PlanType.singleBook,
                    billingCycle: BillingCycle.monthly);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('Multi-Book Plan (monthly)'),
              onTap: () {
                bookProvider.choosePlan(
                    userId: userId,
                    planType: PlanType.multiBook,
                    billingCycle: BillingCycle.monthly);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}

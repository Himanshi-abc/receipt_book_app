import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../books/providers/book_provider.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/models/subscription_model.dart';
import '../models/support_content.dart';
import '../services/support_launcher.dart';
import '../widgets/settings_nav_tile.dart';
import 'faq_screen.dart';
import 'legal_document_screen.dart';

/// Covers "Manage Books" (plan/trial state + switch active book), since
/// that's the piece the SRS calls out as safety-critical, plus the
/// Business Book-only Business Profile / Invoice Template screens, and the
/// Help & Support / About Us sections.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _openDocument(BuildContext context, LegalDocument document) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LegalDocumentScreen(document: document)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = context.tones;
    final isBusiness = context.watch<BookProvider>().currentBook?.isBusiness == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              const _SectionHeading('Your books'),
              if (isBusiness)
                SettingsNavTile(
                  icon: SettingsNavTile.material(Icons.storefront_outlined),
                  tone: AppTone.brand,
                  title: 'Business Profile',
                  subtitle: 'Company details shown on your invoices',
                  onTap: () =>
                      Navigator.pushNamed(context, '/settings/business-profile'),
                ),
              if (isBusiness)
                SettingsNavTile(
                  icon: SettingsNavTile.material(Icons.palette_outlined),
                  tone: AppTone.info,
                  title: 'Invoice Template',
                  subtitle: 'Choose how your invoices look',
                  onTap: () =>
                      Navigator.pushNamed(context, '/settings/invoice-template'),
                ),
              SettingsNavTile(
                icon: SettingsNavTile.material(Icons.menu_book),
                tone: AppTone.neutral,
                title: 'Manage Books',
                subtitle: 'Plan, trial status, active Business Book',
                onTap: () => Navigator.pushNamed(context, '/settings/manage-books'),
              ),

              // Both sections below are shown for Individual and Business
              // books alike: support and the legal documents are about the
              // app, not about which book happens to be open.
              const Divider(height: AppSpacing.xxl),
              const _SectionHeading('Help & Support'),
              SettingsNavTile(
                icon: SettingsNavTile.material(Icons.help_outline),
                tone: AppTone.info,
                title: 'FAQs',
                subtitle: 'Answers to the questions we get most',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FaqScreen()),
                ),
              ),
              SettingsNavTile(
                icon: (color) =>
                    FaIcon(FontAwesomeIcons.whatsapp, size: 18, color: color),
                tone: AppTone.positive,
                title: 'Help on WhatsApp',
                subtitle: 'Chat with our support team',
                onTap: () => SupportLauncher.whatsApp(context),
              ),
              SettingsNavTile(
                icon: SettingsNavTile.material(Icons.call_outlined),
                tone: AppTone.brand,
                title: 'Call Us',
                subtitle: '${SupportContacts.phoneNumber} · '
                    '${SupportContacts.supportHours}',
                onTap: () => SupportLauncher.call(context),
              ),

              const Divider(height: AppSpacing.xxl),
              const _SectionHeading('About Us'),
              SettingsNavTile(
                icon: SettingsNavTile.material(Icons.info_outline),
                tone: AppTone.brand,
                title: 'About ReceiptBook',
                subtitle: 'What the app does and who it is for',
                onTap: () => _openDocument(context, kAboutReceiptBook),
              ),
              SettingsNavTile(
                icon: SettingsNavTile.material(Icons.privacy_tip_outlined),
                tone: AppTone.info,
                title: 'Privacy Policy',
                subtitle: 'What we collect, and what we do with it',
                onTap: () => _openDocument(context, kPrivacyPolicy),
              ),
              SettingsNavTile(
                icon: SettingsNavTile.material(Icons.gavel_outlined),
                tone: AppTone.neutral,
                title: 'Terms and Conditions',
                subtitle: 'The agreement for using ReceiptBook',
                onTap: () => _openDocument(context, kTermsAndConditions),
              ),

              const Divider(height: AppSpacing.xxl),
              SettingsNavTile(
                icon: SettingsNavTile.material(Icons.logout),
                tone: AppTone.negative,
                title: 'Log out',
                subtitle: 'Sign out of this device',
                onTap: () async {
                  await context.read<AuthProvider>().signOut();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'ReceiptBook v${SupportContacts.appVersion}',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(color: tones.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small all-caps group label. Settings is now long enough that ungrouped
/// rows would read as one undifferentiated list.
class _SectionHeading extends StatelessWidget {
  final String label;
  const _SectionHeading(this.label);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = context.tones;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        AppSpacing.lg,
        AppSpacing.pageGutter,
        AppSpacing.xs,
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: tones.textTertiary,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
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

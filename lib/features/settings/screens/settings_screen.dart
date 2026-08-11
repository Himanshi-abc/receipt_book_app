import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../books/providers/book_provider.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/models/subscription_model.dart';
import '../../../core/services/locale_provider.dart';
import '../../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    final isBusiness = context.watch<BookProvider>().currentBook?.isBusiness == true;
    // Falls back to whatever the device language resolved to, so this row
    // always names the language actually on screen.
    final currentLanguage = context.watch<LocaleProvider>().selectedLanguage ??
        kSupportedLanguages.firstWhere(
          (l) => l.code == Localizations.localeOf(context).languageCode,
          orElse: () => kSupportedLanguages.first,
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
            children: [
              _SectionHeading(l10n.sectionYourBooks),
              if (isBusiness)
                SettingsNavTile(
                  icon: SettingsNavTile.material(Icons.storefront_outlined),
                  tone: AppTone.brand,
                  title: l10n.businessProfile,
                  subtitle: l10n.businessProfileSubtitle,
                  onTap: () =>
                      Navigator.pushNamed(context, '/settings/business-profile'),
                ),
              if (isBusiness)
                SettingsNavTile(
                  icon: SettingsNavTile.material(Icons.palette_outlined),
                  tone: AppTone.info,
                  title: l10n.invoiceTemplate,
                  subtitle: l10n.invoiceTemplateSubtitle,
                  onTap: () =>
                      Navigator.pushNamed(context, '/settings/invoice-template'),
                ),
              SettingsNavTile(
                icon: SettingsNavTile.material(Icons.menu_book),
                tone: AppTone.neutral,
                title: l10n.manageBooks,
                subtitle: l10n.manageBooksSubtitle,
                onTap: () => Navigator.pushNamed(context, '/settings/manage-books'),
              ),

              // Language sits in its own group directly under the books
              // section: it applies to the whole app rather than to the
              // open book, and it's the row people go hunting for.
              const Divider(height: AppSpacing.xxl),
              _SectionHeading(l10n.sectionAppSettings),
              SettingsNavTile(
                icon: SettingsNavTile.material(Icons.language),
                tone: AppTone.brand,
                title: l10n.language,
                // Shows the language's own name, so it's recognisable even
                // when the app is currently in a script you can't read.
                subtitle: currentLanguage.endonym,
                onTap: () => Navigator.pushNamed(context, '/settings/language'),
              ),

              // Both sections below are shown for Individual and Business
              // books alike: support and the legal documents are about the
              // app, not about which book happens to be open.
              const Divider(height: AppSpacing.xxl),
              _SectionHeading(l10n.sectionHelpSupport),
              SettingsNavTile(
                icon: SettingsNavTile.material(Icons.help_outline),
                tone: AppTone.info,
                title: l10n.faqs,
                subtitle: l10n.faqsSubtitle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FaqScreen()),
                ),
              ),
              SettingsNavTile(
                icon: (color) =>
                    FaIcon(FontAwesomeIcons.whatsapp, size: 18, color: color),
                tone: AppTone.positive,
                title: l10n.helpOnWhatsApp,
                subtitle: l10n.helpOnWhatsAppSubtitle,
                onTap: () => SupportLauncher.whatsApp(context),
              ),
              SettingsNavTile(
                icon: SettingsNavTile.material(Icons.call_outlined),
                tone: AppTone.brand,
                title: l10n.callUs,
                subtitle: '${SupportContacts.phoneNumber} · '
                    '${l10n.supportHours}',
                onTap: () => SupportLauncher.call(context),
              ),

              const Divider(height: AppSpacing.xxl),
              _SectionHeading(l10n.sectionAboutUs),
              SettingsNavTile(
                icon: SettingsNavTile.material(Icons.info_outline),
                tone: AppTone.brand,
                title: l10n.aboutDhandho,
                subtitle: l10n.aboutDhandhoSubtitle,
                onTap: () => _openDocument(context, kAboutDhandho),
              ),
              SettingsNavTile(
                icon: SettingsNavTile.material(Icons.privacy_tip_outlined),
                tone: AppTone.info,
                title: l10n.privacyPolicy,
                subtitle: l10n.privacyPolicySubtitle,
                onTap: () => _openDocument(context, kPrivacyPolicy),
              ),
              SettingsNavTile(
                icon: SettingsNavTile.material(Icons.gavel_outlined),
                tone: AppTone.neutral,
                title: l10n.termsAndConditions,
                subtitle: l10n.termsAndConditionsSubtitle,
                onTap: () => _openDocument(context, kTermsAndConditions),
              ),

              const Divider(height: AppSpacing.xxl),
              SettingsNavTile(
                icon: SettingsNavTile.material(Icons.logout),
                tone: AppTone.negative,
                title: l10n.logOut,
                subtitle: l10n.logOutSubtitle,
                onTap: () async {
                  await context.read<AuthProvider>().signOut();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.appVersion(SupportContacts.appVersion),
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

    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.manageBooks)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.planWithName(_planLabel(l10n, sub)),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (sub != null &&
                      sub.isOnActiveTrial &&
                      sub.trialDaysLeft != null)
                    Text(l10n.daysLeftInTrial(sub.trialDaysLeft!)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.businessBooks,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          ...businessBooks.map((b) {
            final isActive = sub?.activeBusinessBookId == b.id;
            return ListTile(
              title: Text(b.name),
              subtitle: Text(sub?.planType == PlanType.singleBook
                  ? (isActive ? l10n.bookStatusActive : l10n.statusLocked)
                  : l10n.bookStatusActive),
              trailing: (sub?.planType == PlanType.singleBook && !isActive)
                  ? TextButton(
                      onPressed: () => bookProvider.setActiveBusinessBook(userId, b.id),
                      child: Text(l10n.makeActive),
                    )
                  : null,
            );
          }),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _showUpgradeSheet(context, bookProvider, userId),
            child: Text(l10n.upgradeChangePlan),
          ),
        ],
      ),
    );
  }

  String _planLabel(AppLocalizations l10n, sub) {
    if (sub == null) return l10n.planNone;
    switch (sub.planType) {
      case PlanType.trial:
        return l10n.planFreeTrial;
      case PlanType.singleBook:
        return l10n.planSingleBook;
      case PlanType.multiBook:
        return l10n.planMultiBook;
      case PlanType.none:
        return l10n.planNoPlan;
    }
    return l10n.planNoPlan;
  }

  void _showUpgradeSheet(BuildContext context, BookProvider bookProvider, String userId) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(AppLocalizations.of(ctx).planSingleBookMonthly),
              onTap: () {
                bookProvider.choosePlan(
                    userId: userId,
                    planType: PlanType.singleBook,
                    billingCycle: BillingCycle.monthly);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: Text(AppLocalizations.of(ctx).planMultiBookMonthly),
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

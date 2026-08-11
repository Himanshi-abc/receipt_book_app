import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/design/app_theme.dart';
import 'core/navigation/business_section.dart';
import 'core/services/locale_provider.dart';
import 'l10n/app_localizations.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/books/providers/book_provider.dart';
import 'features/books/screens/first_time_setup_screen.dart';
import 'features/books/screens/add_business_book_screen.dart';
import 'features/books/screens/business_profile_screen.dart';
import 'features/invoices/screens/invoice_template_screen.dart';
import 'features/ledger/screens/home_ledger_screen.dart';
import 'features/ledger/screens/register_screen.dart';
import 'features/settings/screens/language_screen.dart';
import 'features/settings/screens/settings_screen.dart';

class DhandhoApp extends StatelessWidget {
  /// Pre-loaded in main() so the very first frame is already in the saved
  /// language, rather than flashing English and then swapping.
  final LocaleProvider localeProvider;

  const DhandhoApp({super.key, required this.localeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BookProvider()),
        ChangeNotifierProvider.value(value: localeProvider),
      ],
      // Only the MaterialApp rebuilds when the language changes - the
      // provider list above stays intact, so switching language never tears
      // down AuthProvider/BookProvider (which would log the user out and
      // re-fetch every book).
      child: Consumer<LocaleProvider>(
        builder: (context, locales, _) => MaterialApp(
        title: 'Dhandho',
        debugShowCheckedModeBanner: false,
        // Null locale = follow the device language; see LocaleProvider.
        locale: locales.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          // Translate Flutter's own widgets too (date picker, text-selection
          // menu, dialog buttons) - without these they stay English while
          // the rest of the app is not.
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        // Pinned to light for now. The dark token set is complete and the
        // migrated components render correctly in it, but screens that have
        // not yet moved off hardcoded colors (Colors.white / grey.shade100)
        // would render broken. Flip to ThemeMode.system once the remaining
        // screens are migrated - see the handover note.
        themeMode: ThemeMode.light,
        home: const _RootGate(),
        routes: {
          // The Business Book sections all resolve to the shell with that
          // section selected, so a deep link lands somewhere the section
          // bar is present - arriving on a bare screen with only a back
          // arrow is the exact dead end the shell exists to remove.
          '/home': (_) => const HomeLedgerScreen(),
          '/dashboard': (_) =>
              const HomeLedgerScreen(initialSection: BusinessSection.dashboard),
          '/bills': (_) =>
              const HomeLedgerScreen(initialSection: BusinessSection.bills),
          // Customers and Suppliers are now one merged Parties section (see
          // BusinessSection.parties); both route names are kept so any
          // existing deep link still lands inside the shell, just on the
          // Customers-default Parties view rather than a dedicated screen.
          '/customers': (_) =>
              const HomeLedgerScreen(initialSection: BusinessSection.parties),
          '/suppliers': (_) =>
              const HomeLedgerScreen(initialSection: BusinessSection.parties),
          '/products': (_) =>
              const HomeLedgerScreen(initialSection: BusinessSection.products),
          '/register': (_) => const RegisterScreen(),
          '/add-business-book': (_) => const AddBusinessBookScreen(),
          '/settings': (_) => const SettingsScreen(),
          '/settings/language': (_) => const LanguageScreen(),
          '/settings/manage-books': (_) => const ManageBooksScreen(),
          '/settings/business-profile': (_) => const BusinessProfileScreen(),
          '/settings/invoice-template': (_) => const InvoiceTemplateScreen(),
        },
        ),
      ),
    );
  }
}

/// Decides Login vs First-time-setup vs Home based on auth + book state.
/// SRS 4.1: "On first login, app auto-creates the user's Individual Book."
class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  String? _listeningForUserId;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isLoggedIn) {
      _listeningForUserId = null;
      return const LoginScreen();
    }

    final bookProvider = context.watch<BookProvider>();
    if (_listeningForUserId != auth.user!.uid) {
      _listeningForUserId = auth.user!.uid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        bookProvider.listenToUser(auth.user!.uid);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (bookProvider.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (bookProvider.books.isEmpty) {
      return const FirstTimeSetupScreen();
    }

    return const HomeLedgerScreen();
  }
}

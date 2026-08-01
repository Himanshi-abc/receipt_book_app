import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/design/app_theme.dart';
import 'core/navigation/business_section.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/books/providers/book_provider.dart';
import 'features/books/screens/first_time_setup_screen.dart';
import 'features/books/screens/add_business_book_screen.dart';
import 'features/books/screens/business_profile_screen.dart';
import 'features/invoices/screens/invoice_template_screen.dart';
import 'features/ledger/screens/home_ledger_screen.dart';
import 'features/ledger/screens/register_screen.dart';
import 'features/settings/screens/settings_screen.dart';

class ReceiptBookApp extends StatelessWidget {
  const ReceiptBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => BookProvider()),
      ],
      child: MaterialApp(
        title: 'ReceiptBook',
        debugShowCheckedModeBanner: false,
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
          '/customers': (_) =>
              const HomeLedgerScreen(initialSection: BusinessSection.customers),
          '/suppliers': (_) =>
              const HomeLedgerScreen(initialSection: BusinessSection.suppliers),
          '/products': (_) =>
              const HomeLedgerScreen(initialSection: BusinessSection.products),
          '/register': (_) => const RegisterScreen(),
          '/add-business-book': (_) => const AddBusinessBookScreen(),
          '/settings': (_) => const SettingsScreen(),
          '/settings/manage-books': (_) => const ManageBooksScreen(),
          '/settings/business-profile': (_) => const BusinessProfileScreen(),
          '/settings/invoice-template': (_) => const InvoiceTemplateScreen(),
        },
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

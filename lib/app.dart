import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import 'features/dashboard/screens/business_dashboard_screen.dart';
import 'features/bills/screens/bill_list_screen.dart';
import 'features/khata/screens/party_list_screen.dart';
import 'core/models/contact_model.dart';
import 'features/products/screens/product_list_screen.dart';

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
        theme: ThemeData(
          colorSchemeSeed: Colors.teal,
          useMaterial3: true,
        ),
        home: const _RootGate(),
        routes: {
          '/home': (_) => const HomeLedgerScreen(),
          '/register': (_) => const RegisterScreen(),
          '/add-business-book': (_) => const AddBusinessBookScreen(),
          '/settings': (_) => const SettingsScreen(),
          '/settings/manage-books': (_) => const ManageBooksScreen(),
          '/settings/business-profile': (_) => const BusinessProfileScreen(),
          '/settings/invoice-template': (_) => const InvoiceTemplateScreen(),
          '/dashboard': (_) => const BusinessDashboardScreen(),
          '/bills': (_) => const BillListScreen(),
          '/customers': (_) => const PartyListScreen(type: ContactType.customer),
          '/suppliers': (_) => const PartyListScreen(type: ContactType.vendor),
          '/products': (_) => const ProductListScreen(),
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

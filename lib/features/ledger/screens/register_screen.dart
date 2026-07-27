import 'package:flutter/material.dart';
import 'register_section_body.dart';

/// Business Book only: the Income/Expense register, reached via the
/// "Register" icon on HomeLedgerScreen - Bills is the default view there
/// instead. The Individual Book shows RegisterSectionBody directly as
/// HomeLedgerScreen's body, with no separate push needed.
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: const RegisterSectionBody(),
    );
  }
}

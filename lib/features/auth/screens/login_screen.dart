import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _isSignUp = false;
  bool _busy = false;
  String? _error;

  Future<void> _submitEmail() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      if (_isSignUp) {
        await auth.signUpWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
      } else {
        await auth.signInWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
      }
      // Navigation on success is handled by the auth-state listener in app.dart
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitPhone() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      await auth.sendOtp(_phoneCtrl.text.trim());
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OtpScreen()));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ReceiptBook'),
        bottom: TabBar(controller: _tab, tabs: const [
          Tab(text: 'Email'),
          Tab(text: 'Mobile OTP'),
        ]),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                FilledButton(
                  onPressed: _busy ? null : _submitEmail,
                  child: Text(_isSignUp ? 'Sign Up' : 'Log In'),
                ),
                TextButton(
                  onPressed: () => setState(() => _isSignUp = !_isSignUp),
                  child: Text(_isSignUp
                      ? 'Already have an account? Log in'
                      : "New here? Sign up"),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'Mobile number (with country code)',
                      hintText: '+91XXXXXXXXXX'),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                FilledButton(
                  onPressed: _busy ? null : _submitPhone,
                  child: const Text('Send OTP'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

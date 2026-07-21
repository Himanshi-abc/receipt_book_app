import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  User? get user => _user;
  bool get isLoggedIn => _user != null;

  String? _pendingVerificationId;

  AuthProvider() {
    _authService.authStateChanges.listen((u) {
      _user = u;
      notifyListeners();
    });
  }

  Future<void> sendOtp(String phoneNumber) async {
    await _authService.sendOtp(
      phoneNumber: phoneNumber,
      onCodeSent: (id) {
        _pendingVerificationId = id;
        notifyListeners();
      },
      onError: (err) => throw Exception(err),
    );
  }

  /// Returns true if this is the user's first ever login (caller should
  /// then trigger Individual Book auto-creation per SRS 4.1).
  Future<bool> verifyOtp(String smsCode) async {
    if (_pendingVerificationId == null) {
      throw Exception('No OTP request in progress');
    }
    final cred = await _authService.verifyOtp(
      verificationId: _pendingVerificationId!,
      smsCode: smsCode,
    );
    return _authService.ensureUserDocAndCheckFirstLogin(cred.user!);
  }

  Future<bool> signInWithEmail(String email, String password) async {
    final cred = await _authService.signInWithEmail(email, password);
    return _authService.ensureUserDocAndCheckFirstLogin(cred.user!);
  }

  Future<bool> signUpWithEmail(String email, String password) async {
    final cred = await _authService.signUpWithEmail(email, password);
    return _authService.ensureUserDocAndCheckFirstLogin(cred.user!);
  }

  Future<void> signOut() => _authService.signOut();
}

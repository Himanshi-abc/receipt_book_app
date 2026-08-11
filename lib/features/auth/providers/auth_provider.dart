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

  /// Signup completion: verifies the mobile OTP (proving the number is
  /// real and reachable), then links email/password to that same account
  /// so the user ends up with one account carrying both sign-in methods.
  Future<bool> completeSignUp({
    required String smsCode,
    required String email,
    required String password,
  }) async {
    if (_pendingVerificationId == null) {
      throw Exception('No OTP request in progress');
    }
    await _authService.verifyOtp(
      verificationId: _pendingVerificationId!,
      smsCode: smsCode,
    );
    try {
      await _authService.linkEmailPassword(email, password);
    } catch (_) {
      // Roll back the bare phone-only account link created just above -
      // e.g. the email turned out to already be registered - so the
      // failed attempt doesn't leave an orphaned account behind.
      await _authService.deleteCurrentUser();
      rethrow;
    }
    return _authService.ensureUserDocAndCheckFirstLogin(_authService.currentUser!);
  }

  /// Forgot-password completion: verifies the mobile OTP. If the number
  /// was never linked to an existing account, Firebase silently creates a
  /// brand-new bare account for it - that's rolled back here so a stray
  /// number can't be used to conjure an empty account.
  Future<void> verifyOtpForPasswordReset(String smsCode) async {
    if (_pendingVerificationId == null) {
      throw Exception('No OTP request in progress');
    }
    final cred = await _authService.verifyOtp(
      verificationId: _pendingVerificationId!,
      smsCode: smsCode,
    );
    final isNewAccount = cred.additionalUserInfo?.isNewUser ?? false;
    if (isNewAccount) {
      await _authService.deleteCurrentUser();
      throw Exception('No account found with this mobile number.');
    }
  }

  Future<void> updatePassword(String newPassword) =>
      _authService.updatePassword(newPassword);

  Future<void> sendPasswordResetEmail(String email) =>
      _authService.sendPasswordResetEmail(email);

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

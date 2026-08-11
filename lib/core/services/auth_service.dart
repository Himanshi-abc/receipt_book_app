import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ---- Mobile OTP flow ----
  //
  // `verifyPhoneNumber` returns as soon as the request is *dispatched* - the
  // codeSent / verificationFailed callbacks fire later, asynchronously. So we
  // bridge them to a Completer: the returned Future only resolves once the SMS
  // is actually sent (codeSent) and rejects with the real FirebaseAuthException
  // on failure. Without this, callers `await` a Future that completes before
  // the outcome is known - they'd navigate to the OTP screen even when sending
  // failed, and any error thrown inside the callback would be swallowed
  // (unhandled async) instead of reaching their try/catch.
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
  }) {
    final completer = Completer<void>();
    _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      // Android can auto-retrieve the code and hand back a credential. We
      // deliberately do NOT auto sign-in here: the signup flow still has to
      // link email/password onto this number, and a silent phone-only
      // sign-in would skip that. The user enters the code on the OTP screen.
      verificationCompleted: (PhoneAuthCredential credential) {},
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
        if (!completer.isCompleted) completer.complete();
      },
      // End of the auto-retrieval window; harmless once codeSent already
      // completed the future, and a safety net if it somehow didn't.
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future;
  }

  Future<UserCredential> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  /// Attaches an email/password credential to the currently signed-in user
  /// (used right after phone-OTP verification during signup, so the mobile
  /// number and the email/password become two sign-in methods on the same
  /// account rather than two separate accounts).
  Future<UserCredential> linkEmailPassword(String email, String password) {
    final credential = EmailAuthProvider.credential(email: email, password: password);
    return _auth.currentUser!.linkWithCredential(credential);
  }

  /// Deletes the currently signed-in user. Used to roll back the bare
  /// phone-only account Firebase auto-creates when a Forgot Password OTP is
  /// verified for a mobile number that was never actually registered.
  Future<void> deleteCurrentUser() => _auth.currentUser!.delete();

  Future<void> updatePassword(String newPassword) =>
      _auth.currentUser!.updatePassword(newPassword);

  // ---- Email/password flow ----
  Future<UserCredential> signUpWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<void> signOut() => _auth.signOut();

  /// Ensures a `users/{uid}` doc exists. Returns true if this was the
  /// user's very first login (used to trigger auto-creation of the
  /// Individual Book - SRS 4.1: "On first login, app auto-creates the
  /// user's Individual Book.")
  Future<bool> ensureUserDocAndCheckFirstLogin(User firebaseUser) async {
    final ref = _db.collection('users').doc(firebaseUser.uid);
    final snap = await ref.get();
    if (snap.exists) return false;

    final user = AppUser(
      id: firebaseUser.uid,
      name: firebaseUser.displayName,
      phone: firebaseUser.phoneNumber,
      email: firebaseUser.email,
      createdAt: DateTime.now(),
    );
    await ref.set(user.toMap());
    return true;
  }
}

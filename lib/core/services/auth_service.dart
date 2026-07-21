import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ---- Mobile OTP flow ----
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        onError(e.message ?? 'Verification failed');
      },
      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
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

  // ---- Email/password flow ----
  Future<UserCredential> signUpWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

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

import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(
    String email,
    String password,
  ) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'البريد الإلكتروني مطلوب',
      );
    }

    if (password.isEmpty) {
      throw FirebaseAuthException(
        code: 'empty-password',
        message: 'كلمة المرور مطلوبة',
      );
    }

    try {
      return await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
    } on FirebaseAuthException {
      rethrow;
    }
  }

  Future<UserCredential> signUp(
    String name,
    String email,
    String password,
  ) async {
    final normalizedEmail = email.trim().toLowerCase();

    final cred = await _auth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );

    await cred.user?.updateDisplayName(name.trim());

    return cred;
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(
      email: email.trim().toLowerCase(),
    );
  }

  Future<void> signOut() {
    return _auth.signOut();
  }
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static Future<void>? _googleInitialization;

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<UserCredential> createAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final displayName = name.trim();
    if (displayName.isNotEmpty) {
      await result.user?.updateDisplayName(displayName);
    }
    return result;
  }

  Future<UserCredential> signInWithGoogle() async {
    _googleInitialization ??= GoogleSignIn.instance.initialize();
    await _googleInitialization;
    final googleUser = await GoogleSignIn.instance.authenticate();
    final credential = GoogleAuthProvider.credential(
      idToken: googleUser.authentication.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (_googleInitialization != null) {
      await GoogleSignIn.instance.signOut();
    }
  }
}

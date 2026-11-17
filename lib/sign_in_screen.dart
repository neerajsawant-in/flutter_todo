import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import 'auth_service.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});
  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isCreatingAccount = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() { _busy = true; _error = null; });
    try {
      await action();
    } on FirebaseAuthException catch (error) {
      setState(() => _error = switch (error.code) {
        'invalid-email' => 'That email address doesn’t look right.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Email or password is incorrect.',
        'email-already-in-use' => 'An account already uses that email.',
        'weak-password' => 'Choose a password with at least 6 characters.',
        'network-request-failed' => 'Check your internet connection and try again.',
        'operation-not-allowed' => 'Enable email/password sign-in in Firebase Authentication settings.',
        _ => error.message ?? 'Sign in failed. Please try again.',
      });
    } catch (error) {
      setState(() => _error = 'Sign in couldn’t finish. Check your Firebase and Google sign-in setup.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitEmail() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email and password to continue.');
      return;
    }
    await _run(() async {
      if (_isCreatingAccount) {
        await AuthService.instance.createAccount(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        );
      } else {
        await AuthService.instance.signIn(_email.text, _password.text);
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        height: 62,
                        width: 62,
                        decoration: BoxDecoration(
                          color: const Color(0xff6658e8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.check_rounded, color: Colors.white, size: 34),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('dayflow', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -.7)),
                    const SizedBox(height: 7),
                    Text(
                      _isCreatingAccount ? 'Create an account to keep your days in sync.' : 'Sign in and pick up where you left off.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xff898897)),
                    ),
                    const SizedBox(height: 30),
                    if (_isCreatingAccount) ...[
                      _input(_name, 'Your name', Icons.person_outline_rounded),
                      const SizedBox(height: 12),
                    ],
                    _input(_email, 'Email address', Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    _input(_password, 'Password', Icons.lock_outline_rounded, obscure: true),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Color(0xffc34355), fontSize: 13)),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _busy ? null : _submitEmail,
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xff6658e8), padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_isCreatingAccount ? 'Create account' : 'Sign in'),
                    ),
                    const SizedBox(height: 14),
                    Row(children: const [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: TextStyle(color: Color(0xff9998a5)))), Expanded(child: Divider())]),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _run(() async { await AuthService.instance.signInWithGoogle(); }),
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                      label: const Text('Continue with Google'),
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xff32313d), side: const BorderSide(color: Color(0xffe6e5ec)), padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _busy ? null : () => setState(() { _isCreatingAccount = !_isCreatingAccount; _error = null; }),
                      child: Text(_isCreatingAccount ? 'Already have an account? Sign in' : 'New here? Create an account'),
                    ),
                    const SizedBox(height: 8),
                    const Text('Your tasks and completed history sync to your account.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xffa09fac), fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Widget _input(TextEditingController controller, String hint, IconData icon, {bool obscure = false, TextInputType? keyboardType}) => TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xff8b8999)),
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xffe9e8ef))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xffe9e8ef))),
        ),
      );
}

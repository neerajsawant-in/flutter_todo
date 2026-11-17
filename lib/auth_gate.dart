import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import 'auth_service.dart';
import 'main.dart';
import 'sign_in_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final user = snapshot.data;
          if (user == null) return const SignInScreen();
          return TodoHome(userId: user.uid, user: user);
        },
      );
}

class AccountButton extends StatelessWidget {
  const AccountButton({super.key, required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final displayName = user.displayName?.trim() ?? '';
    final email = user.email ?? '';
    final initial = displayName.isNotEmpty ? displayName[0] : (email.isNotEmpty ? email[0] : 'A');
    return PopupMenuButton<String>(
        tooltip: 'Account',
        onSelected: (value) async {
          if (value == 'signout') await AuthService.instance.signOut();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'signout', child: Text('Sign out')),
        ],
        child: CircleAvatar(
          backgroundColor: const Color(0xffeceaff),
          foregroundImage: user.photoURL == null ? null : NetworkImage(user.photoURL!),
          child: Text(
            initial.toUpperCase(),
            style: const TextStyle(
              color: Color(0xff6658e8),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
  }
}

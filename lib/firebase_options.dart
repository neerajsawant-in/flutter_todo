// This placeholder keeps the app buildable until Firebase is configured.
// Run `flutterfire configure` from the project root to replace this file with
// the platform options for your Firebase project.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw StateError(
        'Firebase is not configured. Run flutterfire configure from the project root.',
      );
}

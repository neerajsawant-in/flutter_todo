# Dayflow

A Flutter to do app with animated daily tasks, IST reminders, Google or email/password sign-in, and a cloud-backed completion history.

## Configure Firebase (one time)

Firebase configuration is required before account sign-in and cloud history can work.

1. Open your project in the [Firebase Console](https://console.firebase.google.com/). In **Authentication → Sign-in method**, enable **Email/Password** and **Google**.
2. In **Firestore Database**, create a database.
3. In **Project settings → Your apps**, register an Android app with package name `com.example.to_do`. Add the debug SHA-1 fingerprint from the command below to this Android app; Google sign-in needs it.

   ```bash
   cd android
   ./gradlew signingReport
   ```

4. Download the Android config file and place it at `android/app/google-services.json`.
5. Install and log into the Firebase CLI, then generate this app's Dart Firebase configuration:

   ```bash
   npm install -g firebase-tools
   firebase login
   cd /home/kunkka/Documents/to_do
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

   Select the existing Firebase project and Android. This replaces the placeholder `lib/firebase_options.dart` with your project's options.
6. From the project root, deploy the included user-private Firestore rules:

   ```bash
   firebase deploy --only firestore:rules --project YOUR_FIREBASE_PROJECT_ID
   ```

Then run `flutter pub get` and restart the Android app. Each account's tasks are stored at `users/{userId}/tasks`; completing a task keeps it in the **History** filter. The Firestore rules restrict each account to its own tasks.

The Linux desktop target is a visual preview. Firebase sign-in and cloud storage are intended for Android/mobile; use an Android emulator or phone to try those features. Email/password sign-in uses an email address as the account ID, with an optional display name.

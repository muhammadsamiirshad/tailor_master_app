import 'package:firebase_auth/firebase_auth.dart';

class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);

  @override
  String toString() => message;
}

class AuthService {
  // Singleton-style lazy access — always uses FirebaseAuth.instance.
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_friendlyMessage(e));
    } catch (e) {
      throw AuthFailure(_genericMessage(e));
    }
  }

  Future<UserCredential> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_friendlyMessage(e));
    } catch (e) {
      throw AuthFailure(_genericMessage(e));
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_friendlyMessage(e));
    } catch (e) {
      throw AuthFailure(_genericMessage(e));
    }
  }

  // ─── Error messages ────────────────────────────────────────────────────────

  static String _friendlyMessage(FirebaseAuthException e) {
    switch (e.code) {
      // Login errors
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'No account found for this email. Please sign up first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';

      // Signup errors
      case 'email-already-in-use':
        return 'An account already exists for this email. Try signing in instead.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled.\n\n'
            '→ Go to Firebase Console → Authentication → Sign-in method → '
            'Enable "Email/Password".';
      case 'weak-password':
        return 'Your password is too weak. Please use at least 6 characters.';

      // Network & rate errors
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';

      // Config errors — very helpful for debugging
      case 'configuration-not-found':
        return 'Firebase configuration not found.\n\n'
            'Fix checklist:\n'
            '1. Enable Email/Password in Firebase Console → Authentication → Sign-in method.\n'
            '2. Ensure google-services.json matches your app package name (com.usbrodev.tailormaster).\n'
            '3. Run flutter clean and rebuild.';
      case 'app-not-authorized':
        return 'This app is not authorized to use Firebase Authentication. '
            'Check your SHA-1 fingerprint in the Firebase Console.';
      case 'api-key-not-valid':
        return 'Invalid API key. Re-download google-services.json from Firebase Console.';

      // Password reset
      case 'auth/user-not-found':
        return 'No account found with that email.';

      default:
        // Show the raw code to help with debugging unknown errors
        final code = e.code;
        final msg = e.message ?? 'An unknown error occurred.';
        return '[$code] $msg';
    }
  }

  static String _genericMessage(Object e) {
    final str = e.toString();
    // Catch known non-FirebaseAuthException issues
    if (str.contains('configuration-not-found') ||
        str.contains('CONFIGURATION_NOT_FOUND')) {
      return 'Firebase configuration not found.\n\n'
          'Please enable Email/Password sign-in in your Firebase Console:\n'
          'Firebase Console → Authentication → Sign-in method → Email/Password → Enable.';
    }
    if (str.contains('network')) {
      return 'Network error. Please check your internet connection.';
    }
    return 'An error occurred: $str';
  }
}

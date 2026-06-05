import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../firebase_options.dart';

class AuthActionResult {
  const AuthActionResult._({required this.success, required this.message});

  final bool success;
  final String message;

  factory AuthActionResult.ok(String message) {
    return AuthActionResult._(success: true, message: message);
  }

  factory AuthActionResult.failed(String message) {
    return AuthActionResult._(success: false, message: message);
  }
}

class AuthService {
  const AuthService._({required this.firebaseReady, this.disabledReason});

  final bool firebaseReady;
  final String? disabledReason;

  static bool _googleInitialized = false;

  static Future<AuthService> bootstrap() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      if (!_googleInitialized) {
        await GoogleSignIn.instance.initialize();
        _googleInitialized = true;
      }

      return const AuthService._(firebaseReady: true);
    } catch (_) {
      return const AuthService._(
        firebaseReady: false,
        disabledReason: 'Firebase is not configured yet.',
      );
    }
  }

  Stream<User?> authStateChanges() {
    if (!firebaseReady) {
      return Stream<User?>.value(null);
    }
    return FirebaseAuth.instance.authStateChanges();
  }

  Future<AuthActionResult> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (!firebaseReady) {
      return AuthActionResult.failed(_configurationMessage);
    }

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return AuthActionResult.ok('Signed in successfully.');
    } on FirebaseAuthException catch (error) {
      return AuthActionResult.failed(_friendlyFirebaseMessage(error));
    } catch (_) {
      return AuthActionResult.failed('Unable to sign in. Please try again.');
    }
  }

  Future<AuthActionResult> signInWithGoogle() async {
    if (!firebaseReady) {
      return AuthActionResult.failed(_configurationMessage);
    }

    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');

        await FirebaseAuth.instance.signInWithPopup(provider);
        return AuthActionResult.ok('Signed in with Google.');
      }

      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const <String>['email', 'profile'],
      );
      final credential = GoogleAuthProvider.credential(
        idToken: account.authentication.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      return AuthActionResult.ok('Signed in with Google.');
    } on GoogleSignInException catch (error) {
      return AuthActionResult.failed(_friendlyGoogleMessage(error));
    } on FirebaseAuthException catch (error) {
      return AuthActionResult.failed(_friendlyFirebaseMessage(error));
    } catch (_) {
      return AuthActionResult.failed(
        'Unable to complete Google sign-in. Please try again.',
      );
    }
  }

  Future<AuthActionResult> sendPasswordResetEmail(String email) async {
    if (!firebaseReady) {
      return AuthActionResult.failed(_configurationMessage);
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      return AuthActionResult.ok('Password reset email sent.');
    } on FirebaseAuthException catch (error) {
      return AuthActionResult.failed(_friendlyFirebaseMessage(error));
    } catch (_) {
      return AuthActionResult.failed(
        'Unable to send a password reset email. Please try again.',
      );
    }
  }

  Future<void> signOut() async {
    if (!firebaseReady) {
      return;
    }
    await FirebaseAuth.instance.signOut();
    if (_googleInitialized) {
      await GoogleSignIn.instance.signOut();
    }
  }

  String get _configurationMessage {
    return disabledReason ??
        'Firebase is not configured. Run flutterfire configure first.';
  }

  String _friendlyFirebaseMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network connection failed. Please check your connection.';
      case 'popup-closed-by-user':
        return 'Google sign-in was cancelled.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }

  String _friendlyGoogleMessage(GoogleSignInException error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Google sign-in was cancelled.';
      case GoogleSignInExceptionCode.interrupted:
        return 'Google sign-in was interrupted.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google sign-in is not available on this device.';
      default:
        return error.description ??
            'Unable to complete Google sign-in. Please try again.';
    }
  }
}

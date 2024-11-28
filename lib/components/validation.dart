import 'dart:convert';

import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:swiftpath/views/login_page.dart';
import 'package:swiftpath/views/splash_screen.dart';

class AuthValidation {
  static void showAlert({
    required BuildContext context,
    required String title,
    required String desc,
    VoidCallback? onPressed,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(desc),
          actions: [
            TextButton(
              onPressed: onPressed ?? () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  static bool validateFields({
    required BuildContext context,
    required String email,
    required String password,
    String? confirmPassword,
  }) {
    if (email.isEmpty ||
        password.isEmpty ||
        (confirmPassword?.isEmpty ?? false)) {
      showAlert(
        context: context,
        title: 'Empty Fields',
        desc: 'Please fill out all fields.',
      );
      return false;
    }

    if (confirmPassword != null && password != confirmPassword) {
      showAlert(
        context: context,
        title: 'Password Mismatch',
        desc: 'Make sure that you write the same password twice.',
      );
      return false;
    }

    return true;
  }

  static Future<void> handleFirebaseSignUp({
    required BuildContext context,
    required FirebaseAuth auth,
    required String email,
    required String password,
    required VoidCallback onSuccess,
    required VoidCallback onFailure,
  }) async {
    final Map<String, String> signUpErrorMessages = {
      'invalid-email': 'The email address is not valid.',
      'email-already-in-use': 'The email address is already in use.',
      'weak-password': 'The password is too weak.',
      'operation-not-allowed': 'Email/password sign up is not enabled.',
      'invalid-credential': 'The credentials are invalid or expired.',
    };

    try {
      onSuccess();
    } catch (e) {
      String errorMessage = 'An error occurred. Please try again.';

      if (e is FirebaseAuthException) {
        errorMessage = signUpErrorMessages[e.code] ??
            'An unexpected error occurred: ${e.message}.';
      } else {
        errorMessage = 'An unknown error occurred: ${e.toString()}';
      }
      showAlert(
        context: context,
        title: 'Sign Up Error',
        desc: errorMessage,
      );
      onFailure();
    }
  }

  static Future<void> handleFirebaseLogin({
    required BuildContext context,
    required FirebaseAuth auth,
    required String email,
    required String password,
    required VoidCallback onSuccess,
    required VoidCallback onFailure,
  }) async {
    final Map<String, String> errorMessages = {
      'user-not-found': 'No user found for this email.',
      'wrong-password': 'Wrong password provided.',
      'invalid-email': 'The email address is not valid.',
      'user-disabled': 'The user account has been disabled.',
      'too-many-requests': 'Too many login attempts. Please try again later.',
      'operation-not-allowed': 'Email and password sign-in is not enabled.',
      'invalid-credential': 'The supplied credentials are invalid or expired.',
    };

    try {
      await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      onSuccess();
    } catch (e) {
      String errorMessage = 'An error occurred. Please try again.';

      if (e is FirebaseAuthException) {
        errorMessage = errorMessages[e.code] ??
            'An unexpected error occurred: ${e.message}.';
      } else {
        errorMessage = 'An unknown error occurred: ${e.toString()}';
      }
      showAlert(
        context: context,
        title: 'Login Error',
        desc: errorMessage,
      );
      onFailure();
    }
  }

  static Future<void> signInWithGoogle(
      {required BuildContext context,
      required FirebaseAuth auth,
      required GoogleSignIn googleSignIn}) async {
    try {
      final GoogleUser = await googleSignIn.signIn();
      if (GoogleUser == null) {
        // User cancelled the sign-in
        return;
      }

      final GoogleAuth = await GoogleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: GoogleAuth.accessToken,
        idToken: GoogleAuth.idToken,
      );

      // Sign in to Firebase
      UserCredential userCredential =
          await auth.signInWithCredential(credential);
      User? userData = userCredential.user;

      if (userData == null) {
        print('Error: User credential is null.');
        return;
      }

      // Navigate to the splash screen after successful sign-in
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const SplashScreen()));
    } catch (e) {
      print('Sign in failed: $e');
      _showErrorDialog(context, e.toString());
    }
  }

  static void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static Future<void> signOut(
      {required BuildContext context,
      required FirebaseAuth auth,
      required GoogleSignIn googleSignIn}) async {
    try {
      if (auth.currentUser?.providerData.any((provider) =>
              provider.providerId == GoogleAuthProvider.PROVIDER_ID) ??
          false) {
        await googleSignIn.signOut();
      }

      await auth.signOut();
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => const LoginPage()));
    } catch (e) {
      print('Sign out failed: $e');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: const Text('Failed to sign out. Please try again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}

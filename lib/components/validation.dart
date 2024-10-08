import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
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
}
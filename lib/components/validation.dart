import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:swiftpath/views/login_page.dart';
import 'package:swiftpath/views/splash_screen.dart';
import 'package:toastification/toastification.dart';

class AuthValidation {
  static void showAlert({
    required BuildContext context,
    required String message,
  }) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.fillColored,
      description: RichText(
          text: TextSpan(
        text: message,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      )),
      icon: const Icon(Icons.error),
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  static bool validateFields({
    required BuildContext context,
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) {
    if (name.isEmpty) {
      toastification.show(
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        context: context,
        description: RichText(
            text: TextSpan(
          text: 'Name is required!',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        )),
        icon: const Icon(Icons.error),
        autoCloseDuration: const Duration(seconds: 3),
      );
      return false;
    }

    // Validate Email
    if (!RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$")
        .hasMatch(email)) {
      toastification.show(
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        context: context,
        description: RichText(
            text: TextSpan(
          text: 'Invalid email format!',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        )),
        icon: const Icon(Icons.error),
        autoCloseDuration: const Duration(seconds: 5),
      );
      return false;
    }

    // Validate Password
    if (password.length < 8) {
      toastification.show(
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        context: context,
        description: RichText(
            text: TextSpan(
          text: 'Password must be at least 8 characters long!',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        )),
        icon: const Icon(Icons.error),
        autoCloseDuration: const Duration(seconds: 3),
      );
      return false;
    }
    if (!RegExp(r"(?=.*[A-Z])").hasMatch(password)) {
      toastification.show(
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        context: context,
        description: RichText(
            text: TextSpan(
          text: 'Password must contain at least one uppercase letter!',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        )),
        icon: const Icon(Icons.error),
        autoCloseDuration: const Duration(seconds: 3),
      );
      return false;
    }
    if (!RegExp(r"(?=.*[a-z])").hasMatch(password)) {
      toastification.show(
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        context: context,
        description: RichText(
            text: TextSpan(
          text: 'Password must contain at least one lowercase letter!',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        )),
        icon: const Icon(Icons.error),
        autoCloseDuration: const Duration(seconds: 3),
      );
      return false; // Stop here if password lacks lowercase
    }
    if (!RegExp(r"(?=.*\d)").hasMatch(password)) {
      toastification.show(
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        context: context,
        description: RichText(
            text: TextSpan(
          text: 'Password must contain at least one number!',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        )),
        icon: const Icon(Icons.error),
        autoCloseDuration: const Duration(seconds: 5),
      );
      return false;
    }
    if (!RegExp(r"(?=.*[@$!%*?&])").hasMatch(password)) {
      toastification.show(
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        context: context,
        description: RichText(
          text: TextSpan(
            text:
                'Password must contain at least one special character! (@, #, \$, %, etc.)',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
        icon: const Icon(Icons.error),
        autoCloseDuration: const Duration(seconds: 5),
      );

      return false;
    }

    // Validate Confirm Password
    if (password != confirmPassword) {
      toastification.show(
        type: ToastificationType.error,
        style: ToastificationStyle.fillColored,
        context: context,
        title: const Text('Passwords do not match!'),
        icon: const Icon(Icons.error),
        autoCloseDuration: const Duration(seconds: 5),
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
    required String name, // Include the user's name as a parameter
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
      UserCredential userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = userCredential.user;
      if (user != null) {
        await FirebaseDatabase.instance
            .ref()
            .child('users')
            .child(user.uid)
            .set({
          'name': name,
          'email': email,
          'image': '',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      toastification.show(
        context: context,
        type: ToastificationType.success,
        style: ToastificationStyle.fillColored,
        title: const Text('Account Created Successfully!'),
        icon: const Icon(Icons.check),
        autoCloseDuration: const Duration(seconds: 3),
      );
      onSuccess();
    } catch (e) {
      String errorMessage = 'An error occurred. Please try again.';
      if (e is FirebaseAuthException) {
        errorMessage = signUpErrorMessages[e.code] ??
            'An unexpected error occurred: ${e.message}.';
        showAlert(
          context: context,
          message: errorMessage,
        );
      } else {
        errorMessage = 'An unknown error occurred: ${e.toString()}';
        showAlert(
          context: context,
          message: errorMessage,
        );
      }
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
      toastification.show(
        context: context,
        type: ToastificationType.success,
        style: ToastificationStyle.fillColored,
        title: const Text('Login Successfully!'),
        icon: const Icon(Icons.check),
        autoCloseDuration: const Duration(seconds: 3),
      );
      onSuccess();
    } catch (e) {
      String errorMessage = 'An error occurred. Please try again.';

      if (e is FirebaseAuthException) {
        errorMessage = errorMessages[e.code] ??
            'An unexpected error occurred: ${e.message}.';
        showAlert(
          context: context,
          message: errorMessage,
        );
      } else {
        errorMessage = 'An unknown error occurred: ${e.toString()}';
        showAlert(
          context: context,
          message: errorMessage,
        );
      }
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

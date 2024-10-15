import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:swiftpath/components/validation.dart';
import 'package:swiftpath/components/components.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  static String id = 'login';

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = FirebaseAuth.instance;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _saving = false;

  void _showAlert({
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

  void _forgotPassword() {
    if (_emailController.text.trim().isEmpty) {
      _showAlert(
        title: 'Error',
        desc: 'Please enter your email address to reset your password.',
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: const Text('Are you sure you want to reset your password?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _auth.sendPasswordResetEmail(
                    email: _emailController.text.trim(),
                  );
                  _showAlert(
                    title: 'Success',
                    desc:
                        'A password reset link has been sent to your email address.',
                  );
                } catch (e) {
                  _showAlert(
                    title: 'Error',
                    desc: 'Failed to send reset email. Please try again.',
                  );
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LoadingOverlay(
        isLoading: _saving,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TopScreenImage(screenImageName: 'ambulance.png'),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const ScreenTitle(title: 'Login'),
                        CustomTextField(
                          hintText: 'Email',
                          obscureText: false,
                          controller: _emailController,
                        ),
                        CustomTextField(
                          hintText: 'Password',
                          obscureText: true,
                          controller: _passwordController,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _forgotPassword,
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(color: Colors.blue),
                            ),
                          ),
                        ),
                        CustomBottomScreen(
                          textButton: 'Login',
                          heroTag: 'login_btn',
                          question: 'Don\'t have an account? Sign Up',
                          buttonPressed: () async {
                            FocusManager.instance.primaryFocus?.unfocus();
                            setState(() {
                              _saving = true;
                            });

                            final email = _emailController.text.trim();
                            final password = _passwordController.text.trim();

                            if (!AuthValidation.validateFields(
                              context: context,
                              email: email,
                              password: password,
                            )) {
                              setState(() {
                                _saving = false;
                              });
                              return;
                            }

                            await AuthValidation.handleFirebaseLogin(
                              context: context,
                              auth: _auth,
                              email: email,
                              password: password,
                              onSuccess: () {
                                setState(() {
                                  _saving = false;
                                  Navigator.pushReplacementNamed(
                                      context, '/splash-screen');
                                });
                              },
                              onFailure: () {
                                setState(() {
                                  _saving =
                                      false; // Reset loading state on failure
                                });
                              },
                            );
                          },
                          questionPressed: () {
                            Navigator.pushNamed(context, "/signup");
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

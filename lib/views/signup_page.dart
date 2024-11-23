import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:swiftpath/components/validation.dart';
import 'package:swiftpath/components/components.dart';
import 'package:swiftpath/views/login_page.dart';
import 'package:swiftpath/views/splash_screen.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  static String id = 'signup';

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _auth = FirebaseAuth.instance;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _saving = false;

  void _resetForm() {
    _emailController.clear();
    _passwordController.clear();
    _confirmPassController.clear();
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
                        CustomTextField(
                          hintText: 'Confirm Password',
                          obscureText: true,
                          controller: _confirmPassController,
                        ),
                        CustomBottomScreen(
                          textButton: 'Sign Up',
                          heroTag: 'signup_btn',
                          question: 'Have an account? Login',
                          buttonPressed: () async {
                            FocusManager.instance.primaryFocus?.unfocus();
                            setState(() {
                              _saving = true;
                            });

                            final email = _emailController.text.trim();
                            final password = _passwordController.text.trim();
                            final confirmPassword =
                                _confirmPassController.text.trim();

                            if (!AuthValidation.validateFields(
                              context: context,
                              email: email,
                              password: password,
                              confirmPassword: confirmPassword,
                            )) {
                              setState(() {
                                _saving = false;
                              });
                              return;
                            }

                            await AuthValidation.handleFirebaseSignUp(
                              context: context,
                              auth: _auth,
                              email: email,
                              password: password,
                              onSuccess: () {
                                setState(() {
                                  _saving = false;
                                  _resetForm();
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              const SplashScreen()));
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
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const LoginPage()));
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

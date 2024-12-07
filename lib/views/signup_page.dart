import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  bool _saving = false;

  bool _showPassword = false;
  bool _showConfirmPassword = false;

  void _resetForm() {
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _confirmPassController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: LoadingOverlay(
        isLoading: _saving,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const TopScreenImage(screenImageName: 'ambulance.png'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    child: Column(
                      children: [
                        CustomTextField(
                          hintText: 'Name',
                          obscureText: false,
                          controller: _nameController,
                        ),
                        const SizedBox(height: 20),
                        CustomTextField(
                          hintText: 'Email',
                          obscureText: false,
                          controller: _emailController,
                        ),
                        const SizedBox(height: 20),
                        CustomTextField(
                          hintText: 'Password',
                          obscureText: !_showPassword,
                          controller: _passwordController,
                          suffixIcon: Icon(
                            _showPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onSuffixIconPressed: () {
                            setState(() {
                              _showPassword = !_showPassword;
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        CustomTextField(
                          hintText: 'Confirm Password',
                          obscureText: !_showConfirmPassword,
                          controller: _confirmPassController,
                          suffixIcon: Icon(
                            _showConfirmPassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onSuffixIconPressed: () {
                            setState(() {
                              _showConfirmPassword = !_showConfirmPassword;
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        CustomBottomScreen(
                          textButton: 'Sign Up',
                          heroTag: 'signup_btn',
                          question: 'Have an account? Login',
                          buttonPressed: () async {
                            FocusManager.instance.primaryFocus?.unfocus();
                            setState(() {
                              _saving = true;
                            });
                            final name = _nameController.text.trim();
                            final email = _emailController.text.trim();
                            final password = _passwordController.text.trim();
                            final confirmPassword =
                                _confirmPassController.text.trim();

                            if (!AuthValidation.validateFields(
                              context: context,
                              name: name,
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
                              name: name,
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
                                          const SplashScreen(),
                                    ),
                                  );
                                });
                              },
                              onFailure: () {
                                setState(() {
                                  _saving = false;
                                });
                              },
                            );
                          },
                          questionPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginPage(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Sign up using',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: () => AuthValidation.signInWithGoogle(
                                context: context,
                                auth: _auth,
                                googleSignIn: _googleSignIn,
                              ),
                              icon: CircleAvatar(
                                radius: 25,
                                backgroundColor: Colors.transparent,
                                child: Image.asset(
                                  'assets/images/icons/google.png',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

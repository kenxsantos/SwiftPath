import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  static String id = 'dashboard_page';

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  bool _isMenuOpen = false; // Tracks the state of the sliding panel

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0), // Starts off-screen to the left
      end: Offset.zero, // Slides into view
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      if (_auth.currentUser?.providerData.any((provider) =>
              provider.providerId == GoogleAuthProvider.PROVIDER_ID) ??
          false) {
        await _googleSignIn.signOut();
      }

      await _auth.signOut();
      Navigator.pushReplacementNamed(context, '/login');
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

  void _toggleMenu() {
    if (_isMenuOpen) {
      _controller.reverse().then((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          setState(() {
            _isMenuOpen = false;
          });
        });
      });
    } else {
      setState(() {
        _isMenuOpen = true;
      });
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Welcome, ${_auth.currentUser?.displayName ?? 'User'}!',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 20),
                Text(
                  'You are logged in successfully.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
        SlideTransition(
          position: _slideAnimation,
          child: Material(
            elevation: 16.0,
            child: Container(
              width: double.infinity,
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 50),
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _toggleMenu,
                    ),
                  ),
                  ListTile(
                    title: Text(
                      'Welcome, ${_auth.currentUser?.displayName ?? 'User'}!',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  ListTile(
                    onTap: () {
                      Navigator.pushNamed(context, '/edit_profile');
                    },
                    leading: const Icon(Icons.person),
                    title: const Text('Profile'),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Logout'),
                    onTap: () => _signOut(context),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!_isMenuOpen)
          Positioned(
            top: 40.0,
            left: 16.0,
            child: GestureDetector(
              onTap: _toggleMenu,
              child: Container(
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.menu,
                  color: Colors.black,
                  size: 32,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

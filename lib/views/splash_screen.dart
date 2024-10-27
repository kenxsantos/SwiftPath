import 'package:flutter/material.dart';
import 'package:swiftpath/views/maps_page.dart';
import 'package:lottie/lottie.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4)).then((value) =>
        Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (context) =>
                const MapScreen(origin: '', destination: ''))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          height: 200,
          width: 200,
          child: LottieBuilder.asset('assets/animassets/mapanimation.json'),
        ),
      ),
    );
  }
}

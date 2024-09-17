import 'package:flutter/material.dart';
import 'package:swiftpath/pages/landing_page.dart';
import 'package:swiftpath/pages/home_page.dart';
import 'package:swiftpath/pages/signup_page.dart';
import 'package:swiftpath/pages/incident_report.dart';
import 'package:swiftpath/pages/thankyou_page.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home:  const ReportIncidentPage(),
      routes: {
        '/landing': (context) => const LandingPage(),
        '/homepage': (context) => const HomePage(),
        '/sign-in': (context) => const SignUpPage(),
        '/incident': (context) => const ReportIncidentPage(),
        '/thank-you':(context) => const ThankyouPage(),
      },
    );
  }
}
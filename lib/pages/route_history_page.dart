import 'package:flutter/material.dart';

class RouteHistoryPage extends StatefulWidget {
  const RouteHistoryPage({super.key});

  @override
  _RouteHistoryPageState createState() => _RouteHistoryPageState();
}

class _RouteHistoryPageState extends State<RouteHistoryPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text('Route History'),
        ),
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      ),
        );
  }
}
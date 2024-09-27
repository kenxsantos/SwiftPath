import 'package:flutter/material.dart';

class RouteHistoryPage extends StatefulWidget {
  const RouteHistoryPage({super.key});

  @override
  _RouteHistoryPageState createState() => _RouteHistoryPageState();
}

class _RouteHistoryPageState extends State<RouteHistoryPage> {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context); // Cancel button action
          },
          icon: const Icon(
            Icons.arrow_back_ios_outlined,
            color: Colors.blue,
            size: 24,
          ),
        ),
        title: const Center(
          child: Text('Route History'),
        ),
      ),
    );
  }
}
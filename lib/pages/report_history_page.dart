import 'package:flutter/material.dart';

class ReportHistoryPage extends StatefulWidget {
  const ReportHistoryPage({super.key});

  @override
  _ReportHistoryPageState createState() => _ReportHistoryPageState();
}

class _ReportHistoryPageState extends State<ReportHistoryPage> {
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
          child: Text('Report History'),
        ),
      ),
    );
  }
}
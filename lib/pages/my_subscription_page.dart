import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:roam_flutter/roam_flutter.dart';

class MySubcriptionPage extends StatefulWidget {
  const MySubcriptionPage({super.key, required this.title});
  static const String routeName = "/MySubcriptionPage";
  final String title;
  @override
  _MySubcriptionPageState createState() => _MySubcriptionPageState();
}

class _MySubcriptionPageState extends State<MySubcriptionPage> {
  String? myUser;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          children: [
            SelectableText(
              '\nUser Details:\n $myUser\n',
              textAlign: TextAlign.center,
            ),
            ElevatedButton(
                child: const Text('Subscribe Location'),
                onPressed: () async {
                  setState(() {
                    myUser = "user location subscribed";
                  });
                  try {
                    await Roam.subscribeLocation();
                  } on PlatformException {
                    print('Subscribe Location Error');
                  }
                }),
            ElevatedButton(
                child: const Text('Subscribe User Location'),
                onPressed: () async {
                  try {
                    setState(() {
                      myUser = "user location subscribed";
                    });
                    await Roam.subscribeUserLocation(
                        userId: '60181b1f521e0249023652bc');
                  } on PlatformException {
                    print('Subscribe User Location Error');
                  }
                }),
            ElevatedButton(
                child: const Text('Subscribe Events'),
                onPressed: () async {
                  try {
                    setState(() {
                      myUser = "user events subscribed";
                    });
                    await Roam.subscribeEvents();
                  } on PlatformException {
                    print('Subscribe Events Error');
                  }
                }),
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:roam_flutter/roam_flutter.dart';

class MyLocationTrackingPage extends StatefulWidget {
  const MyLocationTrackingPage({super.key, required this.title});
  static const String routeName = "/MyLocationTrackingPage";
  final String title;
  @override
  _MyLocationTrackingPageState createState() => _MyLocationTrackingPageState();
}

class _MyLocationTrackingPageState extends State<MyLocationTrackingPage> {
  bool? isTracking;
  String? valueText;
  String? locationResponse;
  static const platform = MethodChannel('roam_example');
  final TextEditingController _textFieldController = TextEditingController();
  Future<void> _displayTextInputDialog(BuildContext context) async {
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Enter Tracking Type'),
            content: TextField(
              onChanged: (value) {
                setState(() {
                  valueText = value;
                });
              },
              controller: _textFieldController,
              decoration: const InputDecoration(
                  hintText: "active/passsive/balanced/custom/time/distance"),
            ),
            actions: <Widget>[
              TextButton(
                // color: Colors.red,
                // textColor: Colors.white,
                child: const Text('CANCEL'),
                onPressed: () {
                  setState(() {
                    Navigator.pop(context);
                  });
                },
              ),
              TextButton(
                // color: Colors.green,
                // textColor: Colors.white,
                child: const Text('OK'),
                onPressed: () async {
                  Roam.onLocation((location) async {
                    print(jsonEncode(location));
                    await platform.invokeMethod(
                        'send_notification', {'body': jsonEncode(location)});
                    setState(() {
                      locationResponse = location.toString();
                    });
                  });

                  // Roam.setForeground(true, "Flutter Example", "Tap to open",
                  //     "mipmap/ic_launcher", "ai.roam.example.MainActivity");
                  try {
                    switch (valueText) {
                      case "active":
                        Roam.startTracking(trackingMode: "active");
                        Navigator.pop(context);
                        break;
                      case "balanced":
                        Roam.startTracking(trackingMode: "balanced");
                        Navigator.pop(context);
                        break;
                      case "passive":
                        Roam.startTracking(trackingMode: "passive");
                        Navigator.pop(context);
                        break;
                      case "custom":
                        Map<String, dynamic> fitnessTracking = {
                          "activityType": "fitness",
                          "showsBackgroundLocationIndicator": true,
                          "allowBackgroundLocationUpdates": true,
                          "distanceFilter": 10,
                          "desiredAccuracy": "nearestTenMeters",
                          "distanceInterval": 15
                        };
                        Roam.startTracking(
                            trackingMode: "custom",
                            customMethods: fitnessTracking);
                        //Navigator.pop(context);
                        break;
                      case "time":
                        Map<String, dynamic> fitnessTracking = {
                          "showsBackgroundLocationIndicator": true,
                          "allowBackgroundLocationUpdates": true,
                          "desiredAccuracy": "kCLLocationAccuracyBest",
                          "timeInterval": 5
                        };
                        Roam.startTracking(
                            trackingMode: "custom",
                            customMethods: fitnessTracking);
                        Navigator.pop(context);
                        break;
                      case "distance":
                        Map<String, dynamic> fitnessTracking = {
                          "activityType": "fitness",
                          "showsBackgroundLocationIndicator": true,
                          "allowBackgroundLocationUpdates": true,
                          "distanceFilter": 5,
                          "desiredAccuracy": "nearestTenMeters",
                          "distanceInterval": 5
                        };
                        Roam.startTracking(
                            trackingMode: "custom",
                            customMethods: fitnessTracking);
                        Navigator.pop(context);
                        break;
                      default:
                        Navigator.pop(context);
                        break;
                    }
                  } on PlatformException {
                    print('Trip Error');
                  }
                  Navigator.pop(context);
                },
              ),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          children: [
            SelectableText('\nTracking status: $isTracking\n'),
            SelectableText('\nLocation: $locationResponse\n'),
            ElevatedButton(
                child: const Text('Update Current Location'),
                onPressed: () async {
                  try {
                    Map<String, dynamic> testMetaData = {};
                    testMetaData['param1'] = "value";
                    testMetaData['param2'] = 123;
                    await Roam.updateCurrentLocation(
                        accuracy: 100, jsonObject: testMetaData);
                  } on PlatformException {
                    print('Update Current Location Error');
                  }
                }),
            ElevatedButton(
                child: const Text('Start Tracking'),
                onPressed: () async {
                  _displayTextInputDialog(context);
                }),
            ElevatedButton(
                child: const Text('Stop Tracking'),
                onPressed: () async {
                  // Roam.setForeground(false, "Flutter Example", "Tap to open",
                  //     "mipmap/ic_launcher", "ai.roam.example.MainActivity");
                  try {
                    await Roam.stopTracking();
                  } on PlatformException {
                    print('Stop Tracking Error');
                  }
                }),
          ],
        ),
      ),
    );
  }
}

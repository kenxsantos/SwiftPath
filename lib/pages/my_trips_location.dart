import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:roam_flutter/RoamTrackingMode.dart';
import 'package:roam_flutter/roam_flutter.dart';
import 'package:roam_flutter/trips_v2/RoamTrip.dart';
import 'package:roam_flutter/trips_v2/request/RoamTripStops.dart';
import 'package:swiftpath/logger.dart';

class MyItemsPage extends StatefulWidget {
  const MyItemsPage({super.key, required this.title});

  static const String routeName = "/MyItemsPage";

  final String title;

  @override
  _MyItemsPageState createState() => _MyItemsPageState();
}

class _MyItemsPageState extends State<MyItemsPage> {
  String? myTrip;
  String? tripId;
  String? response;

  final TextEditingController _textFieldController = TextEditingController();

  Future<void> _displayTripsInputDialog(
      BuildContext context, String type) async {
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Enter Trip Id'),
            content: TextField(
              onChanged: (value) {
                setState(() {
                  tripId = value;
                });
              },
              controller: _textFieldController,
              decoration: const InputDecoration(hintText: "Enter Trip Id"),
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
                  try {
                    switch (type) {
                      case "getTripStatus":
                        Roam.getTripStatus(
                            tripId: tripId!,
                            callBack: ({trip}) {
                              setState(() {
                                myTrip = trip;
                              });
                              print(trip);
                            });
                        break;

                      case "getTrip":
                        Roam.getTrip(tripId!, ({roamTripResponse}) {
                          String responseString =
                              jsonEncode(roamTripResponse?.toJson());
                          print('Get trip response: $responseString');
                          CustomLogger.writeLog(responseString);
                          setState(() {
                            tripId = roamTripResponse?.tripDetails?.id;
                          });
                        }, ({error}) {
                          String errorString = jsonEncode(error?.toJson());
                          print('Error: $errorString');
                          CustomLogger.writeLog(errorString);
                        });
                        break;

                      case "subscribeTrip":
                        Roam.subscribeTripStatus(
                          tripId: tripId!,
                        );
                        break;
                      case "unSubscribeTripStatus":
                        print("unSubscribeTripStatus");
                        Roam.ubSubscribeTripStatus(
                          tripId: tripId!,
                        );
                        break;
                      case "startTrip":
                        Roam.startTrip(({roamTripResponse}) {
                          String responseString =
                              jsonEncode(roamTripResponse?.toJson());
                          print('Start trip response: $responseString');
                          CustomLogger.writeLog(responseString);
                          setState(() {
                            tripId = roamTripResponse?.tripDetails?.id;
                          });
                        }, ({error}) {
                          String errorString = jsonEncode(error?.toJson());
                          print('Error: $errorString');
                          CustomLogger.writeLog(errorString);
                        }, tripId: tripId);
                        break;

                      case "quickTrip":
                        RoamTrip quickTrip = RoamTrip(isLocal: false);
                        Roam.startTrip(({roamTripResponse}) {
                          String responseString =
                              jsonEncode(roamTripResponse?.toJson());
                          print('Start quick trip response: $responseString');
                          CustomLogger.writeLog(
                              'Start quick trip response: $responseString');
                          setState(() {
                            tripId = roamTripResponse?.tripDetails?.id;
                          });
                        }, ({error}) {
                          String errorString = jsonEncode(error?.toJson());
                          print('Error: $errorString');
                          CustomLogger.writeLog(errorString);
                        },
                            roamTrip: quickTrip,
                            roamTrackingMode: RoamTrackingMode.time(5,
                                desiredAccuracy: DesiredAccuracy.HIGH));
                        break;

                      case "updateTrip":
                        RoamTrip updateTrip = RoamTrip(isLocal: false);
                        updateTrip.description = "test description";
                        Roam.updateTrip(updateTrip, ({roamTripResponse}) {
                          String responseString =
                              jsonEncode(roamTripResponse?.toJson());
                          print('Update trip response: $responseString');
                          CustomLogger.writeLog(
                              'Update trip response: $responseString');
                          setState(() {
                            tripId = roamTripResponse?.tripDetails?.id;
                          });
                        }, ({error}) {
                          String errorString = jsonEncode(error?.toJson());
                          print('Error: $errorString');
                          CustomLogger.writeLog(errorString);
                        });
                        break;

                      case "pauseTrip":
                        Roam.pauseTrip(tripId!, ({roamTripResponse}) {
                          String responseString =
                              jsonEncode(roamTripResponse?.toJson());
                          print('Pause trip response: $responseString');
                          CustomLogger.writeLog(responseString);
                          setState(() {
                            tripId = roamTripResponse?.tripDetails?.id;
                          });
                        }, ({error}) {
                          String errorString = jsonEncode(error?.toJson());
                          print('Error: $errorString');
                          CustomLogger.writeLog(errorString);
                        });
                        break;

                      case "resumeTrip":
                        Roam.resumeTrip(tripId!, ({roamTripResponse}) {
                          String responseString =
                              jsonEncode(roamTripResponse?.toJson());
                          print('Resume trip response: $responseString');
                          CustomLogger.writeLog(responseString);
                          setState(() {
                            tripId = roamTripResponse?.tripDetails?.id;
                          });
                        }, ({error}) {
                          String errorString = jsonEncode(error?.toJson());
                          print('Error: $errorString');
                          CustomLogger.writeLog(errorString);
                        });
                        break;

                      case "endTrip":
                        Roam.endTrip(tripId!, false, ({roamTripResponse}) {
                          String responseString =
                              jsonEncode(roamTripResponse?.toJson());
                          print('End trip response: $responseString');
                          CustomLogger.writeLog(responseString);
                          setState(() {
                            tripId = roamTripResponse?.tripDetails?.id;
                          });
                        }, ({error}) {
                          String errorString = jsonEncode(error?.toJson());
                          print('Error: $errorString');
                          CustomLogger.writeLog(errorString);
                        });
                        break;

                      case "syncTrip":
                        Roam.syncTrip(tripId!, ({roamSyncTripResponse}) {
                          String responseString =
                              jsonEncode(roamSyncTripResponse?.toJson());
                          print('End trip response: $responseString');
                          CustomLogger.writeLog(responseString);
                        }, ({error}) {
                          String errorString = jsonEncode(error?.toJson());
                          print('Error: $errorString');
                          CustomLogger.writeLog(errorString);
                        });
                        break;

                      case "deleteTrip":
                        Roam.deleteTrip(tripId!, ({roamDeleteTripResponse}) {
                          String responseString =
                              jsonEncode(roamDeleteTripResponse?.toJson());
                          print('Delete trip response: $responseString}');
                          CustomLogger.writeLog(responseString);
                          setState(() {
                            tripId = roamDeleteTripResponse?.trip?.id;
                          });
                        }, ({error}) {
                          String errorString = jsonEncode(error?.toJson());
                          print('Error: $errorString');
                          CustomLogger.writeLog(errorString);
                        });
                        break;

                      case "getTripSummary":
                        Roam.getTripSummary(tripId!, ({roamTripResponse}) {
                          String responseString =
                              jsonEncode(roamTripResponse?.toJson());
                          print('End trip response: $responseString');
                          CustomLogger.writeLog(responseString);
                          setState(() {
                            tripId = roamTripResponse?.tripDetails?.id;
                          });
                        }, ({error}) {
                          String errorString = jsonEncode(error?.toJson());
                          print('Error: $errorString');
                          CustomLogger.writeLog(errorString);
                        });
                        break;

                      case "getActiveTrips":
                        Roam.getActiveTrips(false, ({roamActiveTripResponse}) {
                          String responseString =
                              jsonEncode(roamActiveTripResponse?.toJson());
                          print('Get active trips response: $responseString}');
                          CustomLogger.writeLog(responseString);
                        }, ({error}) {
                          String errorString = jsonEncode(error?.toJson());
                          print('Error: $errorString');
                          CustomLogger.writeLog(errorString);
                        });
                        break;

                      default:
                        print("default");
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
    return new Scaffold(
        appBar: new AppBar(
          title: new Text(widget.title),
        ),
        body: SingleChildScrollView(
          child: Center(
            child: Column(
              children: [
                SelectableText(
                  '\nTrip Details:\n $tripId\n\n$response',
                  textAlign: TextAlign.center,
                ),
                ElevatedButton(
                    child: const Text('Create Online Trip'),
                    onPressed: () async {
                      setState(() {
                        response = "creating trip..";
                      });
                      try {
                        RoamTripStops stop = RoamTripStops(
                            600, [77.63414185889549, 12.915192126794398]);
                        RoamTrip roamTrip = RoamTrip(isLocal: false);
                        roamTrip.stop?.add(stop);
                        Roam.createTrip(roamTrip, ({roamTripResponse}) {
                          String responseString =
                              jsonEncode(roamTripResponse?.toJson());
                          print('Create online trip response: $responseString');
                          CustomLogger.writeLog(
                              'Create online trip response: $responseString');
                          setState(() {
                            tripId = roamTripResponse!.tripDetails!.id;
                            response =
                                'Create online trip response: $responseString';
                            print(jsonEncode(roamTripResponse.toJson()));
                          });
                        }, ({error}) {
                          String errorString = jsonEncode(error?.toJson());
                          print(errorString);
                          setState(() {
                            response = errorString;
                          });
                          CustomLogger.writeLog(errorString);
                        });
                      } on PlatformException {
                        print('Create Trip Error');
                      }
                    }),
                ElevatedButton(
                    child: const Text('Create Offline Trip'),
                    onPressed: () async {
                      setState(() {
                        response = "creating trip..";
                      });
                      try {
                        RoamTripStops stop = RoamTripStops(
                            600, [77.63414185889549, 12.915192126794398]);
                        RoamTrip roamTrip = RoamTrip(isLocal: true);
                        roamTrip.stop?.add(stop);
                        Roam.createTrip(roamTrip, ({roamTripResponse}) {
                          String responseString =
                              jsonEncode(roamTripResponse?.toJson());
                          print(
                              'Create offline trip response: $responseString');
                          CustomLogger.writeLog(
                              'Create offline trip response: $responseString');
                          setState(() {
                            tripId = roamTripResponse?.tripDetails?.id;
                            response =
                                'Create offline trip response: $responseString';
                            print(jsonEncode(roamTripResponse?.toJson()));
                          });
                        }, ({error}) {
                          String errorString = jsonEncode(error?.toJson());
                          print(errorString);
                          setState(() {
                            response = errorString;
                          });
                          CustomLogger.writeLog(errorString);
                        });
                      } on PlatformException {
                        print('Create Trip Error');
                      }
                    }),
                ElevatedButton(
                    child: const Text('Get Trip'),
                    onPressed: () async {
                      try {
                        Roam.getTrip(tripId!, ({roamTripResponse}) {
                          String responseString =
                              jsonEncode(roamTripResponse?.toJson());
                          print('Get trip response: $responseString');
                          CustomLogger.writeLog(
                              'Get trip response: $responseString');
                          setState(() {
                            tripId = roamTripResponse?.tripDetails?.id;
                            response = 'Get trip response: $responseString';
                          });
                        }, ({error}) {
                          String errorString = jsonEncode(error?.toJson());
                          print('Error: $errorString');
                          CustomLogger.writeLog(errorString);
                          setState(() {
                            response = errorString;
                          });
                        });
                      } catch (error) {
                        print(error);
                      }
                      _displayTripsInputDialog(context, "getTrip");
                    }),
                ElevatedButton(
                    child: const Text('Subscribe Trip Status'),
                    onPressed: () async {
                      setState(() {
                        myTrip = 'trip subscribed';
                      });
                      try {
                        _displayTripsInputDialog(context, "subscribeTrip");
                      } on PlatformException {
                        print('Subscribe Trip Status Error');
                      }
                    }),
                ElevatedButton(
                    child: const Text('Unsubscribe Trip Status'),
                    onPressed: () async {
                      setState(() {
                        myTrip = 'trip unsubscribed';
                      });
                      try {
                        _displayTripsInputDialog(
                            context, "unSubscribeTripStatus");
                      } on PlatformException {
                        print('Unsubscribe Trip Status Error');
                      }
                    }),
                ElevatedButton(
                    child: const Text('Start Trip'),
                    onPressed: () async {
                      try {
                        _displayTripsInputDialog(context, "startTrip");
                        Roam.startTrip(({roamTripResponse}) {
                          String responseString =
                              jsonEncode(roamTripResponse?.toJson());
                          print('Start trip response: $responseString');
                          CustomLogger.writeLog(
                              'Start trip response: $responseString');
                          setState(() {
                            tripId = roamTripResponse?.tripDetails?.id;
                            response = 'Start trip response: $responseString';
                          });
                        }, ({error}) {
                          String errorString = jsonEncode(error?.toJson());
                          print('Error: $errorString');
                          CustomLogger.writeLog(errorString);
                          setState(() {
                            response = errorString;
                          });
                        }, tripId: tripId);
                      } on PlatformException {
                        print('Start Trip Error');
                      }
                    }),
                ElevatedButton(
                    child: const Text('Start Online Quick Trip'),
                    onPressed: () async {
                      try {
                        _displayTripsInputDialog(context, "quickTrip");
                        RoamTrip quickTrip = RoamTrip(isLocal: false);
                        RoamTripStops stop = RoamTripStops(
                            600, [77.63414185889549, 12.915192126794398]);
                        quickTrip.stop?.add(stop);
                        Roam.startTrip(({roamTripResponse}) {
                          String responseString =
                              jsonEncode(roamTripResponse?.toJson());
                          print('Online Quick trip response: $responseString');
                          CustomLogger.writeLog(
                              'Online Quick trip response: $responseString');
                          setState(() {
                            tripId = roamTripResponse?.tripDetails?.id;
                            response =
                                'Online Quick trip response: $responseString';
                          });
                        }, ({error}) {
                          String errorString = jsonEncode(error?.toJson());
                          print('Error: $errorString');
                          CustomLogger.writeLog(errorString);
                          setState(() {
                            response = errorString;
                          });
                        },
                            roamTrip: quickTrip,
                            roamTrackingMode: RoamTrackingMode.time(5,
                                desiredAccuracy: DesiredAccuracy.HIGH));
                      } on PlatformException {
                        print('Quick Trip Error');
                      }
                    }),
                ElevatedButton(
                    child: const Text('Start Offline Quick Trip'),
                    onPressed: () async {
                      try {
                        _displayTripsInputDialog(context, "quickTrip");
                        RoamTrip quickTrip = RoamTrip(isLocal: true);
                        RoamTripStops stop = RoamTripStops(
                            600, [77.63414185889549, 12.915192126794398]);
                        quickTrip.stop?.add(stop);
                        Roam.startTrip(({roamTripResponse}) {
                          String responseString =
                              jsonEncode(roamTripResponse?.toJson());
                          print('Offline Quick trip response: $responseString');
                          CustomLogger.writeLog(
                              'Offline Quick trip response: $responseString');
                          setState(() {
                            tripId = roamTripResponse?.tripDetails?.id;
                            response =
                                'Offline Quick trip response: $responseString';
                          });
                        }, ({error}) {
                          String errorString = jsonEncode(error?.toJson());
                          print('Error: $errorString');
                          CustomLogger.writeLog(errorString);
                          setState(() {
                            response = errorString;
                          });
                        },
                            roamTrip: quickTrip,
                            roamTrackingMode: RoamTrackingMode.time(5,
                                desiredAccuracy: DesiredAccuracy.HIGH));
                      } on PlatformException {
                        print('Quick Trip Error');
                      } catch (error) {
                        print(error);
                      }
                    }),
                ElevatedButton(
                    child: const Text('Update Online Trip'),
                    onPressed: () async {
                      try {
                        print('update trip id: ' + tripId!);
                        RoamTrip updateTrip = RoamTrip(tripId: tripId);
                        updateTrip.isLocal = false;
                        updateTrip.description = "test description";
                        Roam.updateTrip(updateTrip, ({roamTripResponse}) {
                          String responseString =
                              jsonEncode(roamTripResponse?.toJson());
                          print('Update trip response: $responseString');
                          CustomLogger.writeLog(
                              'Update trip response: $responseString');
                          setState(() {
                            tripId = roamTripResponse?.tripDetails?.id;
                            response = 'Update trip response: $responseString';
                          });
                        }, ({error}) {
                          String errorString = jsonEncode(error?.toJson());
                          print('Error: $errorString');
                          CustomLogger.writeLog(errorString);
                          response = errorString;
                        });
                        _displayTripsInputDialog(context, "updateTrip");
                      } on PlatformException {
                        print('Update Trip Error');
                      }
                    }),
                ElevatedButton(
                    child: const Text('Update Offline Trip'),
                    onPressed: () async {
                      try {
                        print('update trip id: ' + tripId!);
                        RoamTrip updateTrip = RoamTrip(tripId: tripId);
                        updateTrip.isLocal = true;
                        updateTrip.description = "test description";
                        Roam.updateTrip(updateTrip, ({roamTripResponse}) {
                          String responseString =
                              jsonEncode(roamTripResponse?.toJson());
                          print('Update trip response: $responseString');
                          CustomLogger.writeLog(
                              'Update trip response: $responseString');
                          setState(() {
                            tripId = roamTripResponse?.tripDetails?.id;
                            response = 'Update trip response: $responseString';
                          });
                        }, ({error}) {
                          String errorString = jsonEncode(error?.toJson());
                          print('Error: $errorString');
                          CustomLogger.writeLog(errorString);
                          response = errorString;
                        });
                        _displayTripsInputDialog(context, "updateTrip");
                      } on PlatformException {
                        print('Update Trip Error');
                      }
                    }),
                ElevatedButton(
                    child: const Text('Pause Trip'),
                    onPressed: () async {
                      try {
                        Roam.pauseTrip(tripId!, ({roamTripResponse}) {
                          String responseString =
                              jsonEncode(roamTripResponse?.toJson());
                          print('Pause trip response: $responseString');
                          CustomLogger.writeLog(
                              'Pause trip response: $responseString');
                          setState(() {
                            tripId = roamTripResponse?.tripDetails?.id;
                            response = 'Pause trip response: $responseString';
                          });
                        }, ({error}) {
                          String errorString = jsonEncode(error?.toJson());
                          print('Error: $errorString');
                          setState(() {
                            response = errorString;
                          });
                          CustomLogger.writeLog(errorString);
                        });
                        _displayTripsInputDialog(context, "pauseTrip");
                      } on PlatformException {
                        print('Pause Trip Error');
                      }
                    }),
                ElevatedButton(
                    child: const Text('Resume Trip'),
                    onPressed: () async {
                      try {
                        Roam.resumeTrip(tripId!, ({roamTripResponse}) {
                          String responseString =
                              jsonEncode(roamTripResponse?.toJson());
                          print('Resume trip response: $responseString');
                          CustomLogger.writeLog(
                              'Resume trip response: $responseString');
                          setState(() {
                            response = 'Resume trip response: $responseString';
                            tripId = roamTripResponse?.tripDetails?.id;
                          });
                        }, ({error}) {
                          String errorString = jsonEncode(error?.toJson());
                          print('Error: $errorString');
                          setState(() {
                            response = errorString;
                          });
                          CustomLogger.writeLog(errorString);
                        });
                        _displayTripsInputDialog(context, "resumeTrip");
                      } on PlatformException {
                        print('Resume Trip Error');
                      }
                    }),
                ElevatedButton(
                    child: const Text('End Trip'),
                    onPressed: () async {
                      try {
                        Roam.endTrip(tripId!, false, ({roamTripResponse}) {
                          String responseString =
                              jsonEncode(roamTripResponse?.toJson());
                          print('End trip response: $responseString');
                          CustomLogger.writeLog(
                              'End trip response: $responseString');
                          setState(() {
                            tripId = roamTripResponse?.tripDetails?.id;
                            response = 'End trip response: $responseString';
                          });
                        }, ({error}) {
                          String errorString = jsonEncode(error?.toJson());
                          print('Error: $errorString');
                          CustomLogger.writeLog(errorString);
                          setState(() {
                            response = errorString;
                          });
                        });
                        _displayTripsInputDialog(context, "endTrip");
                      } on PlatformException {
                        print('End Trip Error');
                      }
                    }),
                ElevatedButton(
                    child: const Text('Sync Trip'),
                    onPressed: () async {
                      try {
                        Roam.syncTrip(tripId!, ({roamSyncTripResponse}) {
                          String responseString =
                              jsonEncode(roamSyncTripResponse?.toJson());
                          print('Sync trip response: $responseString');
                          CustomLogger.writeLog(
                              'Sync trip response: $responseString');
                          setState(() {
                            response = 'Sync trip response: $responseString';
                          });
                        }, ({error}) {
                          String errorString = jsonEncode(error?.toJson());
                          print('Error: $errorString');
                          CustomLogger.writeLog(errorString);
                          setState(() {
                            response = errorString;
                          });
                        });
                        _displayTripsInputDialog(context, "syncTrip");
                      } on PlatformException {
                        print('Sync Trip Error');
                      }
                    }),
                ElevatedButton(
                    child: const Text('Delete Trip'),
                    onPressed: () async {
                      try {
                        Roam.deleteTrip(tripId!, ({roamDeleteTripResponse}) {
                          String responseString =
                              jsonEncode(roamDeleteTripResponse?.toJson());
                          print('Delete trip response: $responseString}');
                          CustomLogger.writeLog(responseString);
                          setState(() {
                            tripId = roamDeleteTripResponse?.trip?.id;
                            response = 'Delete trip response: $responseString}';
                          });
                        }, ({error}) {
                          String errorString = jsonEncode(error?.toJson());
                          print('Error: $errorString');
                          CustomLogger.writeLog(errorString);
                          setState(() {
                            response = errorString;
                          });
                        });
                        _displayTripsInputDialog(context, "deleteTrip");
                      } on PlatformException {
                        print('Delete Trip Error');
                      }
                    }),
                ElevatedButton(
                    child: const Text('Get Active Trips'),
                    onPressed: () async {
                      try {
                        Roam.getActiveTrips(false, ({roamActiveTripResponse}) {
                          String responseString =
                              jsonEncode(roamActiveTripResponse?.toJson());
                          print('Get active trips response: $responseString}');
                          CustomLogger.writeLog(responseString);
                          setState(() {
                            response =
                                'Get active trips response: $responseString}';
                          });
                        }, ({error}) {
                          String errorString = jsonEncode(error?.toJson());
                          print('Error: $errorString');
                          CustomLogger.writeLog(errorString);
                          setState(() {
                            response = errorString;
                          });
                        });
                        //_displayTripsInputDialog(context, "getActiveTrips");
                      } on PlatformException {
                        print('Get Active Trips Error');
                      }
                    }),
                ElevatedButton(
                    child: const Text('Get Trip Summary'),
                    onPressed: () async {
                      setState(() {
                        response = "fetching trip summary..";
                      });
                      try {
                        Roam.getTripSummary(tripId!, ({roamTripResponse}) {
                          String responseString =
                              jsonEncode(roamTripResponse?.toJson());
                          print('trip summary response: $responseString');
                          CustomLogger.writeLog(
                              'trip summary response: $responseString');
                          setState(() {
                            tripId = roamTripResponse?.tripDetails?.id;
                            response = 'Trip summary response: $responseString';
                          });
                        }, ({error}) {
                          String errorString = jsonEncode(error?.toJson());
                          print('Error: $errorString');
                          CustomLogger.writeLog(errorString);
                          setState(() {
                            response = errorString;
                          });
                        });
                        _displayTripsInputDialog(context, "getTripSummary");
                      } on PlatformException {
                        print('Get Trip Summary Error');
                      }
                    }),
              ],
            ),
          ),
        ));
  }
}

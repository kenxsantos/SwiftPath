import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:roam_flutter/roam_flutter.dart';
import 'package:logger/logger.dart';

class MyUsersPage extends StatefulWidget {
  const MyUsersPage({super.key, required this.title});
  static const String routeName = "/MyUsersPage";
  final String title;

  @override
  _MyUsersPageState createState() => _MyUsersPageState();
}

class _MyUsersPageState extends State<MyUsersPage> {
  String myUser = "";
  String valueText = "";
  final TextEditingController _textFieldController = TextEditingController();

  var logger = Logger(
    printer: PrettyPrinter(),
  );

  Future<void> _displayTextInputDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter User Id'),
          content: TextField(
            onChanged: (value) {
              setState(() {
                valueText = value;
              });
            },
            controller: _textFieldController,
            decoration: const InputDecoration(hintText: "Enter User Id"),
          ),
          actions: <Widget>[
            TextButton(
              style: const ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(Colors.red),
              ),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                setState(() {
                  Navigator.pop(context);
                });
              },
            ),
            TextButton(
              style: const ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(Colors.green),
              ),
              child: const Text(
                'OK',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () async {
                setState(() {
                  myUser = "Fetching user data...";
                });
                try {
                  await Roam.getUser(
                    userId: valueText,
                    callBack: ({user}) {
                      setState(() {
                        myUser = user ?? "No user data found.";
                      });
                      logger.d(user);
                    },
                  );
                } catch (e) {
                  setState(() {
                    myUser = "Error fetching user data.";
                  });
                  logger.e('Error: $e');
                }
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
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
            SelectableText(
              '\nUser Details:\n$myUser\n',
              textAlign: TextAlign.center,
            ),
            ElevatedButton(
              child: const Text('Create User'),
              onPressed: () async {
                setState(() {
                  myUser = "Creating user...";
                });
                try {
                  await Roam.createUser(
                    description: 'Joe',
                    callBack: ({user}) {
                      setState(() {
                        myUser = user ?? "Failed to create user.";
                      });
                      logger.d(user);
                      Roam.offlineTracking(true);
                      Roam.allowMockLocation(allow: true);
                    },
                  );
                } catch (e) {
                  setState(() {
                    myUser = "Error creating user.";
                  });
                  logger.e('Error: $e');
                }
              },
            ),
            ElevatedButton(
              child: const Text('Get User'),
              onPressed: () async {
                _displayTextInputDialog(context);
              },
            ),
            ElevatedButton(
              child: const Text('Toggle Listener'),
              onPressed: () async {
                setState(() {
                  myUser = "Updating user listener status...";
                });
                try {
                  await Roam.toggleListener(
                    locations: true,
                    events: true,
                    callBack: ({user}) {
                      setState(() {
                        myUser = user ?? "Failed to toggle listener.";
                      });
                      logger.d(user);
                    },
                  );
                } catch (e) {
                  setState(() {
                    myUser = "Error toggling listener.";
                  });
                  logger.e('Error: $e');
                }
              },
            ),
            ElevatedButton(
              child: const Text('Toggle Events'),
              onPressed: () async {
                setState(() {
                  myUser = "Updating user events status...";
                });
                try {
                  await Roam.toggleEvents(
                    location: true,
                    geofence: true,
                    trips: true,
                    movingGeofence: true,
                    callBack: ({user}) {
                      setState(() {
                        myUser = user ?? "Failed to toggle events.";
                      });
                      logger.d(user);
                    },
                  );
                } catch (e) {
                  setState(() {
                    myUser = "Error toggling events.";
                  });
                  logger.e('Error: $e');
                }
              },
            ),
            ElevatedButton(
              child: const Text('Get Listener Status'),
              onPressed: () async {
                setState(() {
                  myUser = "Fetching user listener status...";
                });
                try {
                  await Roam.getListenerStatus(
                    callBack: ({user}) {
                      setState(() {
                        myUser = user ?? "Failed to get listener status.";
                      });
                      logger.d(user);
                    },
                  );
                } catch (e) {
                  setState(() {
                    myUser = "Error getting listener status.";
                  });
                  logger.e('Error: $e');
                }
              },
            ),
            ElevatedButton(
              child: const Text('Subscribe Location'),
              onPressed: () async {
                setState(() {
                  myUser = "Subscribing to user location...";
                });
                try {
                  await Roam.subscribeLocation();
                  setState(() {
                    myUser = "User location subscribed.";
                  });
                } on PlatformException {
                  logger.e('Subscribe Location Error');
                  setState(() {
                    myUser = "Error subscribing to location.";
                  });
                }
              },
            ),
            ElevatedButton(
              child: const Text('Subscribe User Location'),
              onPressed: () async {
                setState(() {
                  myUser = "Subscribing to user location...";
                });
                try {
                  await Roam.subscribeUserLocation(
                      userId: '673b720f05d68d149c1cfb8f');
                  setState(() {
                    myUser = "User location subscribed.";
                  });
                } on PlatformException {
                  logger.e('Subscribe User Location Error');
                  setState(() {
                    myUser = "Error subscribing to user location.";
                  });
                }
              },
            ),
            ElevatedButton(
              child: const Text('Subscribe Events'),
              onPressed: () async {
                setState(() {
                  myUser = "Subscribing to user events...";
                });
                try {
                  await Roam.subscribeEvents();
                  setState(() {
                    myUser = "User events subscribed.";
                  });
                } on PlatformException {
                  logger.e('Subscribe Events Error');
                  setState(() {
                    myUser = "Error subscribing to events.";
                  });
                }
              },
            ),
            ElevatedButton(
              child: const Text('Logout User'),
              onPressed: () async {
                try {
                  await Roam.logoutUser();
                } catch (e) {
                  logger.e('Error logging out: $e');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

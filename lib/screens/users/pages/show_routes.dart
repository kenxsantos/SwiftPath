import 'dart:async';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_flutter/roam_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:swiftpath/components/location_tracking.dart';
import 'package:swiftpath/screens/admin/pages/barangay_maps.dart';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';
import 'package:flutter_html/flutter_html.dart' as flutter_html;
import 'package:http/http.dart' as http;

class ShowRoutes extends ConsumerStatefulWidget {
  final Map<String, dynamic> destination;
  final Map<String, dynamic> origin;
  final String geofenceId;

  const ShowRoutes({
    super.key,
    required this.geofenceId,
    required this.destination,
    required this.origin,
  });

  @override
  _ShowRoutesState createState() => _ShowRoutesState();
}

class _ShowRoutesState extends ConsumerState<ShowRoutes> {
  final LocationTracker _locationTracker = LocationTracker();
  LatLng? _currentLocation;

  final String googleMapKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  final Completer<GoogleMapController> _controller = Completer();
  final LocationSettings locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 100,
  );
  bool showAutoCompleteSearchBar = true;

  var radiusValue = 3000.0;
  bool getDirections = false;
  var uuid = const Uuid();
  var logger = Logger(
    printer: PrettyPrinter(),
  );

  late LatLng destination;
  late LatLng origin;

  List<LatLng> polylineCoordinates = [];
  late StreamSubscription<Position> positionStream;
  BitmapDescriptor originIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor destinationIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor userIcon = BitmapDescriptor.defaultMarker;

  bool _isLoading = false;
  List<Map<String, dynamic>> routes = [];
  String myUserId = "emergency-vehicle-1";
  late IO.Socket _socket;
  LatLng _currentPosition = const LatLng(0, 0);
  Set<Polyline> polylines = <Polyline>{};
  @override
  void initState() {
    super.initState();
    _locationTracker.listenToLocationUpdates("testing", (LatLng location) {
      setState(() {
        _currentLocation = location;
      });
    });
    _getCurrentPosition();
    setCustomMarkerIcon();
    _connectSocket();
    destination = LatLng(
      widget.destination['lat'],
      widget.destination['lng'],
    );
    origin = LatLng(
      widget.origin['lat'],
      widget.origin['lng'],
    );
    // requestRoutesToServer(origin, destination);
    // createUser();
  }

  void createUser() async {
    // await Roam.createUser(
    //   description: "emergency_vehicle",
    //   callBack: ({user}) {
    //     setState(() {
    //       final userData = jsonDecode(user!);
    //       myUserId = userData["userId"];
    //     });
    //   },
    // );

    // await _createMovingGeofence(myUserId ?? 'No User ID');
    // Push incident report data to Firebase
    await Roam.getListenerStatus(
      callBack: ({user}) {
        setState(() {
          final userData = jsonDecode(user!);
          myUserId = userData["userId"];
        });
      },
    );
    await Roam.startTracking(trackingMode: "active");
  }

  Future<void> _createMovingGeofence(String userId) async {
    final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
    final String roamAiApiKey =
        dotenv.env['ROAM_AI_API_KEY'] ?? ''; // Roam API key

    // Geofence data to be sent to the Roam AI API
    final Map<String, dynamic> geofenceData = {
      "geometry_type": "circle",
      "geometry_radius": 500,
      "color_code": "FF0000",
      "is_enabled": true,
      "only_once": true,
      "users": [
        userId,
        "674489ffacae092dfe16fa86",
      ]
    };

    // Send a request to the Roam AI API
    try {
      final response = await http.post(
        Uri.parse('https://api.roam.ai/v1/api/moving-geofence/'),
        headers: {
          'Api-Key': roamAiApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(geofenceData),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> responseData =
            jsonDecode(response.body)['data'];

        // Store geofence data in Firebase
        final Map<String, dynamic> firebaseGeofenceData = {
          'latitude': _currentPosition.latitude,
          'longitude': _currentPosition.longitude,
          "geofence_id": responseData["id"],
          "account_id": responseData["account_id"],
          "project_id": responseData["project_id"],
          "geometry_type": responseData["geometry_type"],
          "geometry_radius": responseData["geometry_radius"],
          "is_enabled": responseData["is_enabled"],
          "is_deleted": responseData["is_deleted"],
          "only_once": responseData["only_once"],
          "users": responseData["users"],
          "created_at": responseData["created_at"],
          "updated_at": responseData["updated_at"],
        };

        await dbRef.child('moving-geofences').push().set(firebaseGeofenceData);
        logger.i('Moving geofence created and data stored successfully.');
        ('Success', 'Geofence created successfully.');
      } else {
        logger.e('Error creating moving geofence: ${response.body}');
        _showDialog('Error', 'Failed to create geofence.');
      }
    } catch (e) {
      logger.e('Error creating moving geofence: $e');
      _showDialog('Error', 'An error occurred while creating the geofence.');
    }
  }

  void _showDialog(String title, String message) {
    logger.i('$title: $message');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (arguments != null) {
      setState(() {
        destination = LatLng(
          arguments['lat'],
          arguments['lng'],
        );
        origin = LatLng(
          arguments['origin']['lat'],
          arguments['origin']['lng'],
        );
      });
    }
  }

  void requestRoutesToServer(LatLng origin, LatLng destination) async {
    final String backendUrl = dotenv.env['SOCKET_URL'] ?? '';
    try {
      final Map<String, dynamic> payload = {
        "destination": {
          "lat": destination.latitude,
          "lng": destination.longitude
        },
        "origin": {"lat": origin.latitude, "lng": origin.longitude}
      };
      final response = await http.post(
        Uri.parse('$backendUrl/current-location'),
        headers: {
          "Content-Type": "application/json",
        },
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        print("Location sent successfully. $payload");
        print("Response: ${response.body}");
      } else {
        print("Failed to send destination: ${response.body}");
      }
    } catch (e) {
      print("Error sending destination: $e");
    }
  }

  void dispose() {
    // Cancel the position stream to avoid memory leaks
    positionStream.cancel();
    super.dispose();
  }

  void _connectSocket() {
    String socketUrl = "https://bd17-120-29-76-216.ngrok-free.app";
    print("Connecting to Socket.IO server: $socketUrl");
    _socket = IO.io(
      socketUrl,
      IO.OptionBuilder()
          .setPath('/webhook')
          .setTransports(['websocket']) // Use WebSocket transport
          .disableAutoConnect() // Disable auto-connect for manual connection
          .build(),
    );
    _socket.connect();
    _socket.on('location_update', (data) async {
      print('Location Update: $data');
      if (data is Map<String, dynamic>) {
        final coordinates = data['coordinates']['coordinates'];
        setState(() {
          _currentPosition = LatLng(coordinates[1], coordinates[0]);
        });
      }
      _moveCameraToCurrentPosition();
    });

    _socket.on("alternative_routes", (data) {
      print("Received data: $data");

      if (data is Map<String, dynamic> && data['routes'] is List) {
        final List<dynamic> receivedRoutes = data['routes'];

        print("Received data: $receivedRoutes");
        setState(() {
          routes = receivedRoutes.map((route) {
            return {
              'summary': route['summary'],
              'distance': route['distance'],
              'duration': route['duration'],
              'start_address': route['start_address'],
              'end_address': route['end_address'],
              'overview_polyline': route['overview_polyline'],
              'steps': route['steps'] ?? [],
            };
          }).toList();
        });

        if (routes.isNotEmpty) {
          String routesPolyline = routes[0]['overview_polyline'];
          List<LatLng> poly = decodePolyline(routesPolyline);
          setState(() {
            polylines.clear();
            polylines.add(Polyline(
              polylineId: const PolylineId('initial_route_polyline'),
              points: poly,
              color: Colors.blue, // Customize polyline color
              width: 5,
            ));
          });
          print("First overview_polyline: ${routes[0]['overview_polyline']}");
        } else {
          print("No routes found.");
        }
      } else {
        print("Invalid data format received: $data");
      }
    });

    _socket.onConnect((_) {
      setState(() {
        _isLoading = false;
      });
    });
  }

  Future<void> _updateFirebaseLocation(
      double latitude, double longitude) async {
    try {
      // Assuming each vehicle has a unique ID, e.g., "vehicle123"
      final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
      await dbRef.child('emergency-vehicles/$myUserId').set({
        'latitude': latitude,
        'longitude': longitude,
        'status': 'active',
      });

      print("Firebase location updated: $latitude, $longitude");
    } catch (error) {
      print("Failed to update Firebase: $error");
    }
  }

  Future<void> _moveCameraToCurrentPosition() async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _currentPosition, zoom: 15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              Stack(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height,
                    width: MediaQuery.of(context).size.width,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(origin.latitude, origin.longitude),
                        zoom: 15.0,
                      ),
                      mapType: MapType.normal,
                      myLocationEnabled: true,
                      onMapCreated: (controller) =>
                          _controller.complete(controller),
                      markers: {
                        Marker(
                          markerId: const MarkerId('origin'),
                          position: LatLng(origin.latitude, origin.longitude),
                          icon: originIcon,
                        ),
                        Marker(
                          markerId: const MarkerId('destination'),
                          position: destination,
                          icon: destinationIcon,
                        ),
                      },
                      polylines: polylines,
                    ),
                  ),
                  Positioned(
                    bottom: 130.0,
                    right: 10,
                    child: routes.isEmpty
                        ? Container()
                        : SizedBox(
                            height: 60.0, // Increase height
                            width: 60.0, // Increase width
                            child: FloatingActionButton(
                              backgroundColor: Colors.red.shade400,
                              shape: const CircleBorder(),
                              onPressed: showRoutesPopup,
                              child: const Icon(
                                Icons.route,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),
                  Positioned(
                    bottom: 20,
                    height: 50,
                    left: 20,
                    width: MediaQuery.of(context).size.width * 0.9,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.red.shade400, // Background color
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(10), // Rounded corners
                        ),
                      ),
                      onPressed: () => _showConfirmationDialog(
                          context), // Show confirmation dialog
                      child: const Text(
                        'Mark as Resolved',
                        style: TextStyle(
                          fontSize: 16, // Adjust font size
                          color: Colors.white, // Text color
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void setCustomMarkerIcon() {
    BitmapDescriptor.asset(const ImageConfiguration(size: Size(48, 48)),
            'assets/images/icons/emergency_icon.png')
        .then((icon) {
      originIcon = icon;
    });
    BitmapDescriptor.asset(const ImageConfiguration(size: Size(48, 48)),
            'assets/images/icons/destination_icon.png')
        .then((icon) {
      destinationIcon = icon;
    });
    BitmapDescriptor.asset(const ImageConfiguration(size: Size(48, 48)),
            'assets/images/icons/user_icon.png')
        .then((icon) {
      userIcon = icon;
    });
  }

  Future<void> _getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Show error to user
      return Future.error(
          'Location services are disabled. Please enable them.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied. Please enable them in settings.');
    }
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });

      requestRoutesToServer(
        LatLng(position.latitude, position.longitude),
        LatLng(destination.latitude, destination.longitude),
      );

      _controller.future.then((GoogleMapController controller) {
        controller.animateCamera(
          CameraUpdate.newLatLngZoom(_currentPosition, 15),
        );
      }).catchError((error) {
        print('Error updating map camera: $error');
      });
    });
  }

  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Action"),
          content: const Text("Are you sure you want to take this action?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400, // Confirm button color
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                actionTakenSuccessfully(); // Call the action method
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  void actionTakenSuccessfully() async {
    final DatabaseReference dbRef =
        FirebaseDatabase.instance.ref("incident-reports");

    String geofenceId = widget.geofenceId;
    try {
      // Query the database to find reports with the specific geofenceId
      final DatabaseEvent event =
          await dbRef.orderByChild('geofence_id').equalTo(geofenceId).once();

      if (event.snapshot.value != null) {
        // Get all matching reports
        final Map<String, dynamic> reports =
            Map<String, dynamic>.from(event.snapshot.value as Map);

        // Update the status of each matching report to 'Done'
        for (final reportKey in reports.keys) {
          await dbRef.child(reportKey).update({'status': 'Done'});
        }

        // Show a success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Action taken successfully!'),
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate to BarangayMaps
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BarangayMaps()),
        );
      } else {
        // No reports found
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No matching reports found.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      // Show an error message if the update fails
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $error'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0, result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      polyline.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return polyline;
  }

  void showRoutesPopup() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Available Routes",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                // Use Expanded for ListView in a Dialog
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: routes.length,
                    itemBuilder: (context, index) {
                      final route = routes[index];
                      return Card(
                        margin: const EdgeInsets.all(5.0),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0)),
                        elevation: 6.0,
                        child: ExpansionTile(
                          title: Text(
                            route['summary'] ?? 'No summary available',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Distance: ${route['distance'] ?? 'N/A'}, Duration: ${route['duration'] ?? 'N/A'}',
                          ),
                          children: [
                            ListTile(
                              onTap: () => setAlterativeRoutesPolyline(
                                  routes[index]['overview_polyline']),
                              title: const Text(
                                'Follow Route',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            ListTile(
                              title: Text(
                                'Start: ${route['start_address']}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            ListTile(
                              title: Text(
                                'Destination: ${route['end_address']}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            const Divider(),
                            ...route['steps'].map<Widget>((step) {
                              return Column(
                                children: [
                                  ListTile(
                                    title: flutter_html.Html(
                                      data: step['instruction'] ??
                                          'No instruction',
                                    ),
                                    subtitle: Text(
                                      '  Distance: ${step['distance']}, Duration: ${step['duration']}',
                                    ),
                                  ),
                                  const Divider(),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text("Close"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void setAlterativeRoutesPolyline(String overviewPolyline) {
    print(overviewPolyline);
    final decodedPolyline = decodePolyline(overviewPolyline);
    setState(() {
      polylines.clear();
      polylines.add(Polyline(
        polylineId: const PolylineId('alternative_route_polyline'),
        points: decodedPolyline,
        color: Colors.blue,
        width: 5,
      ));
    });
    Navigator.of(context).pop();
  }
}

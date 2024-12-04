import 'dart:async';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:roam_flutter/roam_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:swiftpath/components/routes.dart';
import 'package:swiftpath/screens/admin/pages/barangay_maps.dart';
import 'package:swiftpath/services/google_directions_service.dart';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';
import 'package:flutter_html/flutter_html.dart' as flutter_html;
import 'package:http/http.dart' as http;
import 'package:toastification/toastification.dart';

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
  LatLng? _currentLocation;

  final Completer<GoogleMapController> _controller = Completer();
  final LocationSettings locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 100,
  );
  bool showAutoCompleteSearchBar = true;
  final String googleMapsApiKey =
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? 'API Key not found';
  String socketUrl = dotenv.env['SOCKET_URL'] ?? 'Socket URL not found';
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
  final GoogleDirectionsService directionsService =
      GoogleDirectionsService('AIzaSyC2cU6RHwIR6JskX2GHe-Pwv1VepIHkLCg');

  bool _isLoading = false;
  List<Map<String, dynamic>> routes = [];
  String? myUserId;
  late IO.Socket _socket;
  LatLng _currentPosition = const LatLng(0, 0);
  Set<Polyline> polylines = <Polyline>{};
  bool is_tracking = false;
  bool is_active = true;
  @override
  void initState() {
    super.initState();
    _getCurrentPosition();
    setCustomMarkerIcon();

    destination = LatLng(
      widget.destination['lat'],
      widget.destination['lng'],
    );
    origin = LatLng(
      widget.origin['lat'],
      widget.origin['lng'],
    );
    _fetchAndDisplayRoutes();
    _refreshUserTracking();
  }

  Future<void> _createMovingGeofence(String userId) async {
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
      await http.post(
        Uri.parse('https://api.roam.ai/v1/api/moving-geofence/'),
        headers: {
          'Api-Key': roamAiApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(geofenceData),
      );
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

  Future<void> _fetchAndDisplayRoutes() async {
    try {
      final fetchedRoutes = await directionsService.fetchRoutes(
        origin: origin,
        destination: destination,
      );
      logger.i('Fetched routes: $fetchedRoutes');

      if (fetchedRoutes.isNotEmpty) {
        setState(() {
          routes = fetchedRoutes.map<Map<String, dynamic>>((route) {
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

          // Add the first route's polyline to the map as default
          final polylinePoints = directionsService.decodePolyline(
            fetchedRoutes[0]['overview_polyline'],
          );
          polylines.add(Polyline(
            polylineId: const PolylineId('default_route_polyline'),
            points: polylinePoints,
            color: Colors.blue,
            width: 5,
          ));
        });
      }
    } catch (e) {
      print('Error fetching routes: $e');
    }
  }

  void dispose() {
    positionStream.cancel();
    super.dispose();
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
                    child: SizedBox(
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
                        backgroundColor: is_active
                            ? Colors.red.shade400
                            : Colors.white, // Background color
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(10), // Rounded corners
                        ),
                      ),
                      onPressed: () {
                        if (is_active) {
                          _showConfirmationDialog(context);
                        } else {
                          actionTakenSuccessfully();
                        }
                      },
                      child: Text(
                        is_active ? 'Start Trip' : 'End Trip',
                        style: TextStyle(
                          fontSize: 16, // Adjust font size
                          color: is_active
                              ? Colors.white
                              : Colors.red.shade400, // Text color
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
      createTrackingLocation();
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
      builder: (_) => AlertDialog(
        title: const Text("You are about to start the trip."),
        content: const Text("Are you sure you want to take this action?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              createTrackingLocation();
              setState(() {
                is_active = false;
                toastification.show(
                  type: ToastificationType.success,
                  style: ToastificationStyle.fillColored,
                  context: context,
                  description: RichText(
                      text: TextSpan(
                    text: 'Trip started successfully',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  )),
                  icon: const Icon(Icons.check),
                  autoCloseDuration: const Duration(seconds: 3),
                );
              });
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  Future<void> createTrackingLocation() async {
    try {
      if (myUserId == null) {
        await _initializeUserTracking();
      } else {
        await _refreshUserTracking();
      }
      await _createMovingGeofence(myUserId!);

      final payload = {
        "userId": myUserId,
        "origin": {
          "lat": _currentPosition.latitude,
          "lng": _currentPosition.longitude,
        },
        "is_tracking": is_tracking,
      };

      // Reference to Firebase Realtime Database
      final databaseReference =
          FirebaseDatabase.instance.ref("emergency-vehicle-location");

      // Check if user exists in the database
      final userRef = databaseReference.child(myUserId!);
      final snapshot = await userRef.get();

      if (snapshot.exists) {
        // User exists, update their location
        await userRef.update({
          'origin': payload['origin'],
          'is_tracking': payload['is_tracking'],
        });
        print("Location updated successfully for userId: $myUserId");
      } else {
        // User does not exist, create a new entry
        await userRef.set(payload);
        print("New location added successfully for userId: $myUserId");
      }
    } catch (e) {
      print("Error creating tracking location: $e");
    }
  }

  Future<void> _initializeUserTracking() async {
    await Roam.createUser(
        description: "emergency_vehicle",
        callBack: ({user}) {
          setState(() {
            myUserId = jsonDecode(user!)["userId"];
          });
        });
    Roam.startTracking(trackingMode: "active");
    setState(() => is_tracking = true);
  }

  Future<void> _refreshUserTracking() async {
    await Roam.getListenerStatus(callBack: ({user}) {
      setState(() {
        myUserId = jsonDecode(user!)["userId"];
      });
    });
    setState(() => is_tracking = true);
  }

  Future<void> actionTakenSuccessfully() async {
    final DatabaseReference reportsDbRef =
        FirebaseDatabase.instance.ref("incident-reports");
    final DatabaseReference vehiclesDbRef =
        FirebaseDatabase.instance.ref("emergency-vehicle-location");

    String geofenceId = widget.geofenceId;

    try {
      // Fetch reports for the given geofence ID
      final event = await reportsDbRef
          .orderByChild('geofence_id')
          .equalTo(geofenceId)
          .once();

      if (event.snapshot.value != null) {
        print('Reports found: ${event.snapshot.value}');
        final reports = Map<String, dynamic>.from(event.snapshot.value as Map);

        // Update the status of all reports
        for (final reportKey in reports.keys) {
          await reportsDbRef.child(reportKey).update({'status': 'Done'});
        }

        // Update emergency vehicle status to `is_tracking: false`
        final vehiclesSnapshot = await vehiclesDbRef.once();
        if (vehiclesSnapshot.snapshot.exists) {
          final vehicles =
              Map<String, dynamic>.from(vehiclesSnapshot.snapshot.value as Map);

          for (final vehicleKey in vehicles.keys) {
            final vehicleData = vehicles[vehicleKey];
            if (vehicleData['userId'] == myUserId) {
              // Match vehicle by userId
              await vehiclesDbRef
                  .child(vehicleKey)
                  .update({'is_tracking': false});
              print('Updated vehicle tracking status to false for $vehicleKey');
            }
          }
        }

        if (!mounted) return; // Ensure widget is still mounted
        print('Navigating to BarangayMaps...');
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BarangayMaps()),
        );
        toastification.show(
          type: ToastificationType.error,
          style: ToastificationStyle.fillColored,
          context: context,
          description: RichText(
              text: TextSpan(
            text: 'Trip ended successfully',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          )),
          icon: const Icon(Icons.error),
          autoCloseDuration: const Duration(seconds: 3),
        );
        try {
          await Roam.stopTracking();
        } catch (error) {
          toastification.show(
            type: ToastificationType.error,
            style: ToastificationStyle.fillColored,
            context: context,
            description: RichText(
                text: TextSpan(
              text: 'Failed to stop tracking',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            )),
            icon: const Icon(Icons.error),
            autoCloseDuration: const Duration(seconds: 3),
          );
        }
      } else {
        print('No matching reports found.');
        _showSnackBar(context, 'No matching reports found.');
      }
    } catch (error) {
      print('Failed to update status: $error');
      _showSnackBar(context, 'Failed to update status: $error');
    }
  }

// Helper to show snackbar
  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void showRoutesPopup() {
    if (routes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No routes available to display')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return RoutesPopup(
          routes: routes, // Pass the fetched routes
          onRouteSelected: (polyline) {
            // Update the map with the selected route's polyline
            setState(() {
              polylines.clear(); // Clear existing polylines
              final polylinePoints = directionsService.decodePolyline(polyline);
              polylines.add(Polyline(
                polylineId: const PolylineId('selected_route_polyline'),
                points: polylinePoints,
                color: Colors.green,
                width: 5,
              ));
            });
          },
        );
      },
    );
  }
}

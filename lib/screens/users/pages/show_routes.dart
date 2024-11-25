import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:swiftpath/screens/admin/pages/barangay_maps.dart';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';

class ShowRoutes extends ConsumerStatefulWidget {
  final Map<String, dynamic> incidentReport;
  final String geofenceId;

  const ShowRoutes({
    super.key,
    required this.geofenceId,
    required this.incidentReport,
  });

  @override
  _ShowRoutesState createState() => _ShowRoutesState();
}

class _ShowRoutesState extends ConsumerState<ShowRoutes> {
  final String googleMapKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  final Completer<GoogleMapController> _controller = Completer();
  final LocationSettings locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 100,
  );
  bool showAutoCompleteSearchBar = true;

  final Set<Polyline> _polylines = <Polyline>{};
  var radiusValue = 3000.0;
  bool getDirections = false;
  var uuid = const Uuid();
  var logger = Logger(
    printer: PrettyPrinter(),
  );

  late LatLng incidentReport;

  List<LatLng> polylineCoordinates = [];
  late StreamSubscription<Position> positionStream;
  BitmapDescriptor originIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor destinationIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor userIcon = BitmapDescriptor.defaultMarker;
  Position? currentLocation;
  late LatLng incidentLocation;
  @override
  void initState() {
    super.initState();
    getCurrentUserLocation();
    setCustomMarkerIcon();

    incidentLocation = LatLng(
      widget.incidentReport['latitude'],
      widget.incidentReport['longitude'],
    );
    getCurrentLocationAndTrackMovement();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (arguments != null) {
      setState(() {
        incidentLocation = LatLng(
          arguments['incident_report']['latitude'],
          arguments['incident_report']['longitude'],
        );
      });
    }
  }

  void dispose() {
    // Cancel the position stream to avoid memory leaks
    positionStream.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: currentLocation == null
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
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
                              target: LatLng(currentLocation!.latitude,
                                  currentLocation!.longitude),
                            ),
                            mapType: MapType.normal,
                            onMapCreated: (controller) =>
                                _controller.complete(controller),
                            markers: {
                              Marker(
                                markerId: const MarkerId('origin'),
                                position: LatLng(currentLocation!.latitude,
                                    currentLocation!.longitude),
                                icon: originIcon,
                              ),
                              Marker(
                                markerId: const MarkerId('destination'),
                                position: incidentLocation,
                                icon: destinationIcon,
                              ),
                            },
                            polylines: _polylines,
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
                                borderRadius: BorderRadius.circular(
                                    10), // Rounded corners
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

  Future<Position> getCurrentUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
    Position position =
        await Geolocator.getCurrentPosition(locationSettings: locationSettings);

    setState(() {
      currentLocation = position;
    });

    // Initialize the GoogleMapController and set initial camera position
    GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
        ),
      ),
    );
    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high, // Set accuracy as per your needs
        distanceFilter: 1, // Update every 10 meters; adjust as needed
      ),
    ).listen((Position? position) {
      if (position != null) {
        setState(() {
          currentLocation = position;
        });

        // Animate the camera to the new position
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
                target: LatLng(position.latitude, position.longitude),
                zoom: 15),
          ),
        );

        print(
            'User position updated: ${position.latitude}, ${position.longitude}');
      }
    });

    return position;
  }

  void getCurrentLocationAndTrackMovement() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    // Get the initial position
    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      currentLocation = position;
    });

    // Initialize the polyline to the incident location
    _getPolylinesPoints(
      LatLng(position.latitude, position.longitude),
      incidentLocation,
    );

    // Start listening for position changes to update polylines in real-time
    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      setState(() {
        currentLocation = position;
      });

      // Update the polyline each time the user moves
      _getPolylinesPoints(
        LatLng(position.latitude, position.longitude),
        incidentLocation,
      );
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

  void _getPolylinesPoints(LatLng startLocation, LatLng endLocation) async {
    PolylinePoints polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey: googleMapKey,
      request: PolylineRequest(
        origin: PointLatLng(startLocation.latitude, startLocation.longitude),
        destination: PointLatLng(endLocation.latitude, endLocation.longitude),
        mode: TravelMode.driving,
      ),
    );
    if (result.points.isNotEmpty) {
      polylineCoordinates.clear(); // Clear any previous data
      for (PointLatLng point in result.points) {
        LatLng latLngPoint = LatLng(point.latitude, point.longitude);
        polylineCoordinates.add(latLngPoint);
      }
      print("Polyline Coordinates: $polylineCoordinates"); // Debugging

      setState(() {
        _polylines.add(Polyline(
          polylineId: const PolylineId('polyline'),
          color: Colors.blue,
          width: 5,
          points: polylineCoordinates,
        ));
      });
    } else {
      logger.e("No points found in polyline result.");
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:swiftpath/components/autocomplete_list.dart';
import 'package:swiftpath/components/searchBar.dart';
import 'package:http/http.dart' as http;
import 'package:swiftpath/services/map_services.dart';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';

class ShowRoutes extends ConsumerStatefulWidget {
  const ShowRoutes({
    super.key,
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

  final Set<Marker> _markersForDestination = <Marker>{};
  final Set<Marker> _markersForEmergency = <Marker>{};
  // Set<Marker> get allMarkers =>
  //     _markersForDestination.union(_markersForEmergency);
  final Set<Polyline> _polylines = <Polyline>{};
  final Set<Circle> _circles = <Circle>{};
  int _markerIdCounter = 1;
  int _markerIdCounterForEmergecy = 1;
  int _polylineIdCounter = 1;
  double _radiusValue = 3000.0;
  LatLng? _tappedPoint;

  final ValueNotifier<String> _searchAutoCompleteAddr =
      ValueNotifier<String>('');
  final TextEditingController _searchEditingController =
      TextEditingController();
  final TextEditingController _autoCompleteSearchEditingController =
      TextEditingController();
  Timer? _debounce;
  var radiusValue = 3000.0;
  bool getDirections = false;
  var uuid = const Uuid();
  String _sessionToken = '122344';
  var logger = Logger(
    printer: PrettyPrinter(),
  );

  static const sourceLocation = LatLng(14.5977431, 120.982392);
  static const destinationLocation = LatLng(14.590256, 120.9811942);
  List<LatLng> polylineCoordinates = [];
  Position? currentLocation;

  BitmapDescriptor originIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor destinationIcon = BitmapDescriptor.defaultMarker;
  BitmapDescriptor userIcon = BitmapDescriptor.defaultMarker;

  @override
  void initState() {
    super.initState();
    _getPolylinesPoints();
    getCurrentUserLocation();
    setCustomMarkerIcon();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Retrieve arguments passed via the navigator
      final route = ModalRoute.of(context);
      if (route != null && route.settings.arguments != null) {
        final arguments = route.settings.arguments as Map<String, dynamic>;

        // Check if the 'setPolyline' argument exists before calling _addPolyline
        if (arguments.containsKey('setPolyline')) {
          final polylinePoints = arguments['setPolyline'];
          if (polylinePoints != null && polylinePoints is List<PointLatLng>) {
            _addPolyline(polylinePoints);
            final startPoint = LatLng(
                polylinePoints.first.latitude, polylinePoints.first.longitude);
            _addMarker(startPoint, info: 'Start Location');
            final endPoint = LatLng(
                polylinePoints.last.latitude, polylinePoints.last.longitude);
            _addMarker(endPoint, info: 'End Location');
          }
        }
      }
    });
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
                              zoom: 13.5,
                            ),
                            mapType: MapType.normal,
                            onMapCreated: (controller) =>
                                _controller.complete(controller),
                            markers: {
                              Marker(
                                markerId: const MarkerId('origin'),
                                position: sourceLocation,
                                icon: originIcon,
                              ),
                              Marker(
                                markerId: const MarkerId('user'),
                                position: LatLng(currentLocation!.latitude,
                                    currentLocation!.longitude),
                                icon: userIcon,
                              ),
                              Marker(
                                markerId: const MarkerId('destination'),
                                position: destinationLocation,
                                icon: destinationIcon,
                              ),
                            },
                            polylines: {
                              Polyline(
                                polylineId: const PolylineId('polyline'),
                                color: Colors.blue,
                                width: 5,
                                points: polylineCoordinates,
                              ),
                            },
                            // circles: _circles,
                            // onCameraMove: (position) =>
                            //     _currentCameraPosition = position,
                            // onTap: (point) {
                            //   _tappedPoint = point;
                            //     _addMarker(point);
                            //   _setCircle(point);
                            // },
                          ),
                        ),
                        autoCompleteSearchBar(),
                        ValueListenableBuilder(
                          valueListenable: _searchAutoCompleteAddr,
                          builder: (context, value, _) {
                            return showAutoCompleteSearchBar &&
                                    _searchAutoCompleteAddr.value.isNotEmpty
                                ? showAutoCompleteList()
                                : Container();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

      // floatingActionButton: FloatingActionButton(
      //   onPressed: _recenterMap,
      //   tooltip: 'Recenter',
      //   child: const Icon(Icons.my_location),
      // ),
    );
  }

  Positioned autoCompleteSearchBar() {
    return Positioned(
      top: 40.0,
      right: 15.0,
      left: 15.0,
      child: SearchAutoComplete(
        searchAutocompleteAddr: _searchAutoCompleteAddr,
        searchEditingController: _searchEditingController,
        controllerFuture: () => _controller.future,
        searchAndNavigate: (controller, value, {zoom = 14}) =>
            searchAndNavigate(controller, value, zoom: 14),
        debounce: _debounce,
      ),
    );
  }

  Positioned showAutoCompleteList() {
    return Positioned(
      top: 110,
      right: 15,
      left: 15,
      child: AutoCompleteList(
        searchValueNotifier: _searchAutoCompleteAddr,
        searchEditingController: _autoCompleteSearchEditingController,
        onSearchChange: (value) => onChange(value),
        controllerFuture: () => _controller.future,
        searchAndNavigate: (controller, value, {zoom = 14}) =>
            searchAndNavigate(controller, value, zoom: 14),
      ),
    );
  }

  onChange(String inputvalue) {
    if (_sessionToken.isEmpty) {
      _sessionToken = uuid.v4();
    }
    return getSuggestion(inputvalue);
  }

  getSuggestion(String input) async {
    String baseURL =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json';
    String request =
        '$baseURL?input=$input&key=$googleMapKey&sessiontoken=$_sessionToken';
    var response = await http.get(Uri.parse(request));
    var body = response.body.toString();
    developer.log(body);
    if (response.statusCode == 200) {
      var placesdata = await jsonDecode(body);
      return placesdata;
    } else {
      throw Exception('Error loading autocomplete Data');
    }
  }

  searchAndNavigate(GoogleMapController mapController, String inputvalue,
      {int? zoom}) async {
    await locationFromAddress(inputvalue).then(
      (result) => {
        developer.log(result.toString()),
        mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
                target: LatLng(result.last.latitude, result.last.longitude),
                zoom: zoom!.toDouble() < 13 ? 13 : zoom.toDouble()),
          ),
        ),
        _addMarker(LatLng(result.last.latitude, result.last.longitude),
            info: inputvalue),
      },
    );
  }

  void _addMarker(LatLng point, {String? info}) {
    final markerId = 'marker_${_markerIdCounter++}';
    final marker = Marker(
      markerId: MarkerId(markerId),
      position: point,
      icon: BitmapDescriptor.defaultMarker,
      onTap: () {
        showModalBottomSheet(
          context: context,
          builder: (BuildContext context) {
            return Container(
              padding: const EdgeInsets.all(20.0),
              width: double.infinity,
              height: 200,
              child: Column(
                children: [
                  Text(info ?? 'No Info',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () async {
                      logger.i(info);
                      Position position = await getCurrentUserLocation();
                      var address = await _getAddressFromLatLng(
                          position.latitude, position.longitude);
                      var directions =
                          await MapServices().getDirections(address, info!);
                      gotoPlace(
                          directions['start_location']['lat'],
                          directions['start_location']['lng'],
                          directions['end_location']['lat'],
                          directions['end_location']['lng'],
                          directions['bounds_ne'],
                          directions['bounds_sw']);
                      _addPolyline(directions['polyline_decoded']);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Get Directions'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    setState(() {
      _markersForDestination.add(marker);
    });
  }

  void setCustomMarkerIcon() {
    BitmapDescriptor.asset(const ImageConfiguration(size: Size(48, 48)),
            'assets/images/emergency_car_icon.png')
        .then((icon) {
      originIcon = icon;
    });
    BitmapDescriptor.asset(const ImageConfiguration(size: Size(48, 48)),
            'assets/images/emergency_car_icon.png')
        .then((icon) {
      destinationIcon = icon;
    });
    BitmapDescriptor.asset(const ImageConfiguration(size: Size(48, 48)),
            'assets/images/emergency_car_icon.png')
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

    GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 13.5,
        ),
      ),
    );
    return position;
  }

  Future<String> _getAddressFromLatLng(
      double latitude, double longitude) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);
      Placemark place = placemarks[0];

      // Construct a readable address from the placemark data
      String address =
          "${place.street}, ${place.locality}, ${place.postalCode}, ${place.country}";
      return address;
    } catch (e) {
      print(e);
      return "Address not available";
    }
  }

  void _addPolyline(List<PointLatLng> points) {
    final polylineId = 'polyline_${_polylineIdCounter++}';
    final polyline = Polyline(
      polylineId: PolylineId(polylineId),
      color: Colors.blue,
      width: 4,
      points: points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
    );

    setState(() {
      _polylines.add(polyline);
    });
  }

  void _getPolylinesPoints() async {
    PolylinePoints polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey: googleMapKey,
      request: PolylineRequest(
        origin: PointLatLng(sourceLocation.latitude, sourceLocation.longitude),
        destination: PointLatLng(
            destinationLocation.latitude, destinationLocation.longitude),
        mode: TravelMode.driving,
        // wayPoints: [PolylineWayPoint(location: "Sabo, Yaba Lagos Nigeria")],
      ),
    );
    if (result.points.isNotEmpty) {
      polylineCoordinates.clear(); // Clear any previous data
      for (PointLatLng point in result.points) {
        LatLng latLngPoint = LatLng(point.latitude, point.longitude);
        polylineCoordinates.add(latLngPoint);
      }
      print("Polyline Coordinates: $polylineCoordinates"); // Debugging
    } else {
      logger.e("No points found in polyline result.");
    }

    setState(() {});
  }

  void _addCircle(LatLng point) async {
    final circleId = CircleId('circle_${_circles.length + 1}');
    final circle = Circle(
      circleId: circleId,
      center: point,
      radius: _radiusValue,
      fillColor: Colors.blue.withOpacity(0.1),
      strokeColor: Colors.blue,
      strokeWidth: 2,
    );

    setState(() {
      _circles.add(circle);
    });

    final controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: point, zoom: 12),
    ));
  }

  gotoPlace(double lat, double lng, double endLat, double endLng,
      Map<String, dynamic> boundsNe, Map<String, dynamic> boundsSw) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
            southwest: LatLng(boundsSw['lat'], boundsSw['lng']),
            northeast: LatLng(boundsNe['lat'], boundsNe['lng'])),
        25));
    _addMarker(LatLng(lat, lng));
    _addMarker(LatLng(endLat, endLng));
  }
}

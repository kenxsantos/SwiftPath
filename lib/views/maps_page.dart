// ignore_for_file: prefer_final_fields, non_constant_identifier_names, unused_field, curly_braces_in_flow_control_structures, prefer_typing_uninitialized_variables

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:fab_circular_menu_plus/fab_circular_menu_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:swiftpath/pages/incident_report.dart';
import 'package:swiftpath/pages/settings_page.dart';
import 'package:swiftpath/pages/text_to_speech.dart';
import 'package:swiftpath/views/emergency_vehicle.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/auto_complete_result.dart';
import '../services/map_services.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, required this.origin, required this.destination});

  final String? origin;
  final String? destination;
  @override
  // ignore: library_private_types_in_public_api

  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  Timer? _debounce;

  TextEditingController _searchEditingController = TextEditingController();
  TextEditingController _autoCompleteSearchEditingController =
      TextEditingController();
  TextEditingController _originController =
      TextEditingController(text: "Manila");
  TextEditingController _destinationController = TextEditingController();

  bool showsearchbar = false;
  bool showAutoCompleteSearchBar = true;
  bool noreslt = false;
  bool originnoreslt = false;
  bool destinationnorelt = false;
  bool radiusSlider = false;
  bool cardTapped = false;
  bool pressedNear = false;
  bool getDirections = false;
  String? myLocation;

  final String google_map_key = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  final GlobalKey<FabCircularMenuPlusState> fabKey = GlobalKey();
  final LocationSettings locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 100,
  );
  String searchAddr = '';
  ValueNotifier<String> _originAddr = ValueNotifier<String>('');
  ValueNotifier<String> _destinationAddr = ValueNotifier<String>('');
  String tokenKey = '';
  var tappedPoint;
  var radiusValue = 3000.0;
  List allFavoritePlaces = [];
  ValueNotifier<String> _searchAutoCompleteAddr = ValueNotifier<String>('');
  Completer<GoogleMapController> _controller = Completer();

  int polylineIdCounter = 1;
  Set<Polyline> _polylines = <Polyline>{};

  late PageController _pageController;
  int prevPage = 0;
  var tappedPlaceDetail;
  String placeImg = '';
  var photoGalleryIndex = 0;
  bool showBlankCard = false;
  bool isReviews = true;
  bool isPhotos = false;
  var selectedPlaceDetails;

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(20.5937, 78.9629),
    zoom: 4,
  );
  CameraPosition _currentCameraPosition = _kGooglePlex;

  var uuid = const Uuid();
  String _sessionToken = '122344';
  List<dynamic> _placesList = [];

  onChange(String inputvalue) {
    if (_sessionToken.isEmpty) {
      _sessionToken = uuid.v4();
    }
    return getSuggestion(inputvalue);
  }

//! Function to get current user location through GPS
  Future<Position> getcurrentuserlocation() async {
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
    return await Geolocator.getCurrentPosition(
        locationSettings: locationSettings);
  }

//! funtion to retreive the autocompleter data from getplaces API of google maps
  getSuggestion(String input) async {
    String baseURL =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json';
    String request =
        '$baseURL?input=$input&key=$google_map_key&sessiontoken=$_sessionToken';
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

//! Function to set marker on the map upon searching
//Markers set
  Set<Marker> _markers = <Marker>{};
  Set<Marker> _markersDupe = <Marker>{};
//initial marker count value
  int markerIdCounter = 1;
  void _setMarker(LatLng point, {String? info}) {
    var counter = markerIdCounter++;

    final Marker marker = Marker(
        markerId: MarkerId('marker_$counter'),
        position: point,
        infoWindow: InfoWindow(title: info),
        onTap: () {},
        icon: BitmapDescriptor.defaultMarker);

    setState(() {
      _markers.add(marker);
    });
  }

//! Function to set polyline on the map upon searching
  void _setPolyline(List<PointLatLng> points) {
    final String polylineIdVal = 'polyline_$polylineIdCounter';

    polylineIdCounter++;
    _polylines.add(Polyline(
        polylineId: PolylineId(polylineIdVal),
        width: 2,
        color: Colors.blue,
        points: points.map((e) => LatLng(e.latitude, e.longitude)).toList()));
  }

  Set<Circle> _circles = <Circle>{};
  void _setCircle(LatLng point) async {
    final GoogleMapController controller = await _controller.future;

    controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: point, zoom: 12)));
    setState(() {
      _circles.add(Circle(
          circleId: const CircleId('circle_1'),
          center: point,
          fillColor: Colors.blue.withOpacity(0.1),
          radius: radiusValue,
          strokeColor: Colors.blue,
          strokeWidth: 1));
      getDirections = false;
      radiusSlider = true;
    });
  }

//! initial State upon loading & dispose upon widget when completely removed from tree
  @override
  void initState() {
    super.initState();
    _autoCompleteSearchEditingController.addListener(() {
      onChange(_searchAutoCompleteAddr.value);
    });
    _originController = TextEditingController(text: "Manila");
  }

  @override
  void dispose() {
    super.dispose();
    _autoCompleteSearchEditingController.dispose();
    _searchAutoCompleteAddr.dispose();
    _searchEditingController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _autoCompleteSearchEditingController.removeListener(() {
      onChange(_searchAutoCompleteAddr.value);
    });
    _debounce?.cancel();
    PageController().dispose();
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
                    initialCameraPosition: _kGooglePlex,
                    mapType: MapType.normal,
                    onMapCreated: (controller) {
                      _controller.complete(controller);
                    },
                    markers: _markers,
                    polylines: _polylines,
                    circles: _circles,
                    onCameraMove: (CameraPosition position) {
                      _currentCameraPosition = position;
                    },
                    // onTap: (point) {
                    //   tappedPoint = point;
                    //   _setCircle(point);
                    // },
                  )),
              //!stack if asked autocomplet seachnbar
              showAutoCompleteSearchBar
                  ? autocompletesearchbar()
                  : Container(), // this way also correct
              //!stack of navigate to user current location using GPS
              showGPSlocator(),
              //!Stack to show the autocomplete result
              //?implemented value Listanble builder without calling setstate() in onchange of textfield
              ValueListenableBuilder(
                valueListenable: _searchAutoCompleteAddr,
                builder: (context, value, _) {
                  return showAutoCompleteSearchBar &&
                          _searchAutoCompleteAddr.value.isNotEmpty
                      ? showAutoCompleteList()
                      : Container();
                },
              ),
              //!Stack to show origin to Destination Direction
              getDirections
                  ? getDirectionAndOriginToDestinationNavigate()
                  : Container(),
              //!Stack to show navigation autocomplete result
              ValueListenableBuilder(
                valueListenable: _originAddr,
                builder: (context, value, _) {
                  return getDirections &&
                          _originAddr.value.trim().isNotEmpty &&
                          _destinationAddr.value.trim().isEmpty
                      ? showOriginAutoCompleteListUponNavigation()
                      : Container();
                },
              ),
              ValueListenableBuilder(
                valueListenable: _destinationAddr,
                builder: (context, value, _) {
                  return getDirections &&
                          _destinationAddr.value.trim().isNotEmpty
                      ? showDestinationAutoCompleteListUponNavigation()
                      : Container();
                },
              ),
            ],
          ),
        ],
      ))),
      //!Outside of body--> fab Circular Menu
      floatingActionButton: FabCircularMenuPlus(
          key: fabKey,
          alignment: Alignment.bottomLeft,
          fabColor: Colors.red.shade400,
          fabOpenColor: Colors.red.shade400,
          fabElevation: 4,
          ringDiameter: 350.0,
          ringWidth: 65.0,
          fabMargin: const EdgeInsets.only(left: 25),
          ringColor: Colors.red.shade400,
          fabSize: 60.0,
          fabOpenIcon: const Icon(Icons.menu, color: Colors.white),
          fabCloseIcon: const Icon(Icons.close, color: Colors.white),
          children: [
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const EmergencyVehicles()),
                );
              },
              icon: const Icon(
                Icons.emergency_rounded,
                color: Colors.white,
              ),
            ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
              icon: const Icon(
                Icons.settings,
                color: Colors.white,
              ),
            ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const IncidentReportPage()),
                );
              },
              icon: const Icon(
                Icons.report,
                color: Colors.white,
              ),
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  showsearchbar = false;
                  showAutoCompleteSearchBar = false;
                  _autoCompleteSearchEditingController.clear();
                  _originController.clear();
                  _destinationController.clear();
                  //
                  _searchAutoCompleteAddr.value = '';
                  _originAddr.value = '';
                  _destinationAddr.value = '';
                  //
                  radiusSlider = false;
                  pressedNear = false;
                  cardTapped = false;
                  getDirections = true;
                });
                if (_polylines.isNotEmpty) {
                  _originController.text = '';
                  _destinationController.text = '';
                  _autoCompleteSearchEditingController.text = '';
                  _searchEditingController.text = '';
                  _markers = {};
                  _polylines = {};
                }
                if (fabKey.currentState!.isOpen) {
                  fabKey.currentState!.close();
                }
              },
              icon: const Icon(
                Icons.navigation,
                color: Colors.white,
              ),
            ),
          ]),
    );
  }

//! Function for GPS locator in stack
  Positioned showGPSlocator() {
    return Positioned(
      bottom: MediaQuery.of(context).size.height * 0.15,
      right: 5,
      child: FloatingActionButton(
        onPressed: () async {
          GoogleMapController controller = await _controller.future;
          developer.log('pressed');
          getcurrentuserlocation().then((value) async {
            await controller.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: LatLng(value.latitude, value.longitude),
                  zoom: 14.2,
                ),
              ),
            );
            showAutoCompleteSearchBar = false;
            _setMarker(LatLng(value.latitude, value.longitude),
                info: "My Current Location");
          });
        },
        shape: const CircleBorder(),
        backgroundColor: Colors.red.shade400,
        child: const Icon(
          Icons.my_location_rounded,
          color: Colors.white,
          size: 25,
        ),
      ),
    );
  }

  Positioned autocompletesearchbar() {
    return Positioned(
      top: 40.0,
      right: 15.0,
      left: 15.0,
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: double.infinity,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5.0), color: Colors.white),
            child: SizedBox(
              height: 50.0,
              child: ValueListenableBuilder(
                valueListenable: _searchAutoCompleteAddr,
                builder: (BuildContext context, dynamic value, Widget? _) {
                  return TextField(
                    controller: _searchEditingController,
                    keyboardType: TextInputType.streetAddress,
                    autofocus: true, //for keyboard focus upon the start
                    textInputAction: TextInputAction
                        .search, //to trigger enter key here search key
                    onEditingComplete: () async {
                      searchandNavigate(await _controller.future, value,
                          zoom: 14);
                      FocusManager.instance.primaryFocus
                          ?.unfocus(); //to hide keyboard upon pressing done
                      _searchAutoCompleteAddr.value = '';
                    },
                    decoration: InputDecoration(
                      hintText: 'Search Auto Complete..',
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.only(left: 15.0, top: 12.0),
                      suffixIcon: TextToSpeech(
                        textController: _searchEditingController,
                        onSpeechResult: (text) async {
                          GoogleMapController mapController =
                              await _controller.future.then(
                            (value) => searchandNavigate(value, text, zoom: 14),
                          );
                        },
                      ),
                    ),
                    onChanged: (val) {
                      //!<<<<debounce
                      if (_debounce?.isActive ?? false) _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 500), () {
                        _searchAutoCompleteAddr.value = val;
                      });
                      //!debounce>>>>
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

// //!function to show auto complete suggestion in stack
  Positioned showAutoCompleteList() {
    return noreslt == false && _searchAutoCompleteAddr.value.trim().length >= 2
        ? Positioned(
            top: 110,
            right: 15,
            left: 15,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                color: Colors.red.shade100.withOpacity(0.7),
              ),
              child: FutureBuilder(
                future: onChange(_searchAutoCompleteAddr.value),
                builder: (BuildContext context, AsyncSnapshot snapshot) {
                  return snapshot.hasData
                      ? ListView.builder(
                          itemCount: snapshot.data['predictions'].length ?? 3,
                          padding: const EdgeInsets.only(top: 0, right: 0),
                          itemBuilder: (BuildContext context, int index) {
                            if (snapshot.hasData) {
                              return ListTile(
                                title: Text(
                                  snapshot.data['predictions'][index]
                                          ['description']
                                      .toString(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                                onTap: () {
                                  setState(() async {
                                    _autoCompleteSearchEditingController.text =
                                        snapshot.data['predictions'][index]
                                                ['description']
                                            .toString();
                                    //!important
                                    FocusScope.of(context).requestFocus(
                                        FocusNode()); //to close the keyboard
                                    searchandNavigate(
                                        await _controller.future,
                                        _autoCompleteSearchEditingController
                                            .text,
                                        zoom: 14);
                                    _searchAutoCompleteAddr.value = '';
                                  });
                                },
                                leading: const Icon(
                                  Icons.location_on_outlined,
                                  color: Colors.red,
                                ),
                              );
                            } else {
                              setState(() {
                                if (_searchAutoCompleteAddr.value
                                            .trim()
                                            .length >=
                                        2 &&
                                    snapshot.hasData) {
                                  noreslt = true;
                                }
                              });
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                          },
                        )
                      : const Center(
                          child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                "Loading...",
                                textScaleFactor: 1.5,
                              ),
                            ),
                          ],
                        ));
                },
              ),
            ),
          )
        : Positioned(
            top: 110,
            right: 15,
            left: 15,
            child: Container(
              height: 200.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                color: Colors.red.shade100.withOpacity(0.7),
              ),
              child: Stack(
                children: [
                  // Close Button positioned at the top-right corner
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close, // Close icon
                        color: Colors.black,
                      ),
                      onPressed: () {
                        setState(() {
                          showAutoCompleteSearchBar = false;
                          _autoCompleteSearchEditingController.clear();
                        });
                      },
                    ),
                  ),
                  // Centered content
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'No results to show',
                          style: TextStyle(fontWeight: FontWeight.w400),
                        ),
                        SizedBox(height: 5.0),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
  }

//!function to get direction from origin to destination in stack
  Positioned getDirectionAndOriginToDestinationNavigate() {
    return Positioned(
      height: MediaQuery.of(context).size.height * 1,
      top: 30.0,
      left: 10.0,
      right: 10.0,
      child: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8.0),
              color: Colors.white), // Background color for the whole Row
          padding: const EdgeInsets.all(10.0), // Optional padding
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15.0),
                        color: Colors.white,
                      ),
                      child: TextFormField(
                        onTap: () {
                          _destinationAddr.value = '';
                        },
                        onEditingComplete: () {
                          FocusManager.instance.primaryFocus?.nextFocus();
                          _originAddr.value = '';
                        },
                        autofocus: true,
                        controller: _originController,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
                        onChanged: (val) {
                          if (_debounce?.isActive ?? false) _debounce?.cancel();
                          _debounce =
                              Timer(const Duration(milliseconds: 500), () {
                            _originAddr.value = val;
                          });
                        },
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          hintText: 'Origin',
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 20.0, vertical: 15.0),
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.black),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.black),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.black),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3.0),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5.0),
                        color: Colors.white,
                      ),
                      child: TextFormField(
                        onTap: () {
                          _originAddr.value = '';
                        },
                        controller: _destinationController,
                        textInputAction: TextInputAction.search,
                        keyboardType: TextInputType.streetAddress,
                        onChanged: (val) {
                          if (_debounce?.isActive ?? false) _debounce?.cancel();
                          _debounce =
                              Timer(const Duration(milliseconds: 500), () {
                            _destinationAddr.value = val;
                          });
                        },
                        onEditingComplete: () async {
                          var directions = await MapServices().getDirections(
                              _originController.text,
                              _destinationController.text);
                          _markers = {};
                          _polylines = {};
                          gotoPlace(
                              directions['start_location']['lat'],
                              directions['start_location']['lng'],
                              directions['end_location']['lat'],
                              directions['end_location']['lng'],
                              directions['bounds_ne'],
                              directions['bounds_sw']);
                          _setPolyline(directions['polyline_decoded']);
                          FocusManager.instance.primaryFocus?.unfocus();
                          _originAddr.value = '';
                          _destinationAddr.value = '';
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white, // Set the background to gray
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20.0, vertical: 15.0),
                          border: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.black),
                          ),
                          enabledBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.black),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.black),
                          ),
                          hintText: 'Destination',
                          suffixIcon: IconButton(
                              onPressed: () async {
                                var directions = await MapServices()
                                    .getDirections(_originController.text,
                                        _destinationController.text);
                                _markers = {};
                                _polylines = {};
                                gotoPlace(
                                    directions['start_location']['lat'],
                                    directions['start_location']['lng'],
                                    directions['end_location']['lat'],
                                    directions['end_location']['lng'],
                                    directions['bounds_ne'],
                                    directions['bounds_sw']);
                                _setPolyline(directions['polyline_decoded']);
                                FocusManager.instance.primaryFocus?.unfocus();
                                _originAddr.value = '';
                                _destinationAddr.value = '';
                                setState(() {});
                              },
                              icon: const Icon(
                                Icons.search,
                                color: Colors.black,
                                size: 20,
                              )),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Container(
                width: MediaQuery.of(context).size.width * 0.10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white, // Circle's background color
                ),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center, // Center the icons vertically
                  children: [
                    // Close button placed at the top
                    IconButton(
                      onPressed: () {
                        setState(() {
                          getDirections = false;
                          _originController.text = '';
                          _destinationController.text = '';
                          _markers = {};
                          _polylines = {};
                        });
                      },
                      icon: const Icon(
                        Icons.close,
                        color: Colors.black,
                        size: 20,
                      ),
                    ),
                    // Rotated compare arrows icon below the close button
                    RotatedBox(
                      quarterTurns: 1, // Rotate the icon
                      child: IconButton(
                        onPressed: () async {
                          setState(() {
                            // Switch the text values between origin and destination
                            String temp = _originController.text;
                            _originController.text =
                                _destinationController.text;
                            _destinationController.text = temp;
                          });

                          // Fetch new directions based on the swapped values
                          var directions = await MapServices().getDirections(
                            _originController.text,
                            _destinationController.text,
                          );

                          // Clear existing markers and polylines
                          setState(() {
                            _markers = {};
                            _polylines = {};

                            // Update the map with the new directions and polylines
                            gotoPlace(
                              directions['start_location']['lat'],
                              directions['start_location']['lng'],
                              directions['end_location']['lat'],
                              directions['end_location']['lng'],
                              directions['bounds_ne'],
                              directions['bounds_sw'],
                            );
                            _setPolyline(directions['polyline_decoded']);
                          });
                        },
                        icon: const Icon(
                          Icons.compare_arrows_outlined,
                          color: Colors.black,
                          size: 20,
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

//!Function to show auto complete suggestion in stack upon origin to destination navigation in flutter
  Positioned showOriginAutoCompleteListUponNavigation() {
    return originnoreslt == false && _originAddr.value.trim().length >= 2
        ? Positioned(
            top: 170,
            right: 10,
            left: 10,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                color: Colors.red.shade100.withOpacity(0.7),
              ),
              child: FutureBuilder(
                future: onChange(_originAddr.value),
                builder: (BuildContext context, AsyncSnapshot snapshot) {
                  return snapshot.hasData
                      ? ListView.builder(
                          itemCount: snapshot.data['predictions'].length ?? 3,
                          padding: const EdgeInsets.only(top: 0, right: 0),
                          itemBuilder: (BuildContext context, int index) {
                            if (snapshot.hasData) {
                              return ListTile(
                                title: Text(
                                  snapshot.data['predictions'][index]
                                          ['description']
                                      .toString(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                                onTap: () {
                                  setState(() {
                                    _originController.text = snapshot
                                        .data['predictions'][index]
                                            ['description']
                                        .toString();

                                    _originAddr.value = '';
                                  });
                                  FocusManager.instance.primaryFocus
                                      ?.nextFocus();
                                  _originAddr.value = '';
                                },
                                leading: const Icon(
                                  Icons.location_on_outlined,
                                  color: Colors.red,
                                ),
                              );
                            } else {
                              setState(() {
                                if (_originAddr.value.trim().length >= 2 &&
                                    snapshot.hasData) {
                                  originnoreslt = true;
                                }
                              });
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                          },
                        )
                      : const Center(
                          child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                "Loading...",
                                textScaleFactor: 1.5,
                              ),
                            ),
                          ],
                        ));
                },
              ),
            ),
          )
        : Positioned(
            top: 170,
            right: 10,
            left: 10,
            child: Container(
              height: 200.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                color: Colors.red.shade100.withOpacity(0.7),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 10,
                    right: 10, // Close button positioned to the top-right
                    child: IconButton(
                      icon: const Icon(
                        Icons.close, // Use the close icon
                        color: Colors.black,
                      ),
                      onPressed: () {
                        setState(() {
                          getDirections = false;
                          _originController.clear();
                          _destinationController.clear();
                        });
                      },
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            developer.log('pressed');
                            await getcurrentuserlocation().then((value) {
                              placemarkFromCoordinates(
                                      value.latitude, value.longitude)
                                  .then((placemark) {
                                _originController.text =
                                    '${placemark.reversed.last.name} ${placemark.reversed.last.subLocality} ${placemark.reversed.last.locality} ${placemark.reversed.last.administrativeArea} ${placemark.reversed.last.country}';
                                _originController.selection =
                                    TextSelection.fromPosition(TextPosition(
                                        offset: _originController.text.length));
                                FocusManager.instance.primaryFocus?.nextFocus();
                                _originAddr.value = '';
                              });
                            }).then((value) => FocusManager
                                .instance.primaryFocus
                                ?.nextFocus());
                          },
                          child: Container(
                            height: 45,
                            padding: const EdgeInsets.all(5),
                            margin: const EdgeInsets.only(
                                top: 10, right: 15, left: 15, bottom: 5),
                            decoration: BoxDecoration(
                              color: Colors.white60.withOpacity(1),
                              borderRadius: BorderRadius.circular(10.0),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.grey,
                                  offset: Offset(0.0, 1.0), //(x,y)
                                  blurRadius: 3.0,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.my_location_rounded,
                                  color: Colors.black45,
                                  size: 20,
                                ),
                                Text(" Use your location",
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10.0),
                        const Text(
                          'No results to show',
                          style: TextStyle(fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
  }

  Positioned showDestinationAutoCompleteListUponNavigation() {
    return destinationnorelt == false &&
            _destinationAddr.value.trim().length >= 2
        ? Positioned(
            top: 170,
            right: 10,
            left: 10,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                color: Colors.red.shade100.withOpacity(0.7),
              ),
              child: FutureBuilder(
                future: onChange(_destinationAddr.value),
                builder: (BuildContext context, AsyncSnapshot snapshot) {
                  return snapshot.hasData
                      ? ListView.builder(
                          itemCount: snapshot.data['predictions'].length ?? 3,
                          padding: const EdgeInsets.only(top: 0, right: 0),
                          itemBuilder: (BuildContext context, int index) {
                            if (snapshot.hasData) {
                              return ListTile(
                                title: Text(
                                  snapshot.data['predictions'][index]
                                          ['description']
                                      .toString(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                                onTap: () async {
                                  _destinationController.text = snapshot
                                      .data['predictions'][index]['description']
                                      .toString();
                                  var directions = await MapServices()
                                      .getDirections(_originController.text,
                                          _destinationController.text);
                                  _markers = {};
                                  _polylines = {};
                                  gotoPlace(
                                      directions['start_location']['lat'],
                                      directions['start_location']['lng'],
                                      directions['end_location']['lat'],
                                      directions['end_location']['lng'],
                                      directions['bounds_ne'],
                                      directions['bounds_sw']);
                                  _setPolyline(directions['polyline_decoded']);
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  _originAddr.value = '';
                                  _destinationAddr.value = '';

                                  setState(() {});
                                },
                                leading: const Icon(
                                  Icons.location_on_outlined,
                                  color: Colors.red,
                                ),
                              );
                            } else {
                              setState(() {
                                if (_destinationAddr.value.trim().length >= 2 &&
                                    snapshot.hasData) {
                                  destinationnorelt = true;
                                }
                              });
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                          },
                        )
                      : const Center(
                          child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text(
                                "Loading...",
                                textScaleFactor: 1.5,
                              ),
                            ),
                          ],
                        ));
                },
              ),
            ),
          )
        : Positioned(
            top: 170,
            right: 10,
            left: 10,
            child: Container(
              height: 200.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                color: Colors.red.shade100.withOpacity(0.7),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close, // Use the close icon
                        color: Colors.black,
                      ),
                      onPressed: () {
                        setState(() {
                          getDirections = false;
                          _originController.clear();
                          _destinationController.clear();
                        });
                      },
                    ),
                  ),
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'No results to show',
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        SizedBox(height: 5.0),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
  }

//! functction for naviagtion to a spectific latlang
  searchandNavigate(GoogleMapController mapController, String inputvalue,
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
        _setMarker(LatLng(result.last.latitude, result.last.longitude),
            info: inputvalue),
      },
    );
  }

//! functction to go to a place with close precison and with end lat and lang
  gotoPlace(double lat, double lng, double endLat, double endLng,
      Map<String, dynamic> boundsNe, Map<String, dynamic> boundsSw) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
            southwest: LatLng(boundsSw['lat'], boundsSw['lng']),
            northeast: LatLng(boundsNe['lat'], boundsNe['lng'])),
        25));
    _setMarker(LatLng(lat, lng));
    _setMarker(LatLng(endLat, endLng));
  }

//! functction to move camera sightly upon sliding the page viewer
  Future<void> moveCameraSlightly() async {
    final GoogleMapController controller = await _controller.future;

    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(
            allFavoritePlaces[_pageController.page!.toInt()]['geometry']
                    ['location']['lat'] +
                0.0125,
            allFavoritePlaces[_pageController.page!.toInt()]['geometry']
                    ['location']['lng'] +
                0.005),
        zoom: 14.0,
        bearing: 45.0,
        tilt: 45.0)));
  }

//! functction to go to searched place
  Future<void> gotoSearchedPlace(double lat, double lng) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(lat, lng), zoom: 12)));
    _setMarker(LatLng(lat, lng));
  }

//!Function to build list of items for page viewer
  Widget buildListItem(AutoCompleteResult placeItem, searchFlag) {
    return Padding(
      padding: const EdgeInsets.all(5.0),
      child: GestureDetector(
        onTapDown: (_) {
          FocusManager.instance.primaryFocus?.unfocus();
        },
        onTap: () async {
          var place = await MapServices().getPlace(placeItem.placeId);
          gotoSearchedPlace(place['geometry']['location']['lat'],
              place['geometry']['location']['lng']);
          searchFlag.toggleSearch();
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.location_on, color: Colors.green, size: 25.0),
            const SizedBox(width: 4.0),
            SizedBox(
              height: 40.0,
              width: MediaQuery.of(context).size.width - 75.0,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(placeItem.description ?? ''),
              ),
            )
          ],
        ),
      ),
    );
  }
}

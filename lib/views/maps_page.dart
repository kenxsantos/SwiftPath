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
import 'package:swiftpath/components/autocomplete_list.dart';
import 'package:swiftpath/components/destination_autocomplete_list_false.dart';
import 'package:swiftpath/components/destination_autocomplete_list_true.dart';
import 'package:swiftpath/components/floating_button.dart';
import 'package:swiftpath/components/origin_autocomplete_list_true.dart';
import 'package:swiftpath/components/origin_autocomplete_list_false.dart';
import 'package:swiftpath/pages/incident_report.dart';
import 'package:swiftpath/pages/settings_page.dart';
import 'package:swiftpath/components/searchBar.dart';
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
  TextEditingController _originController = TextEditingController();
  TextEditingController _destinationController = TextEditingController();

  bool showAutoCompleteSearchBar = true;
  bool noResult = false;
  bool originNoResult = false;
  bool destinationNoResult = false;

  bool getDirections = false;
  String? myLocation;

  var tappedPoint;

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

  var radiusValue = 3000.0;

  ValueNotifier<String> _searchAutoCompleteAddr = ValueNotifier<String>('');
  Completer<GoogleMapController> _controller = Completer();

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
  int polylineIdCounter = 1;
  Set<Polyline> _polylines = <Polyline>{};
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
    });
  }

//! initial State upon loading & dispose upon widget when completely removed from tree
  @override
  void initState() {
    super.initState();
    _autoCompleteSearchEditingController.addListener(() {
      onChange(_searchAutoCompleteAddr.value);
    });
    _originController = TextEditingController();
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
                    //   _setMarker(point);
                    // },
                  )),
              //!stack if asked autocomplet seachnbar
              showAutoCompleteSearchBar
                  ? autoCompleteSearchBar()
                  : autoCompleteSearchBar(), // this way also correct
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
                  showAutoCompleteSearchBar = true;
                  _autoCompleteSearchEditingController.clear();
                  _originController.clear();
                  _destinationController.clear();
                  //
                  _searchAutoCompleteAddr.value = '';
                  _originAddr.value = '';
                  _destinationAddr.value = '';

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
        child: CustomFloatingActionButton(
          controller: _controller,
          getCurrentUserLocation: getCurrentUserLocation,
          setMarker: _setMarker,
          backgroundColor: Colors.red.shade400,
          icon: Icons.my_location_rounded,
          iconSize: 25.0,
          markerInfo: "My Current Location",
        ));
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
    return originNoResult == false && _originAddr.value.trim().length >= 2
        ? Positioned(
            top: 170,
            right: 10,
            left: 10,
            child: OriginAutoCompleteListTrue(
              searchValueNotifier: _originAddr,
              futureData: (value) => onChange(value),
              textController: _originController,
              onSelectItem: (selectedText) {
                setState(() {
                  _originController.text = selectedText;
                  _originAddr.value = '';
                });
              },
            ))
        : Positioned(
            top: 170,
            right: 10,
            left: 10,
            child: OriginAutocompleteListFalse(
              onClose: () {
                setState(() {
                  getDirections = false;
                  _originController.clear();
                  _destinationController.clear();
                });
              },
              onUseCurrentLocation: () async {
                await getCurrentUserLocation().then((value) {
                  placemarkFromCoordinates(value.latitude, value.longitude)
                      .then((placemark) {
                    _originController.text =
                        '${placemark.reversed.last.name} ${placemark.reversed.last.subLocality} '
                        '${placemark.reversed.last.locality} ${placemark.reversed.last.administrativeArea} '
                        '${placemark.reversed.last.country}';
                    _originController.selection = TextSelection.fromPosition(
                        TextPosition(offset: _originController.text.length));
                    FocusManager.instance.primaryFocus?.nextFocus();
                    _originAddr.value = '';
                  });
                });
              },
            ));
  }

  Positioned showDestinationAutoCompleteListUponNavigation() {
    return destinationNoResult == false &&
            _destinationAddr.value.trim().length >= 2
        ? Positioned(
            top: 170,
            right: 10,
            left: 10,
            child: DestinationAutoCompleteListTrue(
              destinationAddr: _destinationAddr,
              destinationController: _destinationController,
              originController: _originController,
              onChange: (value) => onChange(value),
              gotoPlace: gotoPlace,
              setPolyline: _setPolyline,
              mapServices: MapServices(),
            ))
        : Positioned(
            top: 170,
            right: 10,
            left: 10,
            child: DestinationAutoCompleteListFalse(
              onClose: () {
                setState(() {
                  getDirections = false; // Update your state variable
                  _originController.clear(); // Clear the origin controller
                  _destinationController
                      .clear(); // Clear the destination controller
                });
              },
            ));
  }

//! functction for naviagtion to a spectific latlang
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

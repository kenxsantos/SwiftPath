// ignore_for_file: prefer_final_fields, non_constant_identifier_names, unused_field, curly_braces_in_flow_control_structures, prefer_typing_uninitialized_variables

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui' as ui;
import 'package:fab_circular_menu_plus/fab_circular_menu_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_rating_stars/flutter_rating_stars.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:swiftpath/pages/text_to_speech.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/auto_complete_result.dart';
import '../services/map_services.dart';
import 'package:roam_flutter/roam_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
//! Debounce for smooth ui upon searching
  Timer? _debounce;
//! Text editing controllers
  TextEditingController _searcheditingcontroller = TextEditingController();
  TextEditingController _autocompletesearcheditingcontroller =
      TextEditingController();
  TextEditingController _originController = TextEditingController();
  TextEditingController _destinationController = TextEditingController();
//! boolean values for ui
  bool showsearchbar = false;
  bool showautocompletesearchbar = false;
  bool noreslt = false;
  bool originnoreslt = false;
  bool destinationnorelt = false;
  bool radiusSlider = false;
  bool cardTapped = false;
  bool pressedNear = false;
  bool getDirections = false;
  String? myLocation;

  final String google_map_key = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
// !global keys
  final GlobalKey<FabCircularMenuPlusState> fabKey = GlobalKey();
  final LocationSettings locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 100,
  );
//! variables & Constants
  String searchAddr = '';
  ValueNotifier<String> _originAddr = ValueNotifier<String>('');
  ValueNotifier<String> _destinationAddr = ValueNotifier<String>('');
  String tokenKey = '';
  var tappedPoint;
  var radiusValue = 3000.0;
  List allFavoritePlaces = [];
  ValueNotifier<String> _searchautocompleteAddr = ValueNotifier<String>('');
//! completer for map
  Completer<GoogleMapController> _controller = Completer();
//! Initial camera position
  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(20.5937, 78.9629),
    zoom: 4,
  );
//! Getting uuid of the device of the user & session token
  var uuid = const Uuid();
  String _sessionToken = '122344';
  List<dynamic> _placesList = [];
//! Current camera postion
  CameraPosition _currentCameraPosition =
      _kGooglePlex; //initially set to starting camera position.
//!onchage Function to assign session token to the user
  onChange(String inputvalue) {
    if (_sessionToken.isEmpty) {
      _sessionToken = uuid.v4();
    }
    //return getSuggestion(_autocompletesearcheditingcontroller.text);//correct when used withoutdebounce
    return getSuggestion(
        inputvalue); //correct both with debounce and withoutdebounce
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
    //?Important!!!<<Place your API key Here,pass it as string>>
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

  int polylineIdCounter = 1;
  Set<Polyline> _polylines = <Polyline>{};

//! Page controller for the nice pageview
  late PageController _pageController;
  int prevPage = 0;
  var tappedPlaceDetail;
  String placeImg = '';
  var photoGalleryIndex = 0;
  bool showBlankCard = false;
  bool isReviews = true;
  bool isPhotos = false;

  //!Important!!!<<Place your API key Here>>

  var selectedPlaceDetails;

//Circle
  Set<Circle> _circles = <Circle>{};

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

  void _setCircle(LatLng point) async {
    final GoogleMapController controller = await _controller.future;

    controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: point, zoom: 12)));
    setState(() {
      _circles.add(Circle(
          circleId: const CircleId('raj'),
          center: point,
          fillColor: Colors.blue.withOpacity(0.1),
          radius: radiusValue,
          strokeColor: Colors.blue,
          strokeWidth: 1));
      getDirections = false;
      radiusSlider = true;
    });
  }

//! Function to set near marker on the place searched upon map upon searching
  _setNearMarker(LatLng point, String label, List types, String status) async {
    var counter = markerIdCounter++;

    final Uint8List markerIcon;

    if (types.contains('restaurants')) {
      markerIcon =
          await getBytesFromAsset('assets/mapicons/restaurants.png', 75);
    } else if (types.contains('food')) {
      markerIcon = await getBytesFromAsset('assets/mapicons/food.png', 75);
    } else if (types.contains('school')) {
      markerIcon = await getBytesFromAsset('assets/mapicons/schools.png', 75);
    } else if (types.contains('bar')) {
      markerIcon = await getBytesFromAsset('assets/mapicons/bars.png', 75);
    } else if (types.contains('lodging')) {
      markerIcon = await getBytesFromAsset('assets/mapicons/hotels.png', 75);
    } else if (types.contains('store')) {
      markerIcon =
          await getBytesFromAsset('assets/mapicons/retail-stores.png', 75);
    } else if (types.contains('locality')) {
      markerIcon =
          await getBytesFromAsset('assets/mapicons/local-services.png', 75);
    } else {
      markerIcon = await getBytesFromAsset('assets/mapicons/places.png', 75);
    }

    final Marker marker = Marker(
        markerId: MarkerId('marker_$counter'),
        position: point,
        onTap: () {},
        icon: BitmapDescriptor.fromBytes(markerIcon));

    setState(() {
      _markers.add(marker);
    });
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);

    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  void _onScroll() {
    if (_pageController.page!.toInt() != prevPage) {
      prevPage = _pageController.page!.toInt();
      cardTapped = false;
      photoGalleryIndex = 1;
      showBlankCard = false;
      goToTappedPlace();
      fetchImage();
    }
  }

  //!Fetch image to place inside the tile in the pageView
  void fetchImage() async {
    if (_pageController.page !=
        null) if (allFavoritePlaces[_pageController.page!.toInt()]
            ['photos'] !=
        null) {
      setState(() {
        placeImg = allFavoritePlaces[_pageController.page!.toInt()]['photos'][0]
            ['photo_reference'];
      });
    } else {
      placeImg = '';
    }
  }

//! initial State upon loading & dispose upon widget when completely removed from tree
  @override
  void initState() {
    super.initState();
    _autocompletesearcheditingcontroller.addListener(() {
      onChange(_searchautocompleteAddr.value);
    });
    _pageController = PageController(initialPage: 1, viewportFraction: 0.85)
      ..addListener(_onScroll);
  }

  @override
  void dispose() {
    super.dispose();
    _autocompletesearcheditingcontroller.dispose();
    _searchautocompleteAddr.dispose();
    _searcheditingcontroller.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _autocompletesearcheditingcontroller.removeListener(() {
      onChange(_searchautocompleteAddr.value);
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
              //!stack of googlemap
              // ignore: sized_box_for_whitespace
              Container(
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
                    onTap: (point) {
                      tappedPoint = point;
                      _setCircle(point);
                    },
                  )),
              //!stack if asked normal seachnbar
              if (showsearchbar == true) searchbar(), //thisway also correct
              //!stack if asked autocomplet seachnbar
              showautocompletesearchbar
                  ? autocompletesearchbar()
                  : Container(), // this way also correct
              //!stack of navigate to user current location using GPS
              showGPSlocator(),
              //!Stack to show the autocomplete result
              //?implemented value Listanble builder without calling setstate() in onchange of textfield
              ValueListenableBuilder(
                valueListenable: _searchautocompleteAddr,
                builder: (context, value, _) {
                  return showautocompletesearchbar &&
                          _searchautocompleteAddr.value.isNotEmpty
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
              //!Stack to show radius slider
              radiusSlider
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(15.0, 30.0, 15.0, 0.0),
                      child: Container(
                        height: 50.0,
                        color: Colors.black.withOpacity(0.2),
                        child: Row(
                          children: [
                            Expanded(
                                child: Slider(
                                    max: 7000.0,
                                    min: 1000.0,
                                    value: radiusValue,
                                    onChanged: (newVal) {
                                      radiusValue = newVal;
                                      pressedNear = false;
                                      _setCircle(tappedPoint);
                                    })),
                            !pressedNear
                                ? IconButton(
                                    onPressed: () {
                                      if (_debounce?.isActive ?? false) {
                                        _debounce?.cancel();
                                      }
                                      _debounce = Timer(
                                          const Duration(seconds: 2), () async {
                                        var placesResult = await MapServices()
                                            .getPlaceDetails(tappedPoint,
                                                radiusValue.toInt());

                                        List<dynamic> placesWithin =
                                            placesResult['results'] as List;

                                        allFavoritePlaces = placesWithin;

                                        tokenKey =
                                            placesResult['next_page_token'] ??
                                                'none';
                                        _markers = {};
                                        for (var element in placesWithin) {
                                          _setNearMarker(
                                            LatLng(
                                                element['geometry']['location']
                                                    ['lat'],
                                                element['geometry']['location']
                                                    ['lng']),
                                            element['name'],
                                            element['types'],
                                            element['business_status'] ??
                                                'not available',
                                          );
                                        }
                                        _markersDupe = _markers;
                                        pressedNear = true;
                                      });
                                    },
                                    icon: const Icon(
                                      Icons.near_me,
                                      color: Colors.blue,
                                    ))
                                : IconButton(
                                    onPressed: () {
                                      if (_debounce?.isActive ?? false) {
                                        _debounce?.cancel();
                                      }
                                      _debounce = Timer(
                                          const Duration(seconds: 2), () async {
                                        if (tokenKey != 'none') {
                                          var placesResult = await MapServices()
                                              .getMorePlaceDetails(tokenKey);

                                          List<dynamic> placesWithin =
                                              placesResult['results'] as List;

                                          allFavoritePlaces
                                              .addAll(placesWithin);

                                          tokenKey =
                                              placesResult['next_page_token'] ??
                                                  'none';

                                          for (var element in placesWithin) {
                                            _setNearMarker(
                                              LatLng(
                                                  element['geometry']
                                                      ['location']['lat'],
                                                  element['geometry']
                                                      ['location']['lng']),
                                              element['name'],
                                              element['types'],
                                              element['business_status'] ??
                                                  'not available',
                                            );
                                          }
                                        } else {
                                          print('Thats all folks!!');
                                        }
                                      });
                                    },
                                    icon: const Icon(Icons.more_time,
                                        color: Colors.blue)),
                            IconButton(
                                onPressed: () {
                                  setState(() {
                                    radiusSlider = false;
                                    pressedNear = false;
                                    cardTapped = false;
                                    radiusValue = 3000.0;
                                    _circles = {};
                                    _markers = {};
                                    allFavoritePlaces = [];
                                  });
                                },
                                icon: const Icon(Icons.close,
                                    color: Colors.white))
                          ],
                        ),
                      ),
                    )
                  : Container(),
              //!Stack to show pressed near location
              pressedNear
                  ? Positioned(
                      bottom: 20.0,
                      child: SizedBox(
                        height: 200.0,
                        width: MediaQuery.of(context).size.width,
                        child: PageView.builder(
                            controller: _pageController,
                            itemCount: allFavoritePlaces.length,
                            itemBuilder: (BuildContext context, int index) {
                              return _nearbyPlacesList(index);
                            }),
                      ))
                  : Container(),
              //!Stack to show fill card of details,review,photos
              cardTapped
                  ? Positioned(
                      top: 100.0,
                      left: 15.0,
                      child: FlipCard(
                        front: Container(
                          height: 250.0,
                          width: 180.0,
                          decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8.0))),
                          child: SingleChildScrollView(
                            child: Column(children: [
                              Container(
                                height: 150.0,
                                width: 175.0,
                                decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(8.0),
                                      topRight: Radius.circular(8.0),
                                    ),
                                    image: DecorationImage(
                                        image: NetworkImage(placeImg != ''
                                            ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=$placeImg&key=$google_map_key'
                                            : 'https://pic.onlinewebfonts.com/svg/img_546302.png'),
                                        fit: BoxFit.cover)),
                              ),
                              Container(
                                padding: const EdgeInsets.all(7.0),
                                width: 180.0,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Address: ',
                                      style: TextStyle(
                                        fontWeight: FontWeight.normal,
                                        fontSize: 30,
                                      ),
                                    ),
                                    SizedBox(
                                        width: 105.0,
                                        child: Text(
                                          tappedPlaceDetail[
                                                  'formatted_address'] ??
                                              'none given',
                                          style: const TextStyle(
                                              fontSize: 11.0,
                                              fontWeight: FontWeight.w400),
                                        ))
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.fromLTRB(
                                    7.0, 0.0, 7.0, 0.0),
                                width: 180.0,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Contact: ',
                                      style: TextStyle(
                                          fontSize: 12.0,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    SizedBox(
                                        width: 105.0,
                                        child: Text(
                                          tappedPlaceDetail[
                                                  'formatted_phone_number'] ??
                                              'none given',
                                          style: const TextStyle(
                                              fontSize: 11.0,
                                              fontWeight: FontWeight.w400),
                                        ))
                                  ],
                                ),
                              ),
                            ]),
                          ),
                        ),
                        back: Container(
                          height: 300.0,
                          width: 225.0,
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(8.0)),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          isReviews = true;
                                          isPhotos = false;
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 700),
                                        curve: Curves.easeIn,
                                        padding: const EdgeInsets.fromLTRB(
                                            7.0, 4.0, 7.0, 4.0),
                                        decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(11.0),
                                            color: isReviews
                                                ? Colors.green.shade300
                                                : Colors.white),
                                        child: Text(
                                          'Reviews',
                                          style: TextStyle(
                                              color: isReviews
                                                  ? Colors.white
                                                  : Colors.black87,
                                              fontSize: 12.0,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          isReviews = false;
                                          isPhotos = true;
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 700),
                                        curve: Curves.easeIn,
                                        padding: const EdgeInsets.fromLTRB(
                                            7.0, 4.0, 7.0, 4.0),
                                        decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(11.0),
                                            color: isPhotos
                                                ? Colors.green.shade300
                                                : Colors.white),
                                        child: Text(
                                          'Photos',
                                          style: TextStyle(
                                              color: isPhotos
                                                  ? Colors.white
                                                  : Colors.black87,
                                              fontSize: 12.0,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: 250.0,
                                child: isReviews
                                    ? ListView(
                                        children: [
                                          if (isReviews &&
                                              tappedPlaceDetail['reviews'] !=
                                                  null)
                                            ...tappedPlaceDetail['reviews']!
                                                .map((e) {
                                              return _buildReviewItem(e);
                                            })
                                        ],
                                      )
                                    : _buildPhotoGallery(
                                        tappedPlaceDetail['photos'] ?? []),
                              )
                            ],
                          ),
                        ),
                      ))
                  : Container()
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
          fabElevation: 5,
          ringDiameter: 350.0,
          ringWidth: 65.0,
          fabMargin: const EdgeInsets.only(left: 25, top: 70),
          ringColor: Colors.red.shade400,
          fabSize: 60.0,
          fabOpenIcon: const Icon(Icons.menu, color: Colors.white),
          fabCloseIcon: const Icon(Icons.close, color: Colors.white),
          children: [
            IconButton(
                onPressed: () {
                  setState(() {
                    showsearchbar = true;
                    showautocompletesearchbar = false;
                    _searcheditingcontroller.clear();
                    _autocompletesearcheditingcontroller.clear();
                    _originController.clear();
                    _destinationController.clear();
                    radiusSlider = false;
                    pressedNear = false;
                    cardTapped = false;
                    getDirections = false;
                    _searchautocompleteAddr.value = '';
                    _originAddr.value = '';
                    _destinationAddr.value = '';
                  });
                  if (_polylines.isNotEmpty) {
                    _originController.text = '';
                    _destinationController.text = '';
                    _autocompletesearcheditingcontroller.text = '';
                    _searcheditingcontroller.text = '';
                    _markers = {};
                    _polylines = {};
                  }
                  if (fabKey.currentState!.isOpen) {
                    fabKey.currentState!.close();
                  }
                },
                icon: const Icon(Icons.search, color: Colors.white)),
            IconButton(
                onPressed: () {
                  setState(() {
                    showsearchbar = false;
                    showautocompletesearchbar = true;
                    _autocompletesearcheditingcontroller.clear();
                    _originController.clear();
                    _destinationController.clear();
                    //
                    _searchautocompleteAddr.value = '';
                    _originAddr.value = '';
                    _destinationAddr.value = '';
                    //
                    radiusSlider = false;
                    pressedNear = false;
                    cardTapped = false;
                    getDirections = false;
                  });
                  if (_polylines.isNotEmpty) {
                    _originController.text = '';
                    _destinationController.text = '';
                    _autocompletesearcheditingcontroller.text = '';
                    _searcheditingcontroller.text = '';
                    _markers = {};
                    _polylines = {};
                  }
                  if (fabKey.currentState!.isOpen) {
                    fabKey.currentState!.close();
                  }
                },
                icon: const Icon(
                  Icons.keyboard_hide_sharp,
                  color: Colors.white,
                )),
            IconButton(
              onPressed: () {
                setState(() {
                  showsearchbar = false;
                  showautocompletesearchbar = false;
                  _autocompletesearcheditingcontroller.clear();
                  _originController.clear();
                  _destinationController.clear();
                  //
                  _searchautocompleteAddr.value = '';
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
                  _autocompletesearcheditingcontroller.text = '';
                  _searcheditingcontroller.text = '';
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
          // Request location permission
          var status = await Permission.location.request();
          User? user = FirebaseAuth.instance.currentUser;
          final DatabaseReference dbRef = FirebaseDatabase.instance.ref();
          String? userEmail = user?.email;

          // Request always location permission
          Permission.locationAlways.request();

          if (status.isGranted) {
            // If permission granted, create user and start location tracking
            print('Location permission granted');

            Roam.createUser(
              description: userEmail!,
              callBack: ({user}) async {
                print('User created: $user');

                // Store user data in Firebase
                await dbRef.child('user-locations/').push().set({
                  'email': userEmail,
                  'description': user,
                  "geometry_type": "circle",
                  "geometry_radius": 500,
                  "is_enabled": true,
                  "only_once": true,
                  'timestamp': DateTime.now().toIso8601String(),
                });

                // Set up Moving Geofence
                await createMovingGeofence(userEmail);
              },
            );

            Roam.startTracking(trackingMode: 'active');
          } else {
            print('Location permission denied');
          }
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

  Future<void> createMovingGeofence(String userEmail) async {
    const String url = 'https://api.roam.ai/v1/api/moving-geofence/';
    const String apiKey =
        '10f984325931446ea8e54d6a76c44037'; // Replace with your actual API key

    // Sample geofence data; modify according to your requirements
    final Map<String, dynamic> geofenceData = {
      "geometry_type": "circle",
      "geometry_radius": 500,
      "is_enabled": true,
      "only_once": true
      // Add any other parameters required by the API
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Api-key': apiKey,
        },
        body: jsonEncode(geofenceData),
      );

      if (response.statusCode == 200) {
        print('Moving geofence created successfully: ${response.body}');
      } else {
        print('Failed to create moving geofence: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating moving geofence: $e');
    }
  }

//! Function for normal searchbarin stack
  Positioned searchbar() {
    return Positioned(
      top: 5.0,
      right: 15.0,
      left: 15.0,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        height: 50.0,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5.0),
          color: Colors.white,
        ),
        child: TextField(
          controller: _searcheditingcontroller,
          keyboardType: TextInputType.streetAddress,
          showCursor: true,
          autocorrect: true,
          autofocus: false,
          onEditingComplete: () async {
            FocusScope.of(context).requestFocus(FocusNode());
            GoogleMapController mapController = await _controller.future.then(
              (value) => searchandNavigate(
                value,
                _searcheditingcontroller.text,
                zoom: 14,
              ),
            );
          },
          decoration: InputDecoration(
            hintText: 'Enter Address',
            contentPadding: const EdgeInsets.only(left: 15.0, top: 12.0),
            border: InputBorder.none,
            suffixIcon: TextToSpeech(
              textController: _searcheditingcontroller,
              onSpeechResult: (text) async {
                GoogleMapController mapController =
                    await _controller.future.then(
                  (value) => searchandNavigate(value, text, zoom: 14),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

//!Function for autocomplete searchbar in stack
  Positioned autocompletesearchbar() {
    return Positioned(
      top: 5.0,
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
                valueListenable: _searchautocompleteAddr,
                builder: (BuildContext context, dynamic value, Widget? _) {
                  return TextField(
                    controller: _autocompletesearcheditingcontroller,
                    keyboardType: TextInputType.streetAddress,
                    autofocus: true, //for keyboard focus upon the start
                    textInputAction: TextInputAction
                        .search, //to trigger enter key here search key
                    onEditingComplete: () async {
                      searchandNavigate(await _controller.future, value,
                          zoom: 14);
                      FocusManager.instance.primaryFocus
                          ?.unfocus(); //to hide keyboard upon pressing done
                      _searchautocompleteAddr.value = '';
                    },
                    decoration: InputDecoration(
                        hintText: 'Search Auto Complete..',
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.only(left: 15.0, top: 12.0),
                        suffixIcon: IconButton(
                            icon: value.trim().isNotEmpty
                                ? const Icon(
                                    Icons.search,
                                    size: 20,
                                  )
                                : const Icon(
                                    Icons.close,
                                    size: 20,
                                  ),
                            onPressed: () async {
                              value.trim().isNotEmpty
                                  ? searchandNavigate(
                                      await _controller.future, value,
                                      zoom: 14)
                                  : showautocompletesearchbar = false;
                              FocusManager.instance.primaryFocus
                                  ?.unfocus(); //to hide keyboard upon pressing done
                              _searchautocompleteAddr.value = '';
                              setState(() {
                                //done for showautocompletesearchbar = false above; not for any of the function used inside valuelistablebuilder
                              });
                            },
                            iconSize: 30.0)),
                    onChanged: (val) {
                      //!<<<<debounce
                      if (_debounce?.isActive ?? false) _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 500), () {
                        _searchautocompleteAddr.value = val;
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
    return noreslt == false && _searchautocompleteAddr.value.trim().length >= 2
        ? Positioned(
            top: 70,
            right: 15,
            left: 15,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                color: Colors.red.shade100.withOpacity(0.7),
              ),
              child: FutureBuilder(
                future: onChange(_searchautocompleteAddr.value),
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
                                    _autocompletesearcheditingcontroller.text =
                                        snapshot.data['predictions'][index]
                                                ['description']
                                            .toString();
                                    //!important
                                    FocusScope.of(context).requestFocus(
                                        FocusNode()); //to close the keyboard
                                    searchandNavigate(
                                        await _controller.future,
                                        _autocompletesearcheditingcontroller
                                            .text,
                                        zoom: 14);
                                    _searchautocompleteAddr.value = '';
                                  });
                                },
                                leading: const Icon(
                                  Icons.location_on_outlined,
                                  color: Colors.red,
                                ),
                              );
                            } else {
                              setState(() {
                                if (_searchautocompleteAddr.value
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
            top: 70,
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
                          showautocompletesearchbar = false;
                          _autocompletesearcheditingcontroller.clear();
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
      top: 10.0,
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
            top: 150,
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
            top: 150,
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
            top: 150,
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
            top: 150,
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

//! functction for building review of place tap
  _buildReviewItem(review) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 8.0),
          child: Row(
            children: [
              Container(
                height: 35.0,
                width: 35.0,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                        image: NetworkImage(review['profile_photo_url']),
                        fit: BoxFit.cover)),
              ),
              const SizedBox(width: 4.0),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 160.0,
                  child: Text(
                    review['author_name'],
                    style: const TextStyle(
                        fontSize: 12.0, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 3.0),
                RatingStars(
                  value: review['rating'] * 1.0,
                  starCount: 5,
                  starSize: 7,
                  valueLabelColor: const Color(0xff9b9b9b),
                  valueLabelTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w400,
                      fontStyle: FontStyle.normal,
                      fontSize: 9.0),
                  valueLabelRadius: 7,
                  maxValue: 5,
                  starSpacing: 2,
                  maxValueVisibility: false,
                  valueLabelVisibility: true,
                  animationDuration: const Duration(milliseconds: 1000),
                  valueLabelPadding:
                      const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
                  valueLabelMargin: const EdgeInsets.only(right: 4),
                  starOffColor: const Color(0xffe7e8ea),
                  starColor: Colors.yellow,
                )
              ])
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            child: Text(
              review['text'],
              style:
                  const TextStyle(fontSize: 11.0, fontWeight: FontWeight.w400),
            ),
          ),
        ),
        Divider(color: Colors.grey.shade600, height: 1.0)
      ],
    );
  }

//! functction for building photos of the place tap
  _buildPhotoGallery(photoElement) {
    if (photoElement == null || photoElement.length == 0) {
      showBlankCard = true;
      return Container(
        child: const Center(
          child: Text(
            'No Photos',
            style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500),
          ),
        ),
      );
    } else {
      var placeImg = photoElement[photoGalleryIndex]['photo_reference'];
      var maxWidth = photoElement[photoGalleryIndex]['width'];
      var maxHeight = photoElement[photoGalleryIndex]['height'];
      var tempDisplayIndex = photoGalleryIndex + 1;

      return Column(
        children: [
          const SizedBox(height: 10.0),
          Container(
              height: 200.0,
              width: 200.0,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  image: DecorationImage(
                      image: NetworkImage(
                          'https://maps.googleapis.com/maps/api/place/photo?maxwidth=$maxWidth&maxheight=$maxHeight&photo_reference=$placeImg&key=$google_map_key'),
                      fit: BoxFit.cover))),
          const SizedBox(height: 10.0),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  if (photoGalleryIndex != 0) {
                    photoGalleryIndex = photoGalleryIndex - 1;
                  } else {
                    photoGalleryIndex = 0;
                  }
                });
              },
              child: Container(
                width: 40.0,
                height: 20.0,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9.0),
                    color: photoGalleryIndex != 0
                        ? Colors.green.shade500
                        : Colors.grey.shade500),
                child: const Center(
                  child: Text(
                    'Prev',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.0,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
            Text(
              '$tempDisplayIndex/${photoElement.length}',
              style:
                  const TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  if (photoGalleryIndex != photoElement.length - 1) {
                    photoGalleryIndex = photoGalleryIndex + 1;
                  } else {
                    photoGalleryIndex = photoElement.length - 1;
                  }
                });
              },
              child: Container(
                width: 40.0,
                height: 20.0,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9.0),
                    color: photoGalleryIndex != photoElement.length - 1
                        ? Colors.green.shade500
                        : Colors.grey.shade500),
                child: const Center(
                  child: Text(
                    'Next',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.0,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
          ])
        ],
      );
    }
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

//! functction to extract near by places list
  _nearbyPlacesList(index) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (BuildContext context, Widget? widget) {
        double value = 1;
        if (_pageController.position.haveDimensions) {
          value = (_pageController.page! - index);
          value = (1 - (value.abs() * 0.3) + 0.06).clamp(0.0, 1.0);
        }
        return Center(
          child: SizedBox(
            height: Curves.easeInOut.transform(value) * 125.0,
            width: Curves.easeInOut.transform(value) * 350.0,
            child: widget,
          ),
        );
      },
      child: InkWell(
        onTap: () async {
          cardTapped = !cardTapped;
          if (cardTapped) {
            tappedPlaceDetail = await MapServices()
                .getPlace(allFavoritePlaces[index]['place_id']);
            setState(() {});
          }
          moveCameraSlightly();
        },
        child: Stack(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 20.0,
                ),
                height: 125.0,
                width: 275.0,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.0),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black54,
                          offset: Offset(0.0, 4.0),
                          blurRadius: 10.0)
                    ]),
                child: Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10.0),
                      color: Colors.white),
                  child: Row(
                    children: [
                      _pageController.position.haveDimensions
                          ? _pageController.page!.toInt() == index
                              ? Container(
                                  height: 90.0,
                                  width: 90.0,
                                  decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(10.0),
                                        topLeft: Radius.circular(10.0),
                                      ),
                                      image: DecorationImage(
                                          image: NetworkImage(placeImg != ''
                                              ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=$placeImg&key=$google_map_key'
                                              : 'https://pic.onlinewebfonts.com/svg/img_546302.png'),
                                          fit: BoxFit.cover)),
                                )
                              : Container(
                                  height: 90.0,
                                  width: 20.0,
                                  decoration: const BoxDecoration(
                                      borderRadius: BorderRadius.only(
                                        bottomLeft: Radius.circular(10.0),
                                        topLeft: Radius.circular(10.0),
                                      ),
                                      color: Colors.blue),
                                )
                          : Container(),
                      const SizedBox(width: 5.0),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 170.0,
                            child: Text(allFavoritePlaces[index]['name'],
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold)),
                          ),
                          RatingStars(
                            value: allFavoritePlaces[index]['rating']
                                        .runtimeType ==
                                    int
                                ? allFavoritePlaces[index]['rating'] * 1.0
                                : allFavoritePlaces[index]['rating'] ?? 0.0,
                            starCount: 5,
                            starSize: 10,
                            valueLabelColor: const Color(0xff9b9b9b),
                            valueLabelTextStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w400,
                                fontStyle: FontStyle.normal,
                                fontSize: 12.0),
                            valueLabelRadius: 10,
                            maxValue: 5,
                            starSpacing: 2,
                            maxValueVisibility: false,
                            valueLabelVisibility: true,
                            animationDuration:
                                const Duration(milliseconds: 1000),
                            valueLabelPadding: const EdgeInsets.symmetric(
                                vertical: 1, horizontal: 8),
                            valueLabelMargin: const EdgeInsets.only(right: 8),
                            starOffColor: const Color(0xffe7e8ea),
                            starColor: Colors.yellow,
                          ),
                          SizedBox(
                            width: 170.0,
                            child: Text(
                              allFavoritePlaces[index]['business_status'] ??
                                  'none',
                              style: TextStyle(
                                  color: allFavoritePlaces[index]
                                              ['business_status'] ==
                                          'OPERATIONAL'
                                      ? Colors.green
                                      : Colors.red,
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w700),
                            ),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

//! functction to go to tapped place on page viewer
  Future<void> goToTappedPlace() async {
    final GoogleMapController controller = await _controller.future;

    _markers = {};

    var selectedPlace = allFavoritePlaces[_pageController.page!.toInt()];

    _setNearMarker(
        LatLng(selectedPlace['geometry']['location']['lat'],
            selectedPlace['geometry']['location']['lng']),
        selectedPlace['name'] ?? 'no name',
        selectedPlace['types'],
        selectedPlace['business_status'] ?? 'none');

    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(selectedPlace['geometry']['location']['lat'],
            selectedPlace['geometry']['location']['lng']),
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

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GoogleMapScreen extends ConsumerStatefulWidget {
  const GoogleMapScreen({super.key});

  @override
  ConsumerState<GoogleMapScreen> createState() => _GoogleMapScreenState();
}

class _GoogleMapScreenState extends ConsumerState<GoogleMapScreen> {
  bool _isExpanded = false; // Track whether the container is expanded or not
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _autocompletesearcheditingcontroller =
      TextEditingController();
  final Completer<GoogleMapController> _controller = Completer();
  final ValueNotifier<String> _searchautocompleteAddr =
      ValueNotifier<String>('');
  final String google_map_key = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  bool showautocompletesearchbar = false;
  Timer? _debounce;
  bool noreslt = false;
  Set<Marker> _markers = <Marker>{};
  Set<Marker> _markersDupe = <Marker>{};
  String _sessionToken = '122344';
//initial marker count value
  int markerIdCounter = 1;
  var uuid = const Uuid();
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

  // Sample recent destinations (replace with your actual data)
  final List<String> _recentDestinations = [
    "Times Square, New York",
    "Golden Gate Bridge, San Francisco",
    "Eiffel Tower, Paris"
  ];

  onChange(String inputvalue) {
    if (_sessionToken.isEmpty) {
      _sessionToken = uuid.v4();
    }
    //return getSuggestion(_autocompletesearcheditingcontroller.text);//correct when used withoutdebounce
    return getSuggestion(
        inputvalue); //correct both with debounce and withoutdebounce
  }

  getSuggestion(String input) async {
    // Handle the case where the API key might be missing
    if (google_map_key.isEmpty) {
      throw Exception('Google Maps API key is missing');
    }

    String baseURL =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json';
    String request =
        '$baseURL?input=$input&key=$google_map_key&sessiontoken=$_sessionToken';
    var response = await http.get(Uri.parse(request));

    if (response.statusCode == 200) {
      var placesdata =
          jsonDecode(response.body); // Directly decode the response
      return placesdata;
    } else {
      throw Exception('Error loading autocomplete data');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            color: Colors.blueGrey,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              height: _isExpanded ? 400 : 150, // Expand height on arrow tap
              decoration: BoxDecoration(
                color: const Color.fromARGB(183, 255, 0, 0).withOpacity(1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.all(10.0),
              child: Column(
                children: [
                  IconButton(
                    icon: Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      color: Colors.white,
                      size: 25,
                    ),
                    onPressed: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 0.0),
                    child: TextField(
                      controller: _destinationController,
                      decoration: InputDecoration(
                        hintText: "Enter destination",
                        hintStyle: const TextStyle(color: Colors.white),
                        filled: true,
                        fillColor: Colors.white24,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(15),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  if (_isExpanded)
                    ValueListenableBuilder(
                      valueListenable: _searchautocompleteAddr,
                      builder:
                          (BuildContext context, dynamic value, Widget? _) {
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
                            if (_debounce?.isActive ?? false)
                              _debounce?.cancel();
                            _debounce =
                                Timer(const Duration(milliseconds: 500), () {
                              _searchautocompleteAddr.value = val;
                            });
                            //!debounce>>>>
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
}

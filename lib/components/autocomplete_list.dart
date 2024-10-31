import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AutoCompleteList extends StatefulWidget {
  final ValueNotifier<String> searchValueNotifier;
  final TextEditingController searchEditingController;
  final Future<dynamic> Function(String value) onSearchChange;
  final Future<GoogleMapController> Function() controllerFuture;
  final Function(GoogleMapController, String, {double zoom}) searchAndNavigate;
  final bool noResult;
  final double zoom;

  const AutoCompleteList({
    super.key,
    required this.searchValueNotifier,
    required this.searchEditingController,
    required this.onSearchChange,
    required this.controllerFuture,
    required this.searchAndNavigate,
    this.noResult = false,
    this.zoom = 14.0,
  });

  @override
  _AutoCompleteListState createState() => _AutoCompleteListState();
}

class _AutoCompleteListState extends State<AutoCompleteList> {
  bool showAutocompleteSearchBar = true;

  @override
  Widget build(BuildContext context) {
    return widget.noResult == false &&
            widget.searchValueNotifier.value.trim().length >= 2
        ? Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.0),
              color: Colors.red.shade100.withOpacity(0.7),
            ),
            child: FutureBuilder(
              future: widget.onSearchChange(widget.searchValueNotifier.value),
              builder: (BuildContext context, AsyncSnapshot snapshot) {
                if (snapshot.hasData) {
                  return ListView.builder(
                    itemCount: snapshot.data['predictions'].length ?? 3,
                    padding: const EdgeInsets.only(top: 0, right: 0),
                    itemBuilder: (BuildContext context, int index) {
                      return ListTile(
                        title: Text(
                          snapshot.data['predictions'][index]['description']
                              .toString(),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        onTap: () async {
                          widget.searchEditingController.text = snapshot
                              .data['predictions'][index]['description']
                              .toString();
                          FocusScope.of(context).requestFocus(FocusNode());
                          widget.searchAndNavigate(
                            await widget.controllerFuture(),
                            widget.searchEditingController.text,
                            zoom: widget.zoom,
                          );
                          widget.searchValueNotifier.value = '';
                        },
                        leading: const Icon(
                          Icons.location_on_outlined,
                          color: Colors.red,
                        ),
                      );
                    },
                  );
                } else if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                } else {
                  return const Center(
                    child: Text("Error loading results"),
                  );
                }
              },
            ),
          )
        : _noResultsWidget();
  }

  Widget _noResultsWidget() {
    return Container(
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
                Icons.close,
                color: Colors.black,
              ),
              onPressed: () {
                setState(() {
                  showAutocompleteSearchBar = false;
                  widget.searchEditingController.clear();
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
                  style: TextStyle(fontWeight: FontWeight.w400),
                ),
                SizedBox(height: 5.0),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

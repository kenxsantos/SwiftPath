import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:swiftpath/pages/text_to_speech.dart';

class SearchAutoComplete extends StatelessWidget {
  final ValueNotifier<String> searchAutocompleteAddr;
  final TextEditingController searchEditingController;
  final Future<GoogleMapController> Function() controllerFuture;
  final Function(GoogleMapController, String, {double zoom}) searchAndNavigate;
  final Timer? debounce;

  const SearchAutoComplete({
    Key? key,
    required this.searchAutocompleteAddr,
    required this.searchEditingController,
    required this.controllerFuture,
    required this.searchAndNavigate,
    this.debounce,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          width: double.infinity,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5.0), color: Colors.white),
          child: SizedBox(
            height: 50.0,
            child: ValueListenableBuilder(
              valueListenable: searchAutocompleteAddr,
              builder: (BuildContext context, dynamic value, Widget? _) {
                return TextField(
                  controller: searchEditingController,
                  keyboardType: TextInputType.streetAddress,
                  autofocus: true, // for keyboard focus upon start
                  textInputAction: TextInputAction.search, // triggers search
                  onEditingComplete: () async {
                    GoogleMapController mapController =
                        await controllerFuture();
                    searchAndNavigate(mapController, value, zoom: 14);
                    FocusManager.instance.primaryFocus?.unfocus();
                    searchAutocompleteAddr.value = '';
                  },
                  decoration: InputDecoration(
                    hintText: 'Search Auto Complete..',
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.only(left: 15.0, top: 12.0),
                    suffixIcon: TextToSpeech(
                      textController: searchEditingController,
                      onSpeechResult: (text) async {
                        GoogleMapController mapController =
                            await controllerFuture();
                        searchAndNavigate(mapController, text, zoom: 14);
                      },
                    ),
                  ),
                  onChanged: (val) {
                    if (debounce?.isActive ?? false) debounce?.cancel();
                    Timer(const Duration(milliseconds: 500), () {
                      searchAutocompleteAddr.value = val;
                    });
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

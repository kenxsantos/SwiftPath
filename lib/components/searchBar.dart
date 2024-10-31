import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:swiftpath/views/maps_page.dart';
import 'package:swiftpath/pages/text_to_speech.dart';

class AutoCompleteSearchBar extends StatelessWidget {
  final TextEditingController textController;
  final ValueNotifier<String> searchNotifier;
  final Future<void> Function(String query) onSearch;
  final Duration debounceDuration;
  final void Function(String) onSpeechResult;
  final Completer<GoogleMapController> _controller = Completer();
  AutoCompleteSearchBar({
    super.key,
    required this.textController,
    required this.searchNotifier,
    required this.onSearch,
    required this.onSpeechResult,
    this.debounceDuration = const Duration(milliseconds: 500),
  });

  Timer? _debounce;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5.0),
        color: Colors.white,
      ),
      child: SizedBox(
        height: 50.0,
        child: ValueListenableBuilder(
          valueListenable: searchNotifier,
          builder: (BuildContext context, dynamic value, Widget? _) {
            return TextField(
              controller: textController,
              keyboardType: TextInputType.streetAddress,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onEditingComplete: () async {
                await onSearch(value);
                FocusManager.instance.primaryFocus?.unfocus();
                searchNotifier.value = '';
              },
              // decoration: InputDecoration(
              //   hintText: 'Search Auto Complete..',
              //   border: InputBorder.none,
              //   contentPadding: const EdgeInsets.only(left: 15.0, top: 12.0),
              //   suffixIcon: TextToSpeech(
              //     textController: textController,
              //     onSpeechResult: (text) async {
              //       GoogleMapController mapController =
              //           await _controller.future;
              //       await searchAndNavigate(mapController, text, zoom: 14);
              //     },
              //   ),
              // ),
              onChanged: (val) {
                if (_debounce?.isActive ?? false) _debounce?.cancel();
                _debounce = Timer(debounceDuration, () {
                  searchNotifier.value = val;
                });
              },
            );
          },
        ),
      ),
    );
  }
}

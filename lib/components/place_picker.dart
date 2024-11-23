import 'package:flutter/material.dart';
import 'package:google_places_autocomplete_text_field/google_places_autocomplete_text_field.dart';
import 'package:google_places_autocomplete_text_field/model/prediction.dart';

class PlacePicker extends StatelessWidget {
  final String apiKey;
  final String labelText;
  final Function(Prediction) onPlaceSelected;
  final TextEditingController controller;

  const PlacePicker({
    super.key,
    required this.apiKey,
    required this.labelText,
    required this.onPlaceSelected,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return GooglePlacesAutoCompleteTextFormField(
      countries: const ["ph"],
      textEditingController: controller,
      googleAPIKey: apiKey,
      decoration: InputDecoration(
        hintText: 'Enter $labelText',
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.purple),
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value!.isEmpty) {
          return 'Please enter a valid $labelText';
        }
        return null;
      },
      maxLines: 1,
      overlayContainer: (child) => Material(
        elevation: 1.0,
        color: Colors.green,
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
      getPlaceDetailWithLatLng: (prediction) {
        // Debugging details (optional).
        print('Selected Place Details: ${prediction.lng}');
      },
      itmClick: (Prediction prediction) {
        onPlaceSelected(prediction);
        controller.text = prediction.description!;
      },
    );
  }
}

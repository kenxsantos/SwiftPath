import 'package:flutter/material.dart';

class DestinationAutoCompleteListFalse extends StatefulWidget {
  final VoidCallback onClose;
  final String message;

  const DestinationAutoCompleteListFalse({
    super.key,
    required this.onClose,
    this.message = 'No results to show',
  });

  @override
  _DestinationAutoCompleteListFalseState createState() =>
      _DestinationAutoCompleteListFalseState();
}

class _DestinationAutoCompleteListFalseState
    extends State<DestinationAutoCompleteListFalse> {
  @override
  Widget build(BuildContext context) {
    return Container(
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
                widget.onClose(); // Call the provided callback
              },
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.message,
                  style: const TextStyle(
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 5.0),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

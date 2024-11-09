import 'package:flutter/material.dart';

class OriginAutocompleteListFalse extends StatelessWidget {
  final VoidCallback onClose;
  final Future<void> Function() onUseCurrentLocation;

  const OriginAutocompleteListFalse({
    super.key,
    required this.onClose,
    required this.onUseCurrentLocation,
  });

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
              icon: const Icon(Icons.close, color: Colors.black),
              onPressed: onClose,
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    await onUseCurrentLocation();
                    FocusManager.instance.primaryFocus?.nextFocus();
                  },
                  child: Container(
                    height: 45,
                    padding: const EdgeInsets.all(5),
                    margin:
                        const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white60,
                      borderRadius: BorderRadius.circular(10.0),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.grey,
                          offset: Offset(0.0, 1.0),
                          blurRadius: 3.0,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.my_location_rounded,
                            color: Colors.black45, size: 20),
                        Text(
                          " Use your location",
                          style: TextStyle(
                              color: Colors.black, fontWeight: FontWeight.w500),
                        ),
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
    );
  }
}

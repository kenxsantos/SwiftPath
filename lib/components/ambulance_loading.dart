import 'package:flutter/material.dart';

class AmbulanceLoadingIndicator extends StatefulWidget {
  const AmbulanceLoadingIndicator({super.key});

  @override
  State<AmbulanceLoadingIndicator> createState() =>
      _AmbulanceLoadingIndicatorState();
}

class _AmbulanceLoadingIndicatorState extends State<AmbulanceLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Image.asset(
        'assets/images/ambulance.png',
        width: 30,
        height: 30,
      ),
    );
  }
}

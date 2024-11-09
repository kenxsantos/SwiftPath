import 'package:flutter/material.dart';
import 'package:swiftpath/services/map_services.dart';

class DestinationAutoCompleteListTrue extends StatefulWidget {
  final ValueNotifier<String> destinationAddr;
  final TextEditingController destinationController;
  final TextEditingController originController;
  final Future<dynamic> Function(String value) onChange;
  final Function gotoPlace;
  final Function setPolyline;
  final MapServices mapServices;

  const DestinationAutoCompleteListTrue({
    super.key,
    required this.destinationAddr,
    required this.destinationController,
    required this.originController,
    required this.onChange,
    required this.gotoPlace,
    required this.setPolyline,
    required this.mapServices,
  });

  @override
  _DestinationAutoCompleteListTrueState createState() =>
      _DestinationAutoCompleteListTrueState();
}

class _DestinationAutoCompleteListTrueState
    extends State<DestinationAutoCompleteListTrue> {
  bool destinationNoResult = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.0),
        color: Colors.red.shade100.withOpacity(0.7),
      ),
      child: FutureBuilder(
        future: widget.onChange(widget.destinationAddr.value),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
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
              ),
            );
          } else if (snapshot.hasData && snapshot.data['predictions'] != null) {
            return ListView.builder(
              itemCount: snapshot.data['predictions'].length,
              padding: const EdgeInsets.only(top: 0, right: 0),
              itemBuilder: (BuildContext context, int index) {
                final prediction = snapshot.data['predictions'][index];
                return ListTile(
                  title: Text(
                    prediction['description'].toString(),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () async {
                    widget.destinationController.text =
                        prediction['description'].toString();
                    var directions = await widget.mapServices.getDirections(
                      widget.originController.text,
                      widget.destinationController.text,
                    );

                    widget.gotoPlace(
                      directions['start_location']['lat'],
                      directions['start_location']['lng'],
                      directions['end_location']['lat'],
                      directions['end_location']['lng'],
                      directions['bounds_ne'],
                      directions['bounds_sw'],
                    );

                    widget.setPolyline(directions['polyline_decoded']);
                    FocusManager.instance.primaryFocus?.unfocus();

                    widget.destinationAddr.value = '';

                    setState(() {});
                  },
                  leading: const Icon(
                    Icons.location_on_outlined,
                    color: Colors.red,
                  ),
                );
              },
            );
          } else {
            return const Center(
              child: Text(
                'No results to show',
                style: TextStyle(fontWeight: FontWeight.w400),
              ),
            );
          }
        },
      ),
    );
  }
}

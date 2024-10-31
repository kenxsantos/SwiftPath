import 'package:flutter/material.dart';

class OriginAutoCompleteListTrue extends StatefulWidget {
  final ValueNotifier<String> searchValueNotifier;
  final Future<dynamic> Function(String value) futureData;
  final TextEditingController textController;
  final Function(String) onSelectItem;

  const OriginAutoCompleteListTrue({
    super.key,
    required this.searchValueNotifier,
    required this.futureData,
    required this.textController,
    required this.onSelectItem,
  });

  @override
  _OriginAutoCompleteListState createState() => _OriginAutoCompleteListState();
}

class _OriginAutoCompleteListState extends State<OriginAutoCompleteListTrue> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.0),
        color: Colors.red.shade100.withOpacity(0.7),
      ),
      child: FutureBuilder(
        future: widget.futureData(widget.searchValueNotifier.value),
        builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text("Loading...", textScaleFactor: 1.5),
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
                  onTap: () {
                    widget.onSelectItem(prediction['description']);
                    FocusManager.instance.primaryFocus?.nextFocus();
                  },
                  leading:
                      const Icon(Icons.location_on_outlined, color: Colors.red),
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

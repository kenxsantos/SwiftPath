import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart' as flutter_html;

class RoutesPopup extends StatelessWidget {
  final List<Map<String, dynamic>> routes;
  final Function(String polyline) onRouteSelected;

  const RoutesPopup({
    Key? key,
    required this.routes,
    required this.onRouteSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Available Routes",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: routes.length,
                itemBuilder: (context, index) {
                  final route = routes[index];
                  return Card(
                    margin: const EdgeInsets.all(5.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    elevation: 6.0,
                    child: ExpansionTile(
                      title: Text(
                        route['summary'] ?? 'No summary available',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Distance: ${route['distance'] ?? 'N/A'}, Duration: ${route['duration'] ?? 'N/A'}',
                      ),
                      children: [
                        ListTile(
                          onTap: () => {
                            onRouteSelected(route['overview_polyline']),
                            Navigator.of(context).pop(),
                          },
                          title: const Text(
                            'Select Route',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ListTile(
                          title: Text(
                            'Start: ${route['start_address']}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        ListTile(
                          title: Text(
                            'Destination: ${route['end_address']}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const Divider(),
                        ...route['steps'].map<Widget>((step) {
                          return Column(
                            children: [
                              ListTile(
                                title: flutter_html.Html(
                                  data: step['instruction'] ?? 'No instruction',
                                ),
                                subtitle: Text(
                                  '  Distance: ${step['distance']}, Duration: ${step['duration']}',
                                ),
                              ),
                              const Divider(),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Close"),
            ),
          ],
        ),
      ),
    );
  }
}

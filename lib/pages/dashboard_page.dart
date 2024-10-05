import 'package:flutter/material.dart';
import 'package:swiftpath/pages/incident_report.dart';
import 'package:swiftpath/pages/settings_page.dart';
import 'package:swiftpath/views/maps_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  static String id = 'dashboard_page';

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: 1, // Set the default tab to Map Screen (index 1)
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 10,
          automaticallyImplyLeading: false,
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(
                  Icons.settings,
                  size: 20,
                ),
                text: 'Settings',
              ),
              Tab(
                  icon: Icon(
                    Icons.map,
                    size: 20,
                  ),
                  text: 'Map'),
              Tab(
                  icon: Icon(
                    Icons.report,
                    size: 20,
                  ),
                  text: 'Reports'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SettingsPage(),
            MapScreen(),
            IncidentReportPage(),
          ],
        ),
      ),
    );
  }
}

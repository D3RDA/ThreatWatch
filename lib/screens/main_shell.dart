import 'package:flutter/material.dart';

import 'ai_coach_screen.dart';
import 'dashboard_screen.dart';
import 'face_registry_screen.dart';
import 'history_screen.dart';
import 'image_location_screen.dart';
import 'quick_checks_screen.dart';
import 'saved_cves_screen.dart';
import 'scanner_screen.dart';
import 'threat_feed_screen.dart';

enum AppSection {
  dashboard,
  threatFeed,
  savedCves,
  scanner,
  quickChecks,
  aiCoach,
  faceRegistry,
  imageLocation,
  history,
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  AppSection _selected = AppSection.dashboard;

  String get _title {
    switch (_selected) {
      case AppSection.dashboard:
        return 'ThreatWatch AI';
      case AppSection.threatFeed:
        return 'Aktuális sebezhetőségek';
      case AppSection.savedCves:
        return 'Mentett CVE-k';
      case AppSection.scanner:
        return 'QR / URL scanner';
      case AppSection.quickChecks:
        return 'Gyors ellenőrzések';
      case AppSection.aiCoach:
        return 'AI coach';
      case AppSection.faceRegistry:
        return 'Arc-regiszter';
      case AppSection.imageLocation:
        return 'Kép helyének becslése';
      case AppSection.history:
        return 'Előzmények és statisztika';
    }
  }

  Widget get _body {
    switch (_selected) {
      case AppSection.dashboard:
        return const DashboardScreen();
      case AppSection.threatFeed:
        return const ThreatFeedScreen();
      case AppSection.savedCves:
        return const SavedCvesScreen();
      case AppSection.scanner:
        return const ScannerScreen();
      case AppSection.quickChecks:
        return const QuickChecksScreen();
      case AppSection.aiCoach:
        return const AiCoachScreen();
      case AppSection.faceRegistry:
        return const FaceRegistryScreen();
      case AppSection.imageLocation:
        return const ImageLocationScreen();
      case AppSection.history:
        return const HistoryScreen();
    }
  }

  void _select(AppSection section) {
    Navigator.of(context).maybePop();
    setState(() {
      _selected = section;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ThreatWatch AI',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text('Kiberbiztonsági dashboard, scanner és AI coach'),
                  ],
                ),
              ),
              const Divider(),
              _drawerTile(AppSection.dashboard, Icons.dashboard_outlined, 'Dashboard'),
              _drawerTile(AppSection.threatFeed, Icons.security_outlined, 'Sebezhetőségek'),
              _drawerTile(AppSection.savedCves, Icons.bookmarks_outlined, 'Mentett CVE-k'),
              _drawerTile(AppSection.scanner, Icons.qr_code_scanner_outlined, 'QR / URL scanner'),
              _drawerTile(AppSection.quickChecks, Icons.rule_folder_outlined, 'Gyors ellenőrzések'),
              _drawerTile(AppSection.aiCoach, Icons.psychology_alt_outlined, 'AI coach'),
              _drawerTile(AppSection.faceRegistry, Icons.face_retouching_natural_outlined, 'Arc-regiszter'),
              _drawerTile(AppSection.imageLocation, Icons.place_outlined, 'Kép helyének becslése'),
              _drawerTile(AppSection.history, Icons.bar_chart_outlined, 'Előzmények és statisztika'),
            ],
          ),
        ),
      ),
      body: SafeArea(child: _body),
    );
  }

  Widget _drawerTile(AppSection section, IconData icon, String title) {
    return ListTile(
      selected: _selected == section,
      leading: Icon(icon),
      title: Text(title),
      onTap: () => _select(section),
    );
  }
}

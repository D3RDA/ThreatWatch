import 'package:flutter/material.dart';

import 'screens/main_shell.dart';

void main() {
  runApp(const ThreatWatchApp());
}

class ThreatWatchApp extends StatelessWidget {
  const ThreatWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ThreatWatch AI',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const MainShell(),
    );
  }
}

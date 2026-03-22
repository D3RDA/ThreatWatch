import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/threat_assessment.dart';
import '../services/heuristic_analysis_service.dart';
import '../services/local_storage_service.dart';
import '../services/safe_browsing_service.dart';
import '../widgets/risk_badge.dart';

enum ScanMode { manual, qr }

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _urlController = TextEditingController();
  final _safeBrowsingService = SafeBrowsingService();
  final _heuristics = HeuristicAnalysisService();
  final _storage = LocalStorageService.instance;
  final _scannerController = MobileScannerController();

  ScanMode _mode = ScanMode.manual;
  ThreatAssessment? _result;
  bool _loading = false;
  bool _processingQr = false;

  @override
  void dispose() {
    _urlController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _analyze(String rawUrl) async {
    final url = rawUrl.trim();
    if (url.isEmpty) {
      return;
    }

    setState(() {
      _loading = true;
    });

    final safeBrowsing = await _safeBrowsingService.checkUrl(url);
    final result = _heuristics.analyzeUrl(url, safeBrowsing);
    await _storage.addHistoryItem(result.toHistoryItem());

    if (!mounted) {
      return;
    }

    setState(() {
      _result = result;
      _loading = false;
    });
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_processingQr) {
      return;
    }

    final rawValue = capture.barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) {
      return;
    }

    _processingQr = true;
    _urlController.text = rawValue;
    await _scannerController.stop();
    await _analyze(rawValue);
    _processingQr = false;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scanner mód',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                SegmentedButton<ScanMode>(
                  segments: const [
                    ButtonSegment(
                      value: ScanMode.manual,
                      label: Text('Kézi URL'),
                      icon: Icon(Icons.link),
                    ),
                    ButtonSegment(
                      value: ScanMode.qr,
                      label: Text('QR kamera'),
                      icon: Icon(Icons.qr_code_scanner),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (selection) async {
                    final next = selection.first;
                    setState(() {
                      _mode = next;
                    });
                    if (next == ScanMode.qr) {
                      await _scannerController.start();
                    } else {
                      await _scannerController.stop();
                    }
                  },
                ),
                const SizedBox(height: 16),
                if (_mode == ScanMode.manual) ...[
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'URL',
                      hintText: 'https://example.com/login',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.public),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : () => _analyze(_urlController.text),
                    icon: const Icon(Icons.search),
                    label: const Text('Ellenőrzés'),
                  ),
                ] else ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 320,
                      child: MobileScanner(
                        controller: _scannerController,
                        onDetect: _handleDetection,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Olvass be egy QR-kódot. Az app kinyeri az URL-t, lefuttatja a helyi heurisztikát, és ha megadsz Google Safe Browsing kulcsot, akkor külső egyeztetést is végez.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _scannerController.start(),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Kamera indítása'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _scannerController.stop(),
                        icon: const Icon(Icons.pause),
                        label: const Text('Kamera megállítása'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_result != null) ...[
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Eredmény',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      RiskBadge(level: _result!.level),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SelectableText(_result!.input),
                  const SizedBox(height: 8),
                  Text('Pontszám: ${_result!.score}/100'),
                  Text('Forrás: ${_result!.source}'),
                  const SizedBox(height: 10),
                  Text(
                    _result!.summary,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  ..._result!.reasons.map(
                    (reason) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(child: Text(reason)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

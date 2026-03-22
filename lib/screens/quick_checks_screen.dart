import 'package:flutter/material.dart';

import '../models/password_strength_result.dart';
import '../models/security_checklist.dart';
import '../models/threat_assessment.dart';
import '../services/heuristic_analysis_service.dart';
import '../services/local_storage_service.dart';
import '../widgets/risk_badge.dart';

class QuickChecksScreen extends StatefulWidget {
  const QuickChecksScreen({super.key});

  @override
  State<QuickChecksScreen> createState() => _QuickChecksScreenState();
}

class _QuickChecksScreenState extends State<QuickChecksScreen> {
  final _passwordController = TextEditingController();
  final _messageController = TextEditingController();
  final _heuristics = HeuristicAnalysisService();
  final _storage = LocalStorageService.instance;

  PasswordStrengthResult? _passwordResult;
  ThreatAssessment? _messageResult;
  SecurityChecklist _checklist = SecurityChecklist.empty();
  bool _loadingChecklist = true;

  @override
  void initState() {
    super.initState();
    _loadChecklist();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadChecklist() async {
    final checklist = await _storage.loadChecklist();
    if (!mounted) {
      return;
    }
    setState(() {
      _checklist = checklist;
      _loadingChecklist = false;
    });
  }

  Future<void> _updateChecklist(SecurityChecklist next) async {
    setState(() {
      _checklist = next;
    });
    await _storage.saveChecklist(next);
  }

  Future<void> _analyzeMessage() async {
    final input = _messageController.text.trim();
    if (input.isEmpty) {
      return;
    }
    final result = _heuristics.analyzeMessage(input);
    await _storage.addHistoryItem(result.toHistoryItem());
    if (!mounted) {
      return;
    }
    setState(() {
      _messageResult = result;
    });
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
                  'Jelszóerősség ellenőrző',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  onChanged: (value) {
                    setState(() {
                      _passwordResult = _heuristics.evaluatePassword(value);
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Írj be egy jelszót',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.password),
                  ),
                ),
                const SizedBox(height: 12),
                if (_passwordResult != null) ...[
                  LinearProgressIndicator(value: _passwordResult!.score / 100),
                  const SizedBox(height: 8),
                  Text('Eredmény: ${_passwordResult!.label} (${_passwordResult!.score}/100)'),
                  const SizedBox(height: 8),
                  ..._passwordResult!.feedback.map((item) => Text('• $item')),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phishing szöveg ellenőrző',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _messageController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Illessz be emailt vagy üzenetet',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _analyzeMessage,
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Szöveg elemzése'),
                ),
                if (_messageResult != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _messageResult!.summary,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      RiskBadge(level: _messageResult!.level),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Pontszám: ${_messageResult!.score}/100'),
                  const SizedBox(height: 8),
                  ..._messageResult!.reasons.map((item) => Text('• $item')),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _loadingChecklist
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cyber hygiene checklist',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text('Teljesítve: ${_checklist.completedCount}/6'),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _checklist.progress),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: _checklist.twoFactorEnabled,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('2FA be van kapcsolva a fontos fiókokon'),
                        onChanged: (value) => _updateChecklist(
                          _checklist.copyWith(twoFactorEnabled: value ?? false),
                        ),
                      ),
                      CheckboxListTile(
                        value: _checklist.deviceUpdated,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Az eszközeim naprakészek'),
                        onChanged: (value) => _updateChecklist(
                          _checklist.copyWith(deviceUpdated: value ?? false),
                        ),
                      ),
                      CheckboxListTile(
                        value: _checklist.uniquePasswords,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Egyedi jelszavakat használok'),
                        onChanged: (value) => _updateChecklist(
                          _checklist.copyWith(uniquePasswords: value ?? false),
                        ),
                      ),
                      CheckboxListTile(
                        value: _checklist.backupsEnabled,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Van mentési stratégiám'),
                        onChanged: (value) => _updateChecklist(
                          _checklist.copyWith(backupsEnabled: value ?? false),
                        ),
                      ),
                      CheckboxListTile(
                        value: _checklist.screenLockEnabled,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Erős képernyőzárat használok'),
                        onChanged: (value) => _updateChecklist(
                          _checklist.copyWith(screenLockEnabled: value ?? false),
                        ),
                      ),
                      CheckboxListTile(
                        value: _checklist.publicWifiCareful,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Óvatos vagyok nyilvános Wi-Fi-n'),
                        onChanged: (value) => _updateChecklist(
                          _checklist.copyWith(publicWifiCareful: value ?? false),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

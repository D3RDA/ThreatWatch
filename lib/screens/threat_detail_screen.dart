import 'package:flutter/material.dart';

import '../models/cve_detail.dart';
import '../models/saved_cve_entry.dart';
import '../models/vulnerability_item.dart';
import '../services/ai_coach_service.dart';
import '../services/local_storage_service.dart';
import '../services/nvd_service.dart';
import '../utils/formatters.dart';

const _cveStatuses = [
  'Új',
  'Ellenőrizendő',
  'Érint minket',
  'Javítás alatt',
  'Megoldva',
  'Nem releváns',
];

const _cvePriorities = ['Alacsony', 'Közepes', 'Magas', 'Kritikus'];

class ThreatDetailScreen extends StatefulWidget {
  final VulnerabilityItem item;

  const ThreatDetailScreen({super.key, required this.item});

  @override
  State<ThreatDetailScreen> createState() => _ThreatDetailScreenState();
}

class _ThreatDetailScreenState extends State<ThreatDetailScreen> {
  final _nvdService = NvdService();
  final _coachService = AiCoachService();
  final _storage = LocalStorageService.instance;

  late Future<CveDetail?> _detailFuture;
  String? _coachText;
  bool _coachLoading = false;
  bool _saved = false;
  SavedCveEntry? _entry;

  @override
  void initState() {
    super.initState();
    _detailFuture = _nvdService.fetchCveDetail(widget.item.cveId);
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    final entry = await _storage.getSavedCveEntry(widget.item.cveId);
    if (!mounted) {
      return;
    }
    setState(() {
      _entry = entry;
      _saved = entry != null;
    });
  }

  Future<void> _toggleSaved() async {
    final saved = await _storage.toggleSavedCve(widget.item.cveId);
    final entry = await _storage.getSavedCveEntry(widget.item.cveId);
    if (!mounted) {
      return;
    }
    setState(() {
      _saved = saved;
      _entry = entry;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved ? '${widget.item.cveId} elmentve.' : '${widget.item.cveId} eltávolítva.'),
      ),
    );
  }

  Future<void> _editTrackerInfo() async {
    final current = _entry ?? SavedCveEntry.empty(widget.item.cveId);
    final noteController = TextEditingController(text: current.note);
    String selectedStatus = current.status;
    String selectedPriority = current.priority;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CVE megjegyzés és státusz',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Saját megjegyzés',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Státusz',
                        border: OutlineInputBorder(),
                      ),
                      items: _cveStatuses
                          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setSheetState(() {
                          selectedStatus = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedPriority,
                      decoration: const InputDecoration(
                        labelText: 'Prioritás',
                        border: OutlineInputBorder(),
                      ),
                      items: _cvePriorities
                          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setSheetState(() {
                          selectedPriority = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Mégse'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final entry = SavedCveEntry(
                              cveId: widget.item.cveId,
                              note: noteController.text.trim(),
                              status: selectedStatus,
                              priority: selectedPriority,
                              updatedAt: DateTime.now(),
                            );
                            await _storage.upsertSavedCveEntry(entry);
                            if (!context.mounted) {
                              return;
                            }
                            Navigator.pop(context, true);
                          },
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Mentés'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    noteController.dispose();

    if (result == true) {
      await _loadSavedState();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A CVE megjegyzése és státusza elmentve.')),
      );
    }
  }

  Future<void> _loadCoach() async {
    setState(() {
      _coachLoading = true;
    });

    final text = await _coachService.getAdvice(
      input:
          '${widget.item.cveId} ${widget.item.vendorProject} ${widget.item.product} ${widget.item.shortDescription} ${widget.item.requiredAction}',
      context: 'vulnerability_explanation',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _coachText = text;
      _coachLoading = false;
    });
  }

  List<String> _todoSteps(VulnerabilityItem item, CveDetail? detail) {
    final steps = <String>[];
    if (item.requiredAction.isNotEmpty) {
      steps.add(item.requiredAction);
    }
    if (item.dueDate != null) {
      steps.add('Ütemezd a frissítést legkésőbb eddig: ${formatDate(item.dueDate)}.');
    }
    if (detail?.baseScore != null && (detail!.baseScore ?? 0) >= 8.0) {
      steps.add('Ez magas CVSS érték, ezért kezeld elsődleges prioritással.');
    }
    if (item.hasRansomwareUse) {
      steps.add('Már kötötték ransomware kampányhoz, ezért vizsgáld meg az érintett rendszereket és a naplókat is.');
    }
    if (_entry?.status == 'Érint minket') {
      steps.add('Ez saját megjelölés szerint is releváns, ezért ellenőrizd az érintett verziókat és dokumentáld a javítás állapotát.');
    }
    if (_entry?.priority == 'Kritikus' || _entry?.priority == 'Magas') {
      steps.add('A saját prioritásod alapján ez sürgős tétel, ezért sorold a napi teendők közé.');
    }
    if (steps.isEmpty) {
      steps.add('Ellenőrizd a gyártói advisory-t, az érintett verziókat és telepítsd a javítást amint elérhető.');
      steps.add('Ha nem frissíthető azonnal, korlátozd a hozzáférést és figyeld a naplókat.');
    }
    return steps;
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'Kritikus':
        return Colors.red;
      case 'Magas':
        return Colors.deepOrange;
      case 'Közepes':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.cveId),
        actions: [
          IconButton(
            onPressed: _editTrackerInfo,
            icon: const Icon(Icons.edit_note_outlined),
            tooltip: 'Megjegyzés / státusz',
          ),
          IconButton(
            onPressed: _toggleSaved,
            icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border),
            tooltip: _saved ? 'Eltávolítás a mentettek közül' : 'Mentés későbbre',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('Gyártó: ${item.vendorProject}')),
                      Chip(label: Text('Termék: ${item.product}')),
                      Chip(label: Text('Hozzáadva: ${formatDate(item.dateAdded)}')),
                      if (item.hasRansomwareUse) const Chip(label: Text('Ransomware kapcsolat')),
                    ],
                  ),
                  if (_entry != null) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('Státusz: ${_entry!.status}')),
                        Chip(
                          backgroundColor: _priorityColor(_entry!.priority).withValues(alpha: 0.12),
                          label: Text('Prioritás: ${_entry!.priority}'),
                        ),
                        Chip(label: Text('Frissítve: ${formatDate(_entry!.updatedAt)}')),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(item.shortDescription),
                  if (item.notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Forrás megjegyzés: ${item.notes}'),
                  ],
                  if (_entry?.note.isNotEmpty ?? false) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Saját megjegyzés',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(_entry!.note),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<CveDetail?>(
            future: _detailFuture,
            builder: (context, snapshot) {
              final detail = snapshot.data;
              final todo = _todoSteps(item, detail);

              return Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: snapshot.connectionState == ConnectionState.waiting
                          ? const Center(child: CircularProgressIndicator())
                          : detail == null
                              ? const Text('Az NVD részletek most nem érhetők el.')
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'NVD részletek',
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 10),
                                    Text('Severity: ${detail.severity}'),
                                    Text('CVSS: ${detail.baseScore?.toStringAsFixed(1) ?? '—'}'),
                                    Text('Gyengeség: ${detail.weakness}'),
                                    const SizedBox(height: 12),
                                    Text(detail.description),
                                    if (detail.references.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        'Referenciák',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 6),
                                      ...detail.references.map((ref) => SelectableText(ref)),
                                    ],
                                  ],
                                ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mit tegyek most?',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          ...todo.map(
                            (step) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 3),
                                    child: Icon(Icons.check_circle_outline, size: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(step)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'AI coach magyarázat',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _coachLoading ? null : _loadCoach,
                        icon: const Icon(Icons.psychology_alt_outlined),
                        label: Text(_coachText == null ? 'Elemzés' : 'Frissítés'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_coachLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    Text(
                      _coachText ??
                          'Kérj AI-s összefoglalót arról, hogy ez a CVE miért fontos és milyen lépéseket érdemes tenni.',
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

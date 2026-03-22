import 'package:flutter/material.dart';

import '../models/saved_cve_entry.dart';
import '../models/vulnerability_item.dart';
import '../services/cisa_kev_service.dart';
import '../services/local_storage_service.dart';
import '../utils/formatters.dart';
import 'threat_detail_screen.dart';

class SavedCvesScreen extends StatefulWidget {
  const SavedCvesScreen({super.key});

  @override
  State<SavedCvesScreen> createState() => _SavedCvesScreenState();
}

class _SavedCvesScreenState extends State<SavedCvesScreen> {
  final _storage = LocalStorageService.instance;
  final _kevService = CisaKevService();

  bool _loading = true;
  String? _error;
  List<_SavedCveViewModel> _items = [];
  String _statusFilter = 'Összes';

  static const _statusFilters = [
    'Összes',
    'Új',
    'Ellenőrizendő',
    'Érint minket',
    'Javítás alatt',
    'Megoldva',
    'Nem releváns',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final entries = await _storage.loadSavedCveEntries();
      final feed = await _kevService.fetchLatest();
      final byId = {for (final item in feed) item.cveId: item};
      final items = entries.values
          .map((entry) => _SavedCveViewModel(entry: entry, item: byId[entry.cveId]))
          .toList()
        ..sort((a, b) => b.entry.updatedAt.compareTo(a.entry.updatedAt));

      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _remove(String cveId) async {
    await _storage.removeSavedCve(cveId);
    await _load();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$cveId eltávolítva a mentett CVE-k közül.')),
    );
  }

  List<_SavedCveViewModel> get _filtered {
    if (_statusFilter == 'Összes') {
      return _items;
    }
    return _items.where((item) => item.entry.status == _statusFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 52),
              const SizedBox(height: 12),
              Text('Nem sikerült betölteni a mentett CVE-ket.'),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Újrapróbálás'),
              ),
            ],
          ),
        ),
      );
    }

    final items = _filtered;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mentett CVE-k és jegyzetek',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Itt látod a saját megjegyzésekkel, státuszokkal és prioritással elmentett tételeket.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _statusFilters
                        .map(
                          (filter) => ChoiceChip(
                            label: Text(filter),
                            selected: _statusFilter == filter,
                            onSelected: (_) {
                              setState(() {
                                _statusFilter = filter;
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Még nincs a jelenlegi szűrőnek megfelelő mentett CVE.'),
              ),
            )
          else
            ...items.map((item) => _buildCard(item)),
        ],
      ),
    );
  }

  Widget _buildCard(_SavedCveViewModel model) {
    final item = model.item;
    final entry = model.entry;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.cveId,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => _remove(entry.cveId),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Eltávolítás',
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(entry.status)),
                Chip(label: Text('Prioritás: ${entry.priority}')),
                Chip(label: Text('Frissítve: ${formatDate(entry.updatedAt)}')),
                if (item != null && item.hasRansomwareUse) const Chip(label: Text('Ransomware')),
              ],
            ),
            if (item != null) ...[
              const SizedBox(height: 10),
              Text('${item.vendorProject} • ${item.product}'),
              const SizedBox(height: 6),
              Text(item.shortDescription),
            ],
            if (entry.note.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Saját megjegyzés',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(entry.note),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: item == null
                    ? null
                    : () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ThreatDetailScreen(item: item),
                          ),
                        );
                        await _load();
                      },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Megnyitás'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedCveViewModel {
  final SavedCveEntry entry;
  final VulnerabilityItem? item;

  const _SavedCveViewModel({required this.entry, required this.item});
}

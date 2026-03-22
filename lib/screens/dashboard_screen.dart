import 'package:flutter/material.dart';

import '../models/face_profile.dart';
import '../models/face_recognition_log.dart';
import '../models/saved_cve_entry.dart';
import '../models/scan_history_item.dart';
import '../models/vulnerability_item.dart';
import '../services/cisa_kev_service.dart';
import '../services/local_storage_service.dart';
import '../utils/formatters.dart';
import '../widgets/info_stat_card.dart';
import '../widgets/risk_badge.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _kevService = CisaKevService();
  final _storage = LocalStorageService.instance;

  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardData> _load() async {
    final vulnerabilities = await _kevService.fetchLatest();
    final watchlist = await _storage.loadWatchlist();
    final history = await _storage.loadHistory();
    final savedEntries = await _storage.loadSavedCveEntries();
    final faceProfiles = await _storage.loadFaceProfiles();
    final faceLogs = await _storage.loadFaceRecognitionLogs();

    final now = DateTime.now();
    final recentCount = vulnerabilities.where((item) {
      final added = item.dateAdded;
      if (added == null) {
        return false;
      }
      return now.difference(added).inDays <= 7;
    }).length;

    final watchedHits = vulnerabilities
        .where((item) => item.matchesAnyProducts(watchlist))
        .take(20)
        .toList();

    final dangerousScans = history.where((item) => item.level.name == 'dangerous').length;
    final savedHits = vulnerabilities
        .where((item) => savedEntries.containsKey(item.cveId))
        .take(10)
        .toList();

    final vendorCounts = <String, int>{};
    for (final item in vulnerabilities.take(40)) {
      final vendor = item.vendorProject.trim();
      if (vendor.isEmpty) {
        continue;
      }
      vendorCounts[vendor] = (vendorCounts[vendor] ?? 0) + 1;
    }
    final topVendors = vendorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _DashboardData(
      recentKevCount: recentCount,
      totalKevCount: vulnerabilities.length,
      watchedHits: watchedHits,
      watchlist: watchlist,
      recentHistory: history.take(5).toList(),
      dangerousScanCount: dangerousScans,
      newestKev: vulnerabilities.take(5).toList(),
      savedEntries: savedEntries,
      savedHits: savedHits,
      topVendors: topVendors.take(5).toList(),
      faceProfiles: faceProfiles,
      faceLogs: faceLogs.take(5).toList(),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DashboardData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 52),
                  const SizedBox(height: 12),
                  Text(
                    'Nem sikerült betölteni a dashboard adatokat.',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Újrapróbálás'),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mai áttekintés',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'A dashboard a CISA KEV feedből, a saját watchlistből és a mentett ellenőrzésekből épül fel.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (data.watchlist.isNotEmpty && data.watchedHits.isNotEmpty)
                Card(
                  color: Colors.orange.withValues(alpha: 0.12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.notifications_active_outlined, color: Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Riasztás: ${data.watchedHits.length} aktuális KEV találat érinti a watchlistedet (${data.watchlist.join(', ')}).',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (data.watchlist.isNotEmpty && data.watchedHits.isNotEmpty)
                const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final veryWide = width > 1100;
                  final wide = width > 800;
                  final medium = width > 560;
                  final crossAxisCount = veryWide ? 5 : (wide ? 4 : 2);
                  final childAspectRatio = veryWide
                      ? 1.12
                      : wide
                          ? 0.98
                          : medium
                              ? 0.86
                              : 0.78;
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: childAspectRatio,
                    children: [
                      InfoStatCard(
                        title: 'Új KEV az elmúlt 7 napban',
                        value: data.recentKevCount.toString(),
                        icon: Icons.new_releases_outlined,
                        color: Colors.red,
                      ),
                      InfoStatCard(
                        title: 'Összes KEV rekord',
                        value: data.totalKevCount.toString(),
                        icon: Icons.dataset_outlined,
                        color: Colors.indigo,
                      ),
                      InfoStatCard(
                        title: 'Watchlist találatok',
                        value: data.watchedHits.length.toString(),
                        icon: Icons.visibility_outlined,
                        color: Colors.orange,
                        subtitle: data.watchlist.isEmpty
                            ? 'Adj hozzá termékeket a figyelőlistához.'
                            : 'Szűrés a saját termékeidre.',
                      ),
                      InfoStatCard(
                        title: 'Mentett CVE-k',
                        value: data.savedEntries.length.toString(),
                        icon: Icons.bookmark_outline,
                        color: Colors.teal,
                      ),
                      InfoStatCard(
                        title: 'Veszélyes mentett ellenőrzések',
                        value: data.dangerousScanCount.toString(),
                        icon: Icons.warning_amber_outlined,
                        color: Colors.deepPurple,
                      ),
                      InfoStatCard(
                        title: 'Arcprofilok',
                        value: data.faceProfiles.length.toString(),
                        icon: Icons.face_retouching_natural_outlined,
                        color: Colors.blueGrey,
                        subtitle: data.faceProfiles.isEmpty
                            ? 'Még nincs regisztrált személy.'
                            : 'Utolsó logok: ${data.faceLogs.length}',
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Arc-regiszter állapot',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (data.faceProfiles.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Még nincs regisztrált személy az arcfelismerő modulhoz.'),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Regisztrált profilok: ${data.faceProfiles.length}'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: data.faceProfiles
                              .take(4)
                              .map((profile) => Chip(label: Text('${profile.name} • ${profile.sampleCount} minta')))
                              .toList(),
                        ),
                        if (data.faceLogs.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text('Utolsó felismerés: ${data.faceLogs.first.personName} (${formatDate(data.faceLogs.first.timestamp)})'),
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                'Leginkább érintett gyártók',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (data.topVendors.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Még nincs elég adat a gyártói összesítéshez.'),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: data.topVendors
                      .map((entry) => Chip(label: Text('${entry.key} (${entry.value})')))
                      .toList(),
                ),
              const SizedBox(height: 20),
              Text(
                'Legújabb figyelendő sebezhetőségek',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ...data.newestKev.map((item) => _kevCard(item, data.savedEntries[item.cveId])),
              const SizedBox(height: 20),
              Text(
                'Watchlist találatok',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (data.watchlist.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Még nincs watchlist. A Sebezhetőségek oldalon adj hozzá termékeket, például: windows, chrome, wordpress.',
                    ),
                  ),
                )
              else if (data.watchedHits.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Most nincs friss találat a watchlistre: ${data.watchlist.join(', ')}',
                    ),
                  ),
                )
              else
                ...data.watchedHits.take(6).map((item) => _kevCard(item, data.savedEntries[item.cveId])),
              const SizedBox(height: 20),
              Text(
                'Mentett CVE-k',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (data.savedHits.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Még nincs elmentett CVE. A sebezhetőségek oldalon könyvjelzőzd őket.'),
                  ),
                )
              else
                ...data.savedHits.map((item) => _kevCard(item, data.savedEntries[item.cveId])),
              const SizedBox(height: 20),
              Text(
                'Legutóbbi ellenőrzések',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (data.recentHistory.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Még nincs mentett scan vagy üzenetelemzés.'),
                  ),
                )
              else
                ...data.recentHistory.map(_historyCard),
            ],
          ),
        );
      },
    );
  }

  Widget _kevCard(VulnerabilityItem item, SavedCveEntry? entry) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: const CircleAvatar(child: Icon(Icons.security)),
        title: Text(item.cveId),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text('${item.vendorProject} • ${item.product}'),
            const SizedBox(height: 4),
            Text(item.shortDescription),
            const SizedBox(height: 6),
            Text('Hozzáadva: ${formatDate(item.dateAdded)}'),
            if (entry != null) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(entry.status)),
                  Chip(label: Text('Prioritás: ${entry.priority}')),
                ],
              ),
              if (entry.note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Saját megjegyzés: ${entry.note}'),
              ],
            ],
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'KEV',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _historyCard(ScanHistoryItem item) {
    return Card(
      child: ListTile(
        title: Text(item.summary),
        subtitle: Text('${item.type.toUpperCase()} • ${truncateMiddle(item.input)}'),
        trailing: RiskBadge(level: item.level),
      ),
    );
  }
}

class _DashboardData {
  final int recentKevCount;
  final int totalKevCount;
  final int dangerousScanCount;
  final List<String> watchlist;
  final List<VulnerabilityItem> newestKev;
  final List<VulnerabilityItem> watchedHits;
  final List<VulnerabilityItem> savedHits;
  final Map<String, SavedCveEntry> savedEntries;
  final List<MapEntry<String, int>> topVendors;
  final List<FaceProfile> faceProfiles;
  final List<FaceRecognitionLog> faceLogs;
  final List<ScanHistoryItem> recentHistory;

  const _DashboardData({
    required this.recentKevCount,
    required this.totalKevCount,
    required this.dangerousScanCount,
    required this.watchlist,
    required this.newestKev,
    required this.watchedHits,
    required this.savedHits,
    required this.savedEntries,
    required this.topVendors,
    required this.faceProfiles,
    required this.faceLogs,
    required this.recentHistory,
  });
}


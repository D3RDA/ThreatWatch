import 'package:flutter/material.dart';

import '../models/saved_cve_entry.dart';
import '../models/vulnerability_item.dart';
import '../services/cisa_kev_service.dart';
import '../services/local_storage_service.dart';
import '../utils/formatters.dart';
import 'threat_detail_screen.dart';

enum ThreatQuickFilter { all, ransomware, watchlistOnly }

enum ThreatSortMode { risk, newest, oldest, vendor, product }

class ThreatFeedScreen extends StatefulWidget {
  const ThreatFeedScreen({super.key});

  @override
  State<ThreatFeedScreen> createState() => _ThreatFeedScreenState();
}

class _ThreatFeedScreenState extends State<ThreatFeedScreen> {
  final _kevService = CisaKevService();
  final _storage = LocalStorageService.instance;
  final _searchController = TextEditingController();
  final _watchController = TextEditingController();

  static const List<String> _quickWatchSuggestions = [
    'windows',
    'chrome',
    'android',
    'wordpress',
    'fortinet',
    'cisco',
    'vmware',
    'apache',
  ];

  static const List<_ThreatCategory> _categories = [
    _ThreatCategory(label: 'Összes'),
    _ThreatCategory(
      label: 'Microsoft',
      keywords: ['microsoft', 'windows', 'exchange', 'sharepoint', 'office', 'azure'],
    ),
    _ThreatCategory(
      label: 'Böngészők',
      keywords: ['chrome', 'chromium', 'edge', 'firefox', 'safari', 'browser'],
    ),
    _ThreatCategory(
      label: 'Hálózat / VPN',
      keywords: ['cisco', 'fortinet', 'pulse secure', 'juniper', 'vpn', 'router', 'firewall'],
    ),
    _ThreatCategory(
      label: 'Web / CMS',
      keywords: ['wordpress', 'drupal', 'apache', 'tomcat', 'nginx', 'confluence'],
    ),
    _ThreatCategory(
      label: 'Mobil',
      keywords: ['android', 'ios', 'iphone', 'ipad', 'mobile'],
    ),
    _ThreatCategory(
      label: 'Virtualizáció',
      keywords: ['vmware', 'esxi', 'hyper-v', 'virtualization'],
    ),
    _ThreatCategory(
      label: 'Biztonsági eszközök',
      keywords: ['ivanti', 'fortinet', 'sophos', 'f5', 'palo alto', 'security'],
    ),
  ];

  List<VulnerabilityItem> _allItems = [];
  List<String> _watchlist = [];
  Map<String, SavedCveEntry> _savedEntries = {};
  bool _loading = true;
  String? _error;
  String _selectedCategory = 'Összes';
  ThreatQuickFilter _quickFilter = ThreatQuickFilter.all;
  ThreatSortMode _sortMode = ThreatSortMode.risk;

  _ThreatCategory get _currentCategory =>
      _categories.firstWhere((item) => item.label == _selectedCategory);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _watchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _kevService.fetchLatest();
      final watchlist = await _storage.loadWatchlist();
      final savedEntries = await _storage.loadSavedCveEntries();
      if (!mounted) {
        return;
      }
      setState(() {
        _allItems = items;
        _watchlist = watchlist;
        _savedEntries = savedEntries;
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

  Future<void> _addWatchTerm() async {
    final value = _watchController.text.trim();
    await _addWatchTermValue(value);
  }

  Future<void> _addWatchTermValue(String value) async {
    if (value.isEmpty) {
      return;
    }
    if (_watchlist.any((item) => item.toLowerCase() == value.toLowerCase())) {
      _watchController.clear();
      return;
    }

    setState(() {
      _watchlist = [..._watchlist, value];
      _watchController.clear();
    });
    await _storage.saveWatchlist(_watchlist);
  }

  Future<void> _removeWatchTerm(String value) async {
    setState(() {
      _watchlist = _watchlist.where((item) => item != value).toList();
      if (_quickFilter == ThreatQuickFilter.watchlistOnly && _watchlist.isEmpty) {
        _quickFilter = ThreatQuickFilter.all;
      }
    });
    await _storage.saveWatchlist(_watchlist);
  }

  Future<void> _toggleSavedCve(String cveId) async {
    final saved = await _storage.toggleSavedCve(cveId);
    final entries = await _storage.loadSavedCveEntries();
    if (!mounted) {
      return;
    }
    setState(() {
      _savedEntries = entries;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved ? '$cveId elmentve.' : '$cveId eltávolítva a mentettek közül.'),
      ),
    );
  }

  bool _matchesCategory(VulnerabilityItem item) {
    if (_currentCategory.keywords.isEmpty) {
      return true;
    }
    return _currentCategory.matches(item);
  }

  int _priorityWeight(String priority) {
    switch (priority.toLowerCase()) {
      case 'kritikus':
        return 35;
      case 'magas':
        return 26;
      case 'közepes':
        return 16;
      case 'alacsony':
        return 8;
      default:
        return 0;
    }
  }

  int _riskScore(VulnerabilityItem item) {
    final entry = _savedEntries[item.cveId];
    var score = 50; // KEV = ismerten kihasznált alapból.

    if (item.hasRansomwareUse) {
      score += 30;
    }
    if (item.matchesAnyProducts(_watchlist)) {
      score += 20;
    }
    if (item.isRecent) {
      score += 12;
    }
    if (item.dueDate != null) {
      final days = item.dueDate!.difference(DateTime.now()).inDays;
      if (days <= 7) {
        score += 10;
      } else if (days <= 30) {
        score += 5;
      }
    }
    if (entry != null) {
      score += _priorityWeight(entry.priority);
      switch (entry.status.toLowerCase()) {
        case 'érint minket':
          score += 12;
          break;
        case 'ellenőrizendő':
          score += 6;
          break;
        case 'javítás alatt':
          score -= 4;
          break;
        case 'megoldva':
        case 'nem releváns':
          score -= 20;
          break;
      }
    }
    return score.clamp(0, 999);
  }

  String _riskLabel(VulnerabilityItem item) {
    final score = _riskScore(item);
    if (score >= 95) return 'Nagyon magas';
    if (score >= 75) return 'Magas';
    if (score >= 55) return 'Közepes';
    return 'Alap';
  }

  String _sortModeLabel(ThreatSortMode mode) {
    switch (mode) {
      case ThreatSortMode.risk:
        return 'Legveszélyesebb elöl';
      case ThreatSortMode.newest:
        return 'Legújabb elöl';
      case ThreatSortMode.oldest:
        return 'Legrégebbi elöl';
      case ThreatSortMode.vendor:
        return 'Gyártó szerint';
      case ThreatSortMode.product:
        return 'Termék szerint';
    }
  }

  List<VulnerabilityItem> get _filteredItems {
    final query = _searchController.text.trim();
    var items = _allItems
        .where((item) => _matchesCategory(item) && item.matchesKeyword(query))
        .toList();

    switch (_quickFilter) {
      case ThreatQuickFilter.all:
        break;
      case ThreatQuickFilter.ransomware:
        items = items.where((item) => item.hasRansomwareUse).toList();
        break;
      case ThreatQuickFilter.watchlistOnly:
        items = items.where((item) => item.matchesAnyProducts(_watchlist)).toList();
        break;
    }

    items.sort((a, b) {
      switch (_sortMode) {
        case ThreatSortMode.risk:
          final riskCompare = _riskScore(b).compareTo(_riskScore(a));
          if (riskCompare != 0) {
            return riskCompare;
          }
          final leftSaved = _savedEntries.containsKey(a.cveId) ? 0 : 1;
          final rightSaved = _savedEntries.containsKey(b.cveId) ? 0 : 1;
          if (leftSaved != rightSaved) {
            return leftSaved.compareTo(rightSaved);
          }
          final leftDate = a.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);
          final rightDate = b.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);
          return rightDate.compareTo(leftDate);
        case ThreatSortMode.newest:
          final leftDate = a.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);
          final rightDate = b.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);
          return rightDate.compareTo(leftDate);
        case ThreatSortMode.oldest:
          final leftDate = a.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);
          final rightDate = b.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);
          return leftDate.compareTo(rightDate);
        case ThreatSortMode.vendor:
          final vendorCompare = a.vendorProject.toLowerCase().compareTo(b.vendorProject.toLowerCase());
          if (vendorCompare != 0) {
            return vendorCompare;
          }
          return a.product.toLowerCase().compareTo(b.product.toLowerCase());
        case ThreatSortMode.product:
          final productCompare = a.product.toLowerCase().compareTo(b.product.toLowerCase());
          if (productCompare != 0) {
            return productCompare;
          }
          return a.vendorProject.toLowerCase().compareTo(b.vendorProject.toLowerCase());
      }
    });

    return items;
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
              Text(
                'Nem sikerült lekérni a KEV feedet.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
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

    final items = _filteredItems;
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
                    'CVE keresés',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Egyszerűbb keresés: válassz kategóriát, írj be gyártót, terméket vagy CVE azonosítót.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Kategória',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: _categories
                        .map(
                          (category) => DropdownMenuItem<String>(
                            value: category.label,
                            child: Text(category.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedCategory = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'CVE, gyártó vagy termék',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Törlés',
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Gyors szűrők',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Összes'),
                        selected: _quickFilter == ThreatQuickFilter.all,
                        onSelected: (_) => setState(() => _quickFilter = ThreatQuickFilter.all),
                      ),
                      FilterChip(
                        label: const Text('Ransomware'),
                        selected: _quickFilter == ThreatQuickFilter.ransomware,
                        onSelected: (_) => setState(() => _quickFilter = ThreatQuickFilter.ransomware),
                      ),
                      FilterChip(
                        label: const Text('Csak watchlist'),
                        selected: _quickFilter == ThreatQuickFilter.watchlistOnly,
                        onSelected: _watchlist.isEmpty
                            ? null
                            : (_) => setState(() => _quickFilter = ThreatQuickFilter.watchlistOnly),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<ThreatSortMode>(
                    value: _sortMode,
                    decoration: const InputDecoration(
                      labelText: 'Rendezés',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.sort),
                    ),
                    items: ThreatSortMode.values
                        .map(
                          (mode) => DropdownMenuItem(
                            value: mode,
                            child: Text(_sortModeLabel(mode)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _sortMode = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    title: Text(
                      'Watchlist kezelés',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      _watchlist.isEmpty
                          ? 'Nincs hozzáadott termék'
                          : '${_watchlist.length} elem a listában',
                    ),
                    children: [
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _quickWatchSuggestions
                            .map(
                              (item) => ActionChip(
                                label: Text(item),
                                onPressed: () => _addWatchTermValue(item),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _watchController,
                        decoration: InputDecoration(
                          hintText: 'Saját termék hozzáadása',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: _addWatchTerm,
                            icon: const Icon(Icons.add),
                          ),
                        ),
                        onSubmitted: (_) => _addWatchTerm(),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _watchlist.isEmpty
                            ? [const Chip(label: Text('Nincs watchlist elem'))]
                            : _watchlist
                                .map(
                                  (item) => InputChip(
                                    label: Text(item),
                                    onDeleted: () => _removeWatchTerm(item),
                                  ),
                                )
                                .toList(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Találatok: ${items.length} • $_selectedCategory • ${_sortModeLabel(_sortMode)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nincs találat a jelenlegi szűrőkkel.'),
              ),
            )
          else
            ...items.map((item) => _buildVulnerabilityCard(context, item)),
        ],
      ),
    );
  }

  Widget _buildVulnerabilityCard(BuildContext context, VulnerabilityItem item) {
    final watchMatch = item.matchesAnyProducts(_watchlist);
    final entry = _savedEntries[item.cveId];
    final saved = entry != null;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ThreatDetailScreen(item: item),
            ),
          );
          _savedEntries = await _storage.loadSavedCveEntries();
          if (mounted) {
            setState(() {});
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.cveId,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _toggleSavedCve(item.cveId),
                    icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                    tooltip: saved ? 'Eltávolítás a mentettek közül' : 'Mentés későbbre',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(item.displayTitle),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(item.vendorProject)),
                  Chip(label: Text(item.product)),
                  Chip(label: Text('Kockázat: ${_riskLabel(item)} (${_riskScore(item)})')),
                  Chip(label: Text('Hozzáadva: ${formatDate(item.dateAdded)}')),
                  if (watchMatch) const Chip(label: Text('Saját watchlist')),
                  if (item.isRecent) const Chip(label: Text('Új')),
                  if (item.hasRansomwareUse) const Chip(label: Text('Ransomware')),
                  if (entry != null) Chip(label: Text(entry.status)),
                  if (entry != null) Chip(label: Text('Prioritás: ${entry.priority}')),
                ],
              ),
              const SizedBox(height: 10),
              Text(item.shortDescription),
              if (entry?.note.isNotEmpty ?? false) ...[
                const SizedBox(height: 12),
                Text(
                  'Saját megjegyzés: ${entry!.note}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
              if (item.requiredAction.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Teendő: ${item.requiredAction}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreatCategory {
  final String label;
  final List<String> keywords;

  const _ThreatCategory({required this.label, this.keywords = const []});

  bool matches(VulnerabilityItem item) {
    final haystack = [
      item.cveId,
      item.vendorProject,
      item.product,
      item.vulnerabilityName,
      item.shortDescription,
      item.notes,
    ].join(' ').toLowerCase();

    return keywords.any((keyword) => haystack.contains(keyword.toLowerCase()));
  }
}

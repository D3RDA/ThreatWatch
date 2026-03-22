
import 'package:flutter/material.dart';

import '../models/face_profile.dart';
import '../models/face_recognition_log.dart';
import '../services/local_storage_service.dart';
import '../utils/formatters.dart';
import 'face_profile_editor_screen.dart';
import 'face_recognition_screen.dart';

class FaceRegistryScreen extends StatefulWidget {
  const FaceRegistryScreen({super.key});

  @override
  State<FaceRegistryScreen> createState() => _FaceRegistryScreenState();
}

class _FaceRegistryScreenState extends State<FaceRegistryScreen> {
  final _storage = LocalStorageService.instance;

  bool _loading = true;
  List<FaceProfile> _profiles = [];
  List<FaceRecognitionLog> _logs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profiles = await _storage.loadFaceProfiles();
    final logs = await _storage.loadFaceRecognitionLogs();
    if (!mounted) {
      return;
    }
    setState(() {
      _profiles = profiles;
      _logs = logs;
      _loading = false;
    });
  }

  Future<void> _openEditor([FaceProfile? profile]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FaceProfileEditorScreen(profile: profile),
      ),
    );
    if (changed == true) {
      await _load();
    }
  }

  Future<void> _removeProfile(FaceProfile profile) async {
    await _storage.removeFaceProfile(profile.id);
    await _load();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${profile.name} törölve a regiszterből.')),
    );
  }

  Future<void> _openRecognition() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FaceRecognitionScreen()),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Arc-regiszter és helyi felismerés',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A modul névvel ellátott arcprofilokat tárol, több mintával. A felismerés helyben történik: TFLite embeddinggel, ha van modellfájl, különben landmark-alapú fallback móddal.' ,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _openEditor(),
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: const Text('Új profil'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _openRecognition,
                        icon: const Icon(Icons.face_retouching_natural_outlined),
                        label: const Text('Felismerés indítása'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 700;
              return GridView.count(
                crossAxisCount: wide ? 3 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: wide ? 1.28 : 1.02,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _statCard(context, 'Regisztrált profilok', _profiles.length.toString(), Icons.badge_outlined),
                  _statCard(context, 'Összes minta', _profiles.fold<int>(0, (sum, item) => sum + item.sampleCount).toString(), Icons.layers_outlined),
                  _statCard(context, 'Utolsó felismerések', _logs.take(10).length.toString(), Icons.history_outlined),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Mentett személyek',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (_profiles.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Még nincs regisztrált személy. Hozz létre egy profilt legalább 1 mintával.'),
              ),
            )
          else
            ..._profiles.map(_profileCard),
          const SizedBox(height: 20),
          Text(
            'Utolsó felismerések',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (_logs.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Még nincs felismerési napló.'),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: _logs.take(8).map((log) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.visibility_outlined),
                    title: Text(log.personName),
                    subtitle: Text('${log.outcome} • ${formatDate(log.timestamp)} • ${log.note}'),
                    trailing: Text('${(log.confidence * 100).toStringAsFixed(0)}%'),
                  )).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statCard(BuildContext context, String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 14),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileCard(FaceProfile profile) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  child: Text(profile.initials),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(profile.label),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _openEditor(profile);
                    } else if (value == 'delete') {
                      _removeProfile(profile);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Szerkesztés')),
                    PopupMenuItem(value: 'delete', child: Text('Törlés')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('Minták: ${profile.sampleCount}')),
                Chip(label: Text('Átlag minőség: ${(profile.averageQuality * 100).toStringAsFixed(0)}%')),
                if (profile.lastSeenAt != null)
                  Chip(label: Text('Utoljára látva: ${formatDate(profile.lastSeenAt)}')),
              ],
            ),
            if (profile.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(profile.note),
            ],
          ],
        ),
      ),
    );
  }
}


import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/face_profile.dart';
import '../services/face_recognition_service.dart';
import '../services/local_storage_service.dart';

class FaceProfileEditorScreen extends StatefulWidget {
  const FaceProfileEditorScreen({super.key, this.profile});

  final FaceProfile? profile;

  @override
  State<FaceProfileEditorScreen> createState() => _FaceProfileEditorScreenState();
}

class _FaceProfileEditorScreenState extends State<FaceProfileEditorScreen> {
  final _storage = LocalStorageService.instance;
  final _recognition = FaceRecognitionService();
  final _picker = ImagePicker();
  final _nameController = TextEditingController();
  final _labelController = TextEditingController();
  final _noteController = TextEditingController();

  late List<FaceSample> _samples;
  bool _saving = false;
  bool _addingSample = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _nameController.text = profile?.name ?? '';
    _labelController.text = profile?.label ?? 'Ismert személy';
    _noteController.text = profile?.note ?? '';
    _samples = [...?profile?.samples];
  }

  @override
  void dispose() {
    _recognition.dispose();
    _nameController.dispose();
    _labelController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _addSample(ImageSource source) async {
    if (!_recognition.isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ez a funkció csak Androidon és iOS-en támogatott.')),
      );
      return;
    }

    setState(() {
      _addingSample = true;
    });

    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );
      if (file == null) {
        setState(() {
          _addingSample = false;
        });
        return;
      }

      final extraction = await _recognition.extractSignatureFromPath(file.path);
      if (!mounted) {
        return;
      }
      if (!extraction.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(extraction.message)),
        );
        setState(() {
          _addingSample = false;
        });
        return;
      }

      setState(() {
        _samples.add(
          FaceSample(
            signature: extraction.signature!,
            qualityScore: extraction.qualityScore,
            createdAt: DateTime.now(),
          ),
        );
        _addingSample = false;
      });

      final suffix = extraction.detectedFaces > 1 ? ' Több arc közül a legnagyobb lett kiválasztva.' : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Minta hozzáadva (${extraction.engineLabel}).${suffix.isEmpty ? '' : suffix}')), 
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _addingSample = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nem sikerült beolvasni a mintát: $error')),
      );
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adj meg nevet a profilhoz.')),
      );
      return;
    }
    if (_samples.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adj hozzá legalább 1 jó minőségű mintát.')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    final now = DateTime.now();
    final existing = widget.profile;
    final profile = FaceProfile(
      id: existing?.id ?? now.microsecondsSinceEpoch.toString(),
      name: name,
      label: _labelController.text.trim().isEmpty ? 'Ismert személy' : _labelController.text.trim(),
      note: _noteController.text.trim(),
      samples: _samples,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      lastSeenAt: existing?.lastSeenAt,
    );

    await _storage.upsertFaceProfile(profile);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.profile != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Arcprofil szerkesztése' : 'Új arcprofil'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Mentés'),
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
                    'Profil adatai',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Név',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _labelController,
                    decoration: const InputDecoration(
                      labelText: 'Címke / szerepkör',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Megjegyzés',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.note_alt_outlined),
                    ),
                  ),
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
                    'Minták',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A legjobb találati arányhoz készíts 3–5 mintát szemből, jó fényben. Ha be van állítva a face_embedding.tflite modell, a rendszer TFLite embeddinget használ; különben landmark-alapú helyi fallback matcher fut.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _addingSample ? null : () => _addSample(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Minta kamerából'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _addingSample ? null : () => _addSample(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Minta galériából'),
                      ),
                    ],
                  ),
                  if (_addingSample) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: 12),
                  if (_samples.isEmpty)
                    const Text('Még nincs elmentett minta ehhez a profilhoz.')
                  else
                    ..._samples.asMap().entries.map(
                      (entry) => Card(
                        margin: const EdgeInsets.only(top: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text('${entry.key + 1}'),
                          ),
                          title: Text('Minta ${entry.key + 1}'),
                          subtitle: Text('Minőség: ${(entry.value.qualityScore * 100).toStringAsFixed(0)}%'),
                          trailing: IconButton(
                            onPressed: () {
                              setState(() {
                                _samples.removeAt(entry.key);
                              });
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (kIsWeb) ...[
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Weben ez a modul nem fog működni, mert az ML Kit face detection csak Androidot és iOS-t támogat.'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

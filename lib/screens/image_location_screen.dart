import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/image_location_result.dart';
import '../services/image_location_service.dart';

class ImageLocationScreen extends StatefulWidget {
  const ImageLocationScreen({super.key});

  @override
  State<ImageLocationScreen> createState() => _ImageLocationScreenState();
}

class _ImageLocationScreenState extends State<ImageLocationScreen> {
  final _picker = ImagePicker();
  final _service = ImageLocationService();

  Uint8List? _bytes;
  ImageLocationResult? _result;
  bool _processing = false;

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _processing = true;
    });
    try {
      final file = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
        requestFullMetadata: true,
      );
      if (file == null) {
        setState(() {
          _processing = false;
        });
        return;
      }
      final bytes = await file.readAsBytes();
      final result = await _service.analyzeImageBytes(bytes, filePath: file.path);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _result = result;
        _processing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _processing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nem sikerült feldolgozni a képet: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kép helyének meghatározása', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                  'A modul először a kép beágyazott EXIF metaadataiból próbál pontos helyet kinyerni. Ha van benne valódi GPS koordináta, abból címet is készít. Csak ha nincs használható GPS, akkor próbál landmark alapján becslést adni.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _processing ? null : () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Kép kiválasztása'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _processing ? null : () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Fotó készítése'),
                    ),
                  ],
                ),
                if (_processing) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_bytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(_bytes!, height: 240, fit: BoxFit.cover),
          ),
        if (_bytes != null) const SizedBox(height: 16),
        if (_result == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Még nincs elemzett kép. Válassz ki egy fotót a helymeghatározáshoz.'),
            ),
          )
        else
          _buildResultCard(_result!),
      ],
    );
  }

  Widget _buildResultCard(ImageLocationResult result) {
    final color = result.hasResult ? Colors.green : Colors.orange;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.place_outlined, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(result.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                if (result.hasResult)
                  Chip(label: Text('${(result.confidence * 100).toStringAsFixed(0)}%')),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.my_location_outlined, size: 18),
                  label: Text(result.accuracyLabel),
                ),
                Chip(
                  avatar: Icon(result.usedExifGps ? Icons.gps_fixed_outlined : Icons.info_outline, size: 18),
                  label: Text(result.usedExifGps
                      ? 'Pontos hely a kép metaadataiból'
                      : result.hadExifGpsField
                          ? 'Volt GPS mező, de nem volt használható'
                          : 'Nincs EXIF GPS a képben'),
                ),
                if (result.address != null)
                  Chip(
                    avatar: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Van cím találat'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(result.summary),
            if (result.address != null) ...[
              const SizedBox(height: 12),
              const Text('Olvasható cím', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SelectableText(result.address!),
            ],
            if (result.latitude != null && result.longitude != null) ...[
              const SizedBox(height: 12),
              SelectableText(
                'Koordináta: ${result.latitude!.toStringAsFixed(6)}, ${result.longitude!.toStringAsFixed(6)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            if (result.diagnosticItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Képdiagnosztika', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...result.diagnosticItems.map(
                (item) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bug_report_outlined),
                  title: Text(item.label),
                  subtitle: SelectableText(item.value),
                ),
              ),
            ],
            if (result.metadataItems.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Kiemelt képmetaadatok', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...result.metadataItems.map(
                (item) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: Text(item.label),
                  subtitle: SelectableText(item.value),
                ),
              ),
            ],
            if (result.fullMetadataItems.isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                leading: const Icon(Icons.list_alt_outlined),
                title: const Text('Metaadatok teljes listája'),
                subtitle: Text('${result.fullMetadataItems.length} mező'),
                children: [
                  ...result.fullMetadataItems.map(
                    (item) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.tag_outlined),
                      title: Text(item.label),
                      subtitle: SelectableText(item.value),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text('Felhasznált források', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...result.sources.map(
              (source) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  switch (source.type) {
                    'exif' => Icons.gps_fixed_outlined,
                    'reverse_geocode' => Icons.map_outlined,
                    _ => Icons.landscape_outlined,
                  },
                ),
                title: Text(source.title),
                subtitle: Text(source.detail),
                trailing: Text('${(source.confidence * 100).toStringAsFixed(0)}%'),
              ),
            ),
            const SizedBox(height: 12),
            Text('Tippek', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...result.tips.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $item'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

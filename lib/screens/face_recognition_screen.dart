import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';

import '../models/face_profile.dart';
import '../models/face_recognition_log.dart';
import '../models/face_recognition_result.dart';
import '../models/live_face_detection.dart';
import '../services/face_recognition_service.dart';
import '../services/local_storage_service.dart';
import '../utils/formatters.dart';

class FaceRecognitionScreen extends StatefulWidget {
  const FaceRecognitionScreen({super.key});

  @override
  State<FaceRecognitionScreen> createState() => _FaceRecognitionScreenState();
}

class _FaceRecognitionScreenState extends State<FaceRecognitionScreen> {
  final _picker = ImagePicker();
  final _storage = LocalStorageService.instance;
  final _recognition = FaceRecognitionService();

  CameraController? _cameraController;
  Future<void>? _cameraInitFuture;
  List<CameraDescription> _cameras = const [];
  CameraLensDirection _currentLensDirection = CameraLensDirection.back;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  double _currentZoomLevel = 1.0;

  List<FaceProfile> _profiles = [];
  Uint8List? _previewBytes;
  FaceRecognitionResult? _result;
  List<LiveFaceDetection> _liveDetections = const [];
  ui.Size? _lastImageSize;
  bool _loading = true;
  bool _processing = false;
  bool _streamProcessing = false;
  bool _liveMode = true;
  bool _expandedPreview = true;
  DateTime _lastFrameProcessedAt = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<String, DateTime> _lastLoggedByProfile = {};
  final Map<int, _TrackVoteState> _trackVotes = {};

  @override
  void initState() {
    super.initState();
    _loadProfiles();
    _cameraInitFuture = _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _recognition.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    final profiles = await _storage.loadFaceProfiles();
    if (!mounted) {
      return;
    }
    setState(() {
      _profiles = profiles;
      _loading = false;
    });
  }

  Future<void> _initializeCamera({CameraLensDirection? preferredLens}) async {
    if (kIsWeb || !_recognition.isSupported) {
      return;
    }

    try {
      _cameras = _cameras.isEmpty ? await availableCameras() : _cameras;
      if (_cameras.isEmpty) {
        return;
      }

      final desiredLens = preferredLens ?? _currentLensDirection;
      final selected = _cameras.firstWhere(
        (camera) => camera.lensDirection == desiredLens,
        orElse: () => _cameras.first,
      );
      _currentLensDirection = selected.lensDirection;

      final previous = _cameraController;
      if (previous != null) {
        try {
          if (previous.value.isStreamingImages) {
            await previous.stopImageStream();
          }
        } catch (_) {}
        await previous.dispose();
      }

      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.nv21,
      );
      await controller.initialize();
      double minZoom = 1.0;
      double maxZoom = 1.0;
      try {
        minZoom = await controller.getMinZoomLevel();
        maxZoom = await controller.getMaxZoomLevel();
      } catch (_) {}
      final initialZoom = minZoom.clamp(1.0, maxZoom).toDouble();
      try {
        await controller.setZoomLevel(initialZoom);
      } catch (_) {}
      await controller.startImageStream(_processCameraImage);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _minZoomLevel = minZoom;
        _maxZoomLevel = maxZoom;
        _currentZoomLevel = initialZoom;
      });
    } catch (_) {
      // Maradjon a still image fallback mód.
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ehhez a készülékhez csak egy használható kamera érhető el.')),
      );
      return;
    }
    final nextLens = _currentLensDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    setState(() {
      _cameraInitFuture = _initializeCamera(preferredLens: nextLens);
    });
  }

  Future<void> _setZoomLevel(double value) async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    final target = value.clamp(_minZoomLevel, _maxZoomLevel).toDouble();
    try {
      await controller.setZoomLevel(target);
      if (!mounted) {
        return;
      }
      setState(() {
        _currentZoomLevel = target;
      });
    } catch (_) {}
  }

  Future<void> _setQuickZoom(double value) async {
    await _setZoomLevel(value);
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (!_liveMode || _streamProcessing) {
      return;
    }

    final now = DateTime.now();
    if (now.difference(_lastFrameProcessedAt) < const Duration(milliseconds: 250)) {
      return;
    }
    _lastFrameProcessedAt = now;
    _streamProcessing = true;

    try {
      final rotation = _cameraRotation();
      final inputImage = _cameraImageToInputImage(image, rotation: rotation);
      if (inputImage == null) {
        _streamProcessing = false;
        return;
      }
      final detections = _stabilizeLiveDetections(
        await _recognition.recognizeFacesInCameraFrame(
          cameraImage: image,
          inputImage: inputImage,
          rotation: rotation,
          lensDirection: _currentLensDirection,
          profiles: _profiles,
        ),
      );
      if (!mounted) {
        _streamProcessing = false;
        return;
      }
      setState(() {
        _liveDetections = detections;
        _lastImageSize = ui.Size(image.height.toDouble(), image.width.toDouble());
      });
      await _persistLiveDetections(detections);
    } catch (_) {
      // élő stream hibát lenyeljük, hogy a preview ne essen szét
    } finally {
      _streamProcessing = false;
    }
  }

  InputImageRotation _cameraRotation() {
    final controller = _cameraController;
    return InputImageRotationValue.fromRawValue(
          controller?.description.sensorOrientation ?? 0,
        ) ??
        InputImageRotation.rotation0deg;
  }

  InputImage? _cameraImageToInputImage(CameraImage image, {required InputImageRotation rotation}) {
    final controller = _cameraController;
    if (controller == null) {
      return null;
    }

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) {
      return null;
    }

    if (Platform.isAndroid && format != InputImageFormat.nv21) {
      return null;
    }
    if (Platform.isIOS && format != InputImageFormat.bgra8888) {
      return null;
    }
    if (image.planes.isEmpty) {
      return null;
    }

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: ui.Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }


  List<LiveFaceDetection> _stabilizeLiveDetections(List<LiveFaceDetection> detections) {
    final now = DateTime.now();
    _trackVotes.removeWhere((key, value) => now.difference(value.lastSeen) > const Duration(seconds: 2));

    return detections.map((detection) {
      final trackingId = detection.trackingId;
      if (trackingId == null) {
        return detection;
      }

      final vote = _trackVotes[trackingId] ?? _TrackVoteState.empty();

      if (detection.state == FaceRecognitionState.matched && detection.profile != null) {
        final sameProfile = vote.profileId == detection.profile!.id;
        final streak = sameProfile ? vote.consecutiveMatches + 1 : 1;
        _trackVotes[trackingId] = _TrackVoteState(
          profileId: detection.profile!.id,
          consecutiveMatches: streak,
          lastSeen: now,
        );
        if (streak < 2) {
          return detection.copyWith(
            state: FaceRecognitionState.possible,
            label: 'Ellenőrzés: ${detection.profile!.name}',
            confidence: detection.confidence * 0.9,
          );
        }
        return detection;
      }

      _trackVotes[trackingId] = _TrackVoteState(
        profileId: vote.profileId,
        consecutiveMatches: 0,
        lastSeen: now,
      );
      return detection;
    }).toList(growable: false);
  }

  Future<void> _persistLiveDetections(List<LiveFaceDetection> detections) async {
    final now = DateTime.now();
    for (final detection in detections) {
      final profile = detection.profile;
      if (profile == null || !detection.isRecognized) {
        continue;
      }
      final lastLogged = _lastLoggedByProfile[profile.id];
      if (lastLogged != null && now.difference(lastLogged) < const Duration(seconds: 8)) {
        continue;
      }
      _lastLoggedByProfile[profile.id] = now;

      await _storage.upsertFaceProfile(
        profile.copyWith(lastSeenAt: now, updatedAt: now),
      );
      await _storage.addFaceRecognitionLog(
        FaceRecognitionLog(
          id: '${profile.id}_${now.microsecondsSinceEpoch}',
          source: 'live_camera',
          personName: profile.name,
          outcome: detection.state.name,
          confidence: detection.confidence,
          timestamp: now,
          note: 'Élő kamera találat (${(detection.qualityScore * 100).toStringAsFixed(0)}% minőség)',
        ),
      );
    }
  }

  Future<void> _runStill(ImageSource source) async {
    if (!_recognition.isSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ez a modul csak Androidon és iOS-en támogatott.')),
      );
      return;
    }

    setState(() {
      _processing = true;
      _result = null;
      _previewBytes = null;
    });

    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (file == null) {
        setState(() {
          _processing = false;
        });
        return;
      }

      final bytes = await file.readAsBytes();
      final result = await _recognition.recognizeFromPath(file.path, _profiles);
      await _persistStillResult(result, source == ImageSource.camera ? 'camera' : 'gallery');
      if (!mounted) {
        return;
      }
      setState(() {
        _previewBytes = bytes;
        _result = result;
        _processing = false;
        _liveMode = false;
      });
      await _loadProfiles();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _processing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nem sikerült lefuttatni az elemzést: $error')),
      );
    }
  }

  Future<void> _persistStillResult(FaceRecognitionResult result, String source) async {
    final now = DateTime.now();
    if (result.profile != null) {
      await _storage.upsertFaceProfile(
        result.profile!.copyWith(
          lastSeenAt: now,
          updatedAt: now,
        ),
      );
    }
    final log = FaceRecognitionLog(
      id: now.microsecondsSinceEpoch.toString(),
      source: source,
      personName: result.profile?.name ?? 'Ismeretlen',
      outcome: result.state.name,
      confidence: result.confidence,
      timestamp: now,
      note: result.message,
    );
    await _storage.addFaceRecognitionLog(log);
  }

  Color _stateColor(FaceRecognitionState state) {
    switch (state) {
      case FaceRecognitionState.matched:
        return Colors.green;
      case FaceRecognitionState.possible:
      case FaceRecognitionState.multipleFaces:
        return Colors.orange;
      case FaceRecognitionState.unknown:
        return Colors.blueGrey;
      case FaceRecognitionState.noFace:
      case FaceRecognitionState.lowQuality:
        return Colors.redAccent;
      case FaceRecognitionState.unsupported:
        return Colors.grey;
    }
  }

  String _stateLabel(FaceRecognitionState state) {
    switch (state) {
      case FaceRecognitionState.matched:
        return 'Találat';
      case FaceRecognitionState.possible:
        return 'Lehetséges találat';
      case FaceRecognitionState.multipleFaces:
        return 'Több arc';
      case FaceRecognitionState.unknown:
        return 'Ismeretlen';
      case FaceRecognitionState.noFace:
        return 'Nem talált arcot';
      case FaceRecognitionState.lowQuality:
        return 'Gyenge minta';
      case FaceRecognitionState.unsupported:
        return 'Nem támogatott';
    }
  }

  Widget _buildCameraPreview(CameraController controller) {
    final screenHeight = MediaQuery.of(context).size.height;
    final previewHeight = _expandedPreview ? screenHeight * 0.68 : 320.0;
    final previewSize = controller.value.previewSize;
    final imageSize = _lastImageSize ??
        ui.Size(
          previewSize?.height ?? 720,
          previewSize?.width ?? 1280,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilterChip(
              selected: _expandedPreview,
              onSelected: (value) {
                setState(() {
                  _expandedPreview = value;
                });
              },
              label: const Text('Nagy kamera nézet'),
              avatar: const Icon(Icons.fullscreen_outlined),
            ),
            if (_cameras.length > 1)
              OutlinedButton.icon(
                onPressed: _switchCamera,
                icon: const Icon(Icons.cameraswitch_outlined),
                label: Text(_currentLensDirection == CameraLensDirection.back ? 'Első kamera' : 'Hátsó kamera'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            height: previewHeight,
            width: double.infinity,
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _LiveCameraSurface(controller: controller),
                if (_liveMode)
                  CustomPaint(
                    painter: _LiveFaceOverlayPainter(
                      detections: _liveDetections,
                      imageSize: imageSize,
                    ),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.60),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _liveMode
                                  ? 'Találatok: ${_liveDetections.where((item) => item.isRecognized).length} • Ismeretlen: ${_liveDetections.where((item) => item.state == FaceRecognitionState.unknown).length} • Arcok: ${_liveDetections.length}'
                                  : 'Live mód kikapcsolva',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _liveDetections.isEmpty
                            ? (_profiles.isEmpty ? 'Nincs mentett profil. Így is megjelenítem az arcokat, de név helyett ismeretlenként.' : 'Irányítsd a kamerát egy jól látható, közel lévő arcra.')
                            : _liveDetections.map((item) => item.label).join(' • '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_maxZoomLevel > _minZoomLevel + 0.01) ...[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.zoom_in_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Live zoom – távoli arcokhoz növeld a nagyítást',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        '${_currentZoomLevel.toStringAsFixed(1)}x',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    min: _minZoomLevel,
                    max: _maxZoomLevel,
                    divisions: ((_maxZoomLevel - _minZoomLevel) * 10).round().clamp(1, 60),
                    value: _currentZoomLevel.clamp(_minZoomLevel, _maxZoomLevel),
                    label: '${_currentZoomLevel.toStringAsFixed(1)}x',
                    onChanged: (value) {
                      setState(() {
                        _currentZoomLevel = value;
                      });
                    },
                    onChangeEnd: _setZoomLevel,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final target in <double>[1, 2, 3])
                        ActionChip(
                          avatar: const Icon(Icons.center_focus_strong, size: 18),
                          label: Text('${target.toStringAsFixed(0)}x'),
                          onPressed: target <= _maxZoomLevel + 0.001
                              ? () => _setQuickZoom(target)
                              : null,
                        ),
                      if (_minZoomLevel < 1.0)
                        ActionChip(
                          avatar: const Icon(Icons.fit_screen_outlined, size: 18),
                          label: Text('${_minZoomLevel.toStringAsFixed(1)}x'),
                          onPressed: () => _setQuickZoom(_minZoomLevel),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Élő arcfelismerés')),
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
                    'Élő kamera mód',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A kamera megnyitásakor az app valós időben arcokat keres, és ha felismeri a mentett profilt, a név azonnal megjelenik a képen. Mentett személyek: ${_profiles.length}.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilterChip(
                        selected: _liveMode,
                        onSelected: (value) {
                          setState(() {
                            _liveMode = value;
                            if (value) {
                              _result = null;
                              _previewBytes = null;
                            }
                          });
                        },
                        label: const Text('Live mód'),
                        avatar: const Icon(Icons.videocam_outlined),
                      ),
                      Chip(label: Text('Motor: ${_recognition.preferredEngineLabel}')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _processing ? null : () => _runStill(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Egyszeri kamera scan'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _processing ? null : () => _runStill(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Kép kiválasztása'),
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
          if (kIsWeb || !_recognition.isSupported)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Weben ez a modul nem fut. Élő arcfelismeréshez Android vagy iOS eszköz kell.'),
              ),
            )
          else ...[
            const SizedBox(height: 16),
            FutureBuilder<void>(
              future: _cameraInitFuture,
              builder: (context, snapshot) {
                final controller = _cameraController;
                if (snapshot.connectionState != ConnectionState.done || controller == null || !controller.value.isInitialized) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          SizedBox(height: 8),
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Kamera inicializálása...'),
                        ],
                      ),
                    ),
                  );
                }
                return _buildCameraPreview(controller);
              },
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Élő találatok', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (_liveDetections.isEmpty)
                      const Text('Még nincs élő találat. Irányítsd a kamerát arcokra, és tartsd stabilan a képet.')
                    else
                      ..._liveDetections.map(
                        (item) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: _stateColor(item.state).withValues(alpha: 0.18),
                            child: Icon(Icons.face_outlined, color: _stateColor(item.state)),
                          ),
                          title: Text(item.label),
                          subtitle: Text(
                            'Állapot: ${_stateLabel(item.state)} • Minőség: ${(item.qualityScore * 100).toStringAsFixed(0)}% • ${item.engineLabel}',
                          ),
                          trailing: Text('${(item.confidence * 100).toStringAsFixed(0)}%'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (_previewBytes != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(_previewBytes!, height: 260, fit: BoxFit.cover),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 16),
            Card(
              color: _stateColor(_result!.state).withValues(alpha: 0.10),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _stateLabel(_result!.state),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Chip(
                          label: Text('${(_result!.confidence * 100).toStringAsFixed(0)}%'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_result!.message),
                    const SizedBox(height: 8),
                    Text('Motor: ${_result!.engineLabel}'),
                    const SizedBox(height: 4),
                    Text('Arc minőségi pontszám: ${(_result!.qualityScore * 100).toStringAsFixed(0)}%'),
                    Text('Detektált arcok: ${_result!.detectedFaces}'),
                    if (_result!.profile != null) ...[
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(child: Text(_result!.profile!.initials)),
                        title: Text(_result!.profile!.name),
                        subtitle: Text(_result!.profile!.label),
                        trailing: Text('Minták: ${_result!.profile!.sampleCount}'),
                      ),
                      if (_result!.profile!.note.isNotEmpty) Text('Megjegyzés: ${_result!.profile!.note}'),
                      if (_result!.profile!.lastSeenAt != null)
                        Text('Utolsó felismerés: ${formatDate(_result!.profile!.lastSeenAt)}'),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}


class _TrackVoteState {
  final String? profileId;
  final int consecutiveMatches;
  final DateTime lastSeen;

  const _TrackVoteState({
    required this.profileId,
    required this.consecutiveMatches,
    required this.lastSeen,
  });

  factory _TrackVoteState.empty() => _TrackVoteState(
        profileId: null,
        consecutiveMatches: 0,
        lastSeen: DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class _LiveCameraSurface extends StatelessWidget {
  final CameraController controller;

  const _LiveCameraSurface({required this.controller});

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(controller);
    }

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _LiveFaceOverlayPainter extends CustomPainter {
  final List<LiveFaceDetection> detections;
  final ui.Size? imageSize;

  const _LiveFaceOverlayPainter({
    required this.detections,
    required this.imageSize,
  });

  @override
  void paint(Canvas canvas, ui.Size size) {
    if (imageSize == null || detections.isEmpty) {
      return;
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );

    final scale = math.max(size.width / imageSize!.width, size.height / imageSize!.height);
    final renderedWidth = imageSize!.width * scale;
    final renderedHeight = imageSize!.height * scale;
    final dx = (size.width - renderedWidth) / 2;
    final dy = (size.height - renderedHeight) / 2;

    for (final detection in detections) {
      final box = detection.boundingBox;
      final rect = Rect.fromLTWH(
        dx + (box.left * scale),
        dy + (box.top * scale),
        box.width * scale,
        box.height * scale,
      );

      final color = switch (detection.state) {
        FaceRecognitionState.matched => Colors.greenAccent,
        FaceRecognitionState.possible || FaceRecognitionState.multipleFaces => Colors.orangeAccent,
        FaceRecognitionState.lowQuality => Colors.yellowAccent,
        FaceRecognitionState.unknown => Colors.redAccent,
        _ => Colors.blueAccent,
      };

      paint.color = color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(14)),
        paint,
      );

      final label = '${detection.label} ${(detection.confidence * 100).toStringAsFixed(0)}%';
      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          backgroundColor: color.withValues(alpha: 0.85),
        ),
      );
      textPainter.layout(maxWidth: math.max(80, size.width - 32));
      final textOffset = Offset(
        rect.left,
        math.max(0, rect.top - textPainter.height - 6),
      );
      textPainter.paint(canvas, textOffset);
    }
  }

  @override
  bool shouldRepaint(covariant _LiveFaceOverlayPainter oldDelegate) {
    return oldDelegate.detections != detections || oldDelegate.imageSize != imageSize;
  }
}

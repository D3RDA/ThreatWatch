import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/face_profile.dart';
import '../models/face_recognition_result.dart';
import '../models/live_face_detection.dart';

class FaceSampleExtraction {
  final List<double>? signature;
  final double qualityScore;
  final String message;
  final int detectedFaces;
  final String engineLabel;

  const FaceSampleExtraction({
    required this.signature,
    required this.qualityScore,
    required this.message,
    required this.detectedFaces,
    required this.engineLabel,
  });

  bool get isSuccess => signature != null;
}

class _MatchCandidate {
  final FaceProfile profile;
  final double distance;
  final double confidence;
  final String engineLabel;
  final int supportingSamples;

  const _MatchCandidate({
    required this.profile,
    required this.distance,
    required this.confidence,
    required this.engineLabel,
    required this.supportingSamples,
  });
}

class FaceRecognitionService {
  FaceDetector? _detector;
  Interpreter? _interpreter;
  bool _tfliteAttempted = false;
  bool _tfliteReady = false;
  int _embeddingLength = 192;
  int _inputImageSize = 112;

  FaceDetector _ensureDetector() {
    return _detector ??= FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: true,
        enableContours: true,
        enableClassification: true,
        enableTracking: true,
      ),
    );
  }

  bool get isSupported {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  String get preferredEngineLabel => _tfliteReady
      ? 'TFLite embedding'
      : 'Landmark alapú fallback';

  Future<void> _ensureInterpreter() async {
    if (_tfliteAttempted) {
      return;
    }
    _tfliteAttempted = true;
    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset('assets/models/face_embedding.tflite', options: options);
      final inputShape = _interpreter!.getInputTensor(0).shape;
      if (inputShape.length >= 4) {
        final height = inputShape[inputShape.length - 3];
        final width = inputShape[inputShape.length - 2];
        if (height > 0 && width > 0 && height == width) {
          _inputImageSize = height;
        }
      }
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      if (outputShape.isNotEmpty) {
        _embeddingLength = outputShape.last;
      }
      _tfliteReady = true;
    } catch (_) {
      _tfliteReady = false;
      _interpreter = null;
    }
  }

  Future<FaceSampleExtraction> extractSignatureFromPath(String imagePath) async {
    if (!isSupported) {
      return const FaceSampleExtraction(
        signature: null,
        qualityScore: 0,
        message: 'Az arcfelismerő modul csak Androidon és iOS-en támogatott.',
        detectedFaces: 0,
        engineLabel: 'Nem támogatott',
      );
    }

    await _ensureInterpreter();

    final input = InputImage.fromFilePath(imagePath);
    final faces = await _ensureDetector().processImage(input);
    if (faces.isEmpty) {
      return FaceSampleExtraction(
        signature: null,
        qualityScore: 0,
        message: 'Nem találtam arcot a képen.',
        detectedFaces: 0,
        engineLabel: preferredEngineLabel,
      );
    }

    final primary = _pickPrimaryFace(faces);
    final quality = _quality(primary);
    if (quality < 0.45) {
      return FaceSampleExtraction(
        signature: null,
        qualityScore: quality,
        message: 'Az arc minősége túl gyenge. Készíts közelebbi, élesebb, szemből fotót.',
        detectedFaces: faces.length,
        engineLabel: preferredEngineLabel,
      );
    }

    List<double>? signature;
    if (_tfliteReady) {
      signature = await _embeddingSignature(imagePath, primary);
    }
    signature ??= _landmarkSignature(primary);

    return FaceSampleExtraction(
      signature: signature,
      qualityScore: quality,
      message: _tfliteReady
          ? 'Az arc minta TFLite embeddinggel sikeresen kinyerve (${_inputImageSize}×${_inputImageSize}).'
          : faces.length > 1
              ? 'Több arcot találtam, a legnagyobb arc landmark-fallback módban lett feldolgozva.'
              : 'Az arc minta landmark-fallback módban sikeresen kinyerve.',
      detectedFaces: faces.length,
      engineLabel: preferredEngineLabel,
    );
  }

  Future<FaceRecognitionResult> recognizeFromPath(String imagePath, List<FaceProfile> profiles) async {
    final extraction = await extractSignatureFromPath(imagePath);
    if (!extraction.isSuccess) {
      final state = !isSupported
          ? FaceRecognitionState.unsupported
          : extraction.detectedFaces == 0
              ? FaceRecognitionState.noFace
              : FaceRecognitionState.lowQuality;
      return FaceRecognitionResult(
        state: state,
        profile: null,
        confidence: 0,
        qualityScore: extraction.qualityScore,
        detectedFaces: extraction.detectedFaces,
        message: extraction.message,
        engineLabel: extraction.engineLabel,
        candidates: const [],
      );
    }

    if (profiles.isEmpty) {
      return FaceRecognitionResult(
        state: FaceRecognitionState.unknown,
        profile: null,
        confidence: 0,
        qualityScore: extraction.qualityScore,
        detectedFaces: extraction.detectedFaces,
        message: 'Még nincs regisztrált személy, amihez hasonlíthatnám a képet.',
        engineLabel: extraction.engineLabel,
        candidates: const [],
      );
    }

    final query = extraction.signature!;
    final candidates = _buildCandidatesFromSignature(
      query: query,
      profiles: profiles,
      liveMode: false,
      forceEmbedding: _isEmbeddingSignature(query),
    )
        .map((candidate) => FaceCandidateScore(
              profile: candidate.profile,
              distance: candidate.distance,
              confidence: candidate.confidence,
            ))
        .toList();

    if (candidates.isEmpty) {
      return FaceRecognitionResult(
        state: FaceRecognitionState.unknown,
        profile: null,
        confidence: 0,
        qualityScore: extraction.qualityScore,
        detectedFaces: extraction.detectedFaces,
        message: 'A mentett minták nem kompatibilisek a jelenlegi felismerő móddal. Regisztrálj új mintát vagy adj hozzá több képet.',
        engineLabel: extraction.engineLabel,
        candidates: const [],
      );
    }

    final best = candidates.first;
    final matchThreshold = _isEmbeddingSignature(query) ? 0.95 : 0.20;
    final possibleThreshold = _isEmbeddingSignature(query) ? 1.08 : 0.28;

    if (best.distance <= matchThreshold) {
      return FaceRecognitionResult(
        state: extraction.detectedFaces > 1 ? FaceRecognitionState.multipleFaces : FaceRecognitionState.matched,
        profile: best.profile,
        confidence: best.confidence,
        qualityScore: extraction.qualityScore,
        detectedFaces: extraction.detectedFaces,
        message: extraction.detectedFaces > 1
            ? 'Több arcot észleltem, a legnagyobb arcon ${best.profile.name} volt a legjobb találat.'
            : 'Erős egyezés: ${best.profile.name}.',
        engineLabel: extraction.engineLabel,
        candidates: candidates.take(3).toList(),
      );
    }

    if (best.distance <= possibleThreshold) {
      return FaceRecognitionResult(
        state: FaceRecognitionState.possible,
        profile: best.profile,
        confidence: best.confidence,
        qualityScore: extraction.qualityScore,
        detectedFaces: extraction.detectedFaces,
        message: 'Lehetséges egyezés: ${best.profile.name}. Érdemes több mintával ellenőrizni.',
        engineLabel: extraction.engineLabel,
        candidates: candidates.take(3).toList(),
      );
    }

    return FaceRecognitionResult(
      state: FaceRecognitionState.unknown,
      profile: null,
      confidence: 0,
      qualityScore: extraction.qualityScore,
      detectedFaces: extraction.detectedFaces,
      message: 'Nem találtam elég közeli egyezést a mentett arcok között.',
      engineLabel: extraction.engineLabel,
      candidates: candidates.take(3).toList(),
    );
  }

  Future<List<LiveFaceDetection>> recognizeFacesInInputImage(
    InputImage inputImage,
    List<FaceProfile> profiles,
  ) async {
    if (!isSupported) {
      return const [];
    }

    await _ensureInterpreter();
    final faces = await _ensureDetector().processImage(inputImage);
    if (faces.isEmpty) {
      return const [];
    }

    return faces
        .map((face) => _liveDetectionFromFace(face, profiles))
        .toList(growable: false);
  }

  Future<List<LiveFaceDetection>> recognizeFacesInCameraFrame({
    required CameraImage cameraImage,
    required InputImage inputImage,
    required InputImageRotation rotation,
    required CameraLensDirection lensDirection,
    required List<FaceProfile> profiles,
  }) async {
    if (!isSupported) {
      return const [];
    }

    await _ensureInterpreter();
    final faces = await _ensureDetector().processImage(inputImage);
    if (faces.isEmpty) {
      return const [];
    }

    img.Image? frameImage;
    final wantsImageBasedMatching = _tfliteReady || profiles.any(
      (profile) => profile.samples.any((sample) => _isEmbeddingSignature(sample.signature)),
    );
    if (wantsImageBasedMatching) {
      frameImage = _cameraImageToOrientedImage(
        cameraImage,
        rotation: rotation,
        lensDirection: lensDirection,
      );
    }

    return faces
        .map((face) => _liveDetectionFromFace(face, profiles, frameImage: frameImage))
        .toList(growable: false);
  }

  LiveFaceDetection _liveDetectionFromFace(
    Face face,
    List<FaceProfile> profiles, {
    img.Image? frameImage,
  }) {
    final quality = _quality(face);
    if (quality < 0.42) {
      return LiveFaceDetection(
        boundingBox: face.boundingBox,
        state: FaceRecognitionState.lowQuality,
        profile: null,
        confidence: 0,
        qualityScore: quality,
        label: 'Gyenge minta',
        engineLabel: 'Live detector',
        trackingId: face.trackingId,
      );
    }

    if (profiles.isEmpty) {
      return LiveFaceDetection(
        boundingBox: face.boundingBox,
        state: FaceRecognitionState.unknown,
        profile: null,
        confidence: 0,
        qualityScore: quality,
        label: 'Ismeretlen arc',
        engineLabel: 'Live detector',
        trackingId: face.trackingId,
      );
    }

    final landmarkSignature = _landmarkSignature(face);
    List<double>? embeddingSignature;
    if (frameImage != null && _tfliteReady) {
      embeddingSignature = _embeddingSignatureFromImage(frameImage, face.boundingBox);
    }

    final candidates = _buildCandidatesForLive(
      embeddingSignature: embeddingSignature,
      landmarkSignature: landmarkSignature,
      profiles: profiles,
    );

    if (candidates.isEmpty) {
      return LiveFaceDetection(
        boundingBox: face.boundingBox,
        state: FaceRecognitionState.unknown,
        profile: null,
        confidence: 0,
        qualityScore: quality,
        label: 'Ismeretlen arc',
        engineLabel: _tfliteReady ? 'Live TFLite matcher' : 'Live landmark matcher',
        trackingId: face.trackingId,
      );
    }

    final best = candidates.first;
    final second = candidates.length > 1 ? candidates[1] : null;
    final separation = second == null ? 999.0 : (second.distance - best.distance);
    final isEmbedding = best.engineLabel.contains('TFLite');
    final strongThreshold = isEmbedding ? 1.02 : 0.20;
    final possibleThreshold = isEmbedding ? 1.14 : 0.28;
    final strongSeparation = isEmbedding ? 0.08 : 0.020;
    final possibleSeparation = isEmbedding ? 0.03 : 0.008;
    final singleProfile = candidates.length == 1;
    final reliableStrong = best.distance <= strongThreshold &&
        (singleProfile || separation >= strongSeparation || best.distance <= ((second?.distance ?? 999) * 0.88));
    final reliablePossible = best.distance <= possibleThreshold &&
        (singleProfile || separation >= possibleSeparation || best.distance <= ((second?.distance ?? 999) * 0.94));

    if (reliableStrong) {
      final confidenceBoost = _sampleSupportFactor(best.supportingSamples);
      return LiveFaceDetection(
        boundingBox: face.boundingBox,
        state: FaceRecognitionState.matched,
        profile: best.profile,
        confidence: (best.confidence * confidenceBoost).clamp(0, 1).toDouble(),
        qualityScore: quality,
        label: best.profile.name,
        engineLabel: best.engineLabel,
        trackingId: face.trackingId,
      );
    }

    if (reliablePossible) {
      return LiveFaceDetection(
        boundingBox: face.boundingBox,
        state: FaceRecognitionState.possible,
        profile: best.profile,
        confidence: (best.confidence * 0.9).clamp(0, 1).toDouble(),
        qualityScore: quality,
        label: 'Talán: ${best.profile.name}',
        engineLabel: best.engineLabel,
        trackingId: face.trackingId,
      );
    }

    return LiveFaceDetection(
      boundingBox: face.boundingBox,
      state: FaceRecognitionState.unknown,
      profile: null,
      confidence: 0,
      qualityScore: quality,
      label: face.trackingId == null ? 'Ismeretlen arc' : 'Ismeretlen #${face.trackingId}',
      engineLabel: best.engineLabel,
      trackingId: face.trackingId,
    );
  }

  List<_MatchCandidate> _buildCandidatesForLive({
    required List<double>? embeddingSignature,
    required List<double> landmarkSignature,
    required List<FaceProfile> profiles,
  }) {
    final candidates = <_MatchCandidate>[];
    for (final profile in profiles.where((profile) => profile.samples.isNotEmpty)) {
      final candidate = _buildCandidate(
        profile: profile,
        embeddingSignature: embeddingSignature,
        landmarkSignature: landmarkSignature,
        liveMode: true,
      );
      if (candidate != null) {
        candidates.add(candidate);
      }
    }
    candidates.sort((a, b) => a.distance.compareTo(b.distance));
    return candidates;
  }

  List<_MatchCandidate> _buildCandidatesFromSignature({
    required List<double> query,
    required List<FaceProfile> profiles,
    required bool liveMode,
    required bool forceEmbedding,
  }) {
    final candidates = <_MatchCandidate>[];
    for (final profile in profiles.where((profile) => profile.samples.isNotEmpty)) {
      final candidate = _buildCandidate(
        profile: profile,
        embeddingSignature: forceEmbedding ? query : null,
        landmarkSignature: forceEmbedding ? null : query,
        liveMode: liveMode,
      );
      if (candidate != null) {
        candidates.add(candidate);
      }
    }
    candidates.sort((a, b) => a.distance.compareTo(b.distance));
    return candidates;
  }

  _MatchCandidate? _buildCandidate({
    required FaceProfile profile,
    required List<double>? embeddingSignature,
    required List<double>? landmarkSignature,
    required bool liveMode,
  }) {
    final embeddingSamples = profile.samples.where((sample) => _isEmbeddingSignature(sample.signature)).toList();
    final landmarkSamples = profile.samples.where((sample) => !_isEmbeddingSignature(sample.signature)).toList();

    if (embeddingSignature != null && embeddingSamples.isNotEmpty) {
      final distance = _aggregateDistances(
        embeddingSamples
            .map((sample) => _distance(embeddingSignature, sample.signature))
            .where((distance) => distance.isFinite)
            .toList(),
      );
      if (distance.isFinite) {
        final support = embeddingSamples.length;
        return _MatchCandidate(
          profile: profile,
          distance: distance,
          confidence: (_confidence(distance) * _sampleSupportFactor(support)).clamp(0, 1).toDouble(),
          engineLabel: liveMode ? 'Live TFLite matcher' : 'TFLite embedding',
          supportingSamples: support,
        );
      }
    }

    if (landmarkSignature != null && landmarkSamples.isNotEmpty) {
      final distance = _aggregateDistances(
        landmarkSamples
            .map((sample) => _distance(landmarkSignature, sample.signature))
            .where((distance) => distance.isFinite)
            .toList(),
      );
      if (distance.isFinite) {
        final support = landmarkSamples.length;
        return _MatchCandidate(
          profile: profile,
          distance: distance,
          confidence: (_confidence(distance) * _sampleSupportFactor(support)).clamp(0, 1).toDouble(),
          engineLabel: liveMode ? 'Live landmark matcher' : 'Landmark alapú fallback',
          supportingSamples: support,
        );
      }
    }

    return null;
  }

  double _aggregateDistances(List<double> distances) {
    if (distances.isEmpty) {
      return double.infinity;
    }
    distances.sort();
    if (distances.length == 1) {
      return distances.first;
    }
    if (distances.length == 2) {
      return (distances[0] * 0.7) + (distances[1] * 0.3);
    }
    return (distances[0] * 0.6) + (distances[1] * 0.3) + (distances[2] * 0.1);
  }

  double _sampleSupportFactor(int sampleCount) {
    if (sampleCount <= 1) {
      return 0.90;
    }
    if (sampleCount == 2) {
      return 0.96;
    }
    if (sampleCount == 3) {
      return 0.99;
    }
    return 1.0;
  }

  bool _isEmbeddingSignature(List<double> signature) {
    return signature.length >= 64;
  }

  List<double>? _embeddingSignatureFromImage(img.Image image, Rect box) {
    if (_interpreter == null) {
      return null;
    }
    try {
      final crop = _cropFace(image, box);
      final size = _inputImageSize <= 0 ? 112 : _inputImageSize;
      final resized = img.copyResize(crop, width: size, height: size, interpolation: img.Interpolation.cubic);
      final input = List.generate(1, (_) => List.generate(size, (y) => List.generate(size, (x) {
            final pixel = resized.getPixel(x, y);
            return [
              (pixel.r / 127.5) - 1,
              (pixel.g / 127.5) - 1,
              (pixel.b / 127.5) - 1,
            ];
          })));
      final output = [List<double>.filled(_embeddingLength, 0)];
      _interpreter!.run(input, output);
      return _normalize(output.first);
    } catch (_) {
      return null;
    }
  }

  img.Image? _cameraImageToOrientedImage(
    CameraImage image, {
    required InputImageRotation rotation,
    required CameraLensDirection lensDirection,
  }) {
    img.Image? base;
    if (Platform.isAndroid) {
      base = _androidNv21ToImage(image);
    } else if (Platform.isIOS) {
      base = _iosBgra8888ToImage(image);
    }
    if (base == null) {
      return null;
    }

    final angle = switch (rotation) {
      InputImageRotation.rotation0deg => 0,
      InputImageRotation.rotation90deg => 90,
      InputImageRotation.rotation180deg => 180,
      InputImageRotation.rotation270deg => 270,
    };

    if (angle != 0) {
      base = img.copyRotate(base, angle: angle);
    }

    if (lensDirection == CameraLensDirection.front) {
      base = img.flipHorizontal(base);
    }

    return base;
  }

  img.Image? _androidNv21ToImage(CameraImage image) {
    if (image.planes.isEmpty) {
      return null;
    }
    final width = image.width;
    final height = image.height;
    final bytes = image.planes.first.bytes;
    if (bytes.length < width * height) {
      return null;
    }

    final output = img.Image(width: width, height: height);
    final frameSize = width * height;
    for (var y = 0; y < height; y++) {
      final uvRow = frameSize + (y >> 1) * width;
      for (var x = 0; x < width; x++) {
        final yp = bytes[y * width + x] & 0xff;
        final uvIndex = uvRow + (x & ~1);
        final vp = bytes.length > uvIndex ? bytes[uvIndex] & 0xff : 128;
        final up = bytes.length > uvIndex + 1 ? bytes[uvIndex + 1] & 0xff : 128;

        final yValue = yp.toDouble();
        final u = up.toDouble() - 128.0;
        final v = vp.toDouble() - 128.0;
        final r = (yValue + 1.370705 * v).round().clamp(0, 255);
        final g = (yValue - 0.337633 * u - 0.698001 * v).round().clamp(0, 255);
        final b = (yValue + 1.732446 * u).round().clamp(0, 255);
        output.setPixelRgba(x, y, r, g, b, 255);
      }
    }
    return output;
  }

  img.Image? _iosBgra8888ToImage(CameraImage image) {
    if (image.planes.isEmpty) {
      return null;
    }
    final plane = image.planes.first;
    final bytes = plane.bytes;
    final width = image.width;
    final height = image.height;
    final output = img.Image(width: width, height: height);

    for (var y = 0; y < height; y++) {
      final rowStart = y * plane.bytesPerRow;
      for (var x = 0; x < width; x++) {
        final index = rowStart + (x * 4);
        if (index + 3 >= bytes.length) {
          continue;
        }
        final b = bytes[index];
        final g = bytes[index + 1];
        final r = bytes[index + 2];
        final a = bytes[index + 3];
        output.setPixelRgba(x, y, r, g, b, a);
      }
    }
    return output;
  }

  Future<List<double>?> _embeddingSignature(String imagePath, Face face) async {
    if (_interpreter == null) {
      return null;
    }
    try {
      final bytes = await File(imagePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return null;
      }
      return _embeddingSignatureFromImage(decoded, face.boundingBox);
    } catch (_) {
      return null;
    }
  }

  img.Image _cropFace(img.Image image, Rect box) {
    final paddingX = box.width * 0.18;
    final paddingY = box.height * 0.22;
    final left = max(0, (box.left - paddingX).round());
    final top = max(0, (box.top - paddingY).round());
    final right = min(image.width, (box.right + paddingX).round());
    final bottom = min(image.height, (box.bottom + paddingY).round());
    final width = max(1, right - left);
    final height = max(1, bottom - top);
    return img.copyCrop(image, x: left, y: top, width: width, height: height);
  }

  List<double> _normalize(List<double> values) {
    final norm = sqrt(values.fold<double>(0, (sum, item) => sum + (item * item)));
    if (norm == 0) {
      return values;
    }
    return values.map((item) => item / norm).toList();
  }

  Face _pickPrimaryFace(List<Face> faces) {
    return faces.reduce((a, b) {
      final areaA = a.boundingBox.width * a.boundingBox.height;
      final areaB = b.boundingBox.width * b.boundingBox.height;
      return areaA >= areaB ? a : b;
    });
  }

  double _quality(Face face) {
    final box = face.boundingBox;
    final landmarks = [
      FaceLandmarkType.leftEye,
      FaceLandmarkType.rightEye,
      FaceLandmarkType.noseBase,
      FaceLandmarkType.leftMouth,
      FaceLandmarkType.rightMouth,
      FaceLandmarkType.bottomMouth,
      FaceLandmarkType.leftCheek,
      FaceLandmarkType.rightCheek,
    ];
    final present = landmarks.where((item) => face.landmarks[item] != null).length;
    final landmarkScore = (present / landmarks.length).clamp(0, 1).toDouble();
    final sizeScore = ((box.width * box.height) / 28000).clamp(0, 1).toDouble();
    final yaw = (face.headEulerAngleY ?? 0).abs();
    final roll = (face.headEulerAngleZ ?? 0).abs();
    final frontalScore = (1 - ((yaw + roll) / 70)).clamp(0, 1).toDouble();
    final eyes = (((face.leftEyeOpenProbability ?? 0.6) + (face.rightEyeOpenProbability ?? 0.6)) / 2)
        .clamp(0, 1)
        .toDouble();
    return (landmarkScore * 0.4) + (sizeScore * 0.2) + (frontalScore * 0.25) + (eyes * 0.15);
  }

  List<double> _landmarkSignature(Face face) {
    final box = face.boundingBox;
    final types = [
      FaceLandmarkType.leftEye,
      FaceLandmarkType.rightEye,
      FaceLandmarkType.noseBase,
      FaceLandmarkType.leftMouth,
      FaceLandmarkType.rightMouth,
      FaceLandmarkType.bottomMouth,
      FaceLandmarkType.leftCheek,
      FaceLandmarkType.rightCheek,
      FaceLandmarkType.leftEar,
      FaceLandmarkType.rightEar,
    ];
    final values = <double>[];
    for (final type in types) {
      final landmark = face.landmarks[type];
      if (landmark == null || box.width == 0 || box.height == 0) {
        values..add(-1)..add(-1);
        continue;
      }
      final x = ((landmark.position.x - box.left) / box.width).clamp(-0.5, 1.5).toDouble();
      final y = ((landmark.position.y - box.top) / box.height).clamp(-0.5, 1.5).toDouble();
      values..add(x)..add(y);
    }

    values.add((box.width / max(box.height, 1)).clamp(0, 4).toDouble());
    values.add(((face.headEulerAngleY ?? 0) / 45).clamp(-1, 1).toDouble());
    values.add(((face.headEulerAngleZ ?? 0) / 45).clamp(-1, 1).toDouble());
    values.add((face.smilingProbability ?? 0.5).clamp(0, 1).toDouble());
    values.add((face.leftEyeOpenProbability ?? 0.5).clamp(0, 1).toDouble());
    values.add((face.rightEyeOpenProbability ?? 0.5).clamp(0, 1).toDouble());
    values.add(_normalizedDistance(face.landmarks[FaceLandmarkType.leftEye], face.landmarks[FaceLandmarkType.rightEye], box));
    values.add(_normalizedDistance(face.landmarks[FaceLandmarkType.leftEye], face.landmarks[FaceLandmarkType.noseBase], box));
    values.add(_normalizedDistance(face.landmarks[FaceLandmarkType.rightEye], face.landmarks[FaceLandmarkType.noseBase], box));
    values.add(_normalizedDistance(face.landmarks[FaceLandmarkType.leftMouth], face.landmarks[FaceLandmarkType.rightMouth], box));
    values.add(_normalizedDistance(face.landmarks[FaceLandmarkType.noseBase], face.landmarks[FaceLandmarkType.bottomMouth], box));
    return values;
  }

  double _normalizedDistance(FaceLandmark? a, FaceLandmark? b, Rect box) {
    if (a == null || b == null || box.width == 0 || box.height == 0) {
      return -1;
    }
    final dx = (a.position.x - b.position.x).toDouble();
    final dy = (a.position.y - b.position.y).toDouble();
    return sqrt((dx * dx) + (dy * dy)) / max(box.width, box.height);
  }

  double _distance(List<double> left, List<double> right) {
    final length = min(left.length, right.length);
    double total = 0;
    int count = 0;
    for (var index = 0; index < length; index++) {
      final a = left[index];
      final b = right[index];
      if (a == -1 || b == -1) {
        continue;
      }
      final diff = a - b;
      total += diff * diff;
      count++;
    }
    if (count == 0) {
      return double.infinity;
    }
    return sqrt(total / count);
  }

  double _confidence(double distance) {
    if (_tfliteReady) {
      return (1 - (distance / 1.2)).clamp(0, 1).toDouble();
    }
    return (1 - (distance / 0.3)).clamp(0, 1).toDouble();
  }

  void dispose() {
    _detector?.close();
    _interpreter?.close();
  }
}

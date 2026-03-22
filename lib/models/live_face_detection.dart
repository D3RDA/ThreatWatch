import 'dart:ui';

import 'face_profile.dart';
import 'face_recognition_result.dart';

class LiveFaceDetection {
  final Rect boundingBox;
  final FaceRecognitionState state;
  final FaceProfile? profile;
  final double confidence;
  final double qualityScore;
  final String label;
  final String engineLabel;
  final int? trackingId;

  const LiveFaceDetection({
    required this.boundingBox,
    required this.state,
    required this.profile,
    required this.confidence,
    required this.qualityScore,
    required this.label,
    required this.engineLabel,
    this.trackingId,
  });

  bool get isRecognized => state == FaceRecognitionState.matched;

  LiveFaceDetection copyWith({
    Rect? boundingBox,
    FaceRecognitionState? state,
    FaceProfile? profile,
    double? confidence,
    double? qualityScore,
    String? label,
    String? engineLabel,
    int? trackingId,
  }) {
    return LiveFaceDetection(
      boundingBox: boundingBox ?? this.boundingBox,
      state: state ?? this.state,
      profile: profile ?? this.profile,
      confidence: confidence ?? this.confidence,
      qualityScore: qualityScore ?? this.qualityScore,
      label: label ?? this.label,
      engineLabel: engineLabel ?? this.engineLabel,
      trackingId: trackingId ?? this.trackingId,
    );
  }
}

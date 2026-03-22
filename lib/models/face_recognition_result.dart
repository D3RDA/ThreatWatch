
import 'face_profile.dart';

enum FaceRecognitionState {
  matched,
  possible,
  unknown,
  noFace,
  lowQuality,
  unsupported,
  multipleFaces,
}

class FaceCandidateScore {
  final FaceProfile profile;
  final double distance;
  final double confidence;

  const FaceCandidateScore({
    required this.profile,
    required this.distance,
    required this.confidence,
  });
}

class FaceRecognitionResult {
  final FaceRecognitionState state;
  final FaceProfile? profile;
  final double confidence;
  final double qualityScore;
  final int detectedFaces;
  final String message;
  final String engineLabel;
  final List<FaceCandidateScore> candidates;

  const FaceRecognitionResult({
    required this.state,
    required this.profile,
    required this.confidence,
    required this.qualityScore,
    required this.detectedFaces,
    required this.message,
    required this.engineLabel,
    required this.candidates,
  });

  bool get isMatch => state == FaceRecognitionState.matched || state == FaceRecognitionState.possible;
}

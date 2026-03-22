import 'package:camera/camera.dart';
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

  bool get isSuccess => false;
}

class FaceRecognitionService {
  bool get isSupported => false;
  String get preferredEngineLabel => 'Nem támogatott';

  Future<FaceSampleExtraction> extractSignatureFromPath(String imagePath) async {
    return const FaceSampleExtraction(
      signature: null,
      qualityScore: 0,
      message: 'Az arcfelismerő modul ezen a platformon nem támogatott.',
      detectedFaces: 0,
      engineLabel: 'Nem támogatott',
    );
  }

  Future<FaceRecognitionResult> recognizeFromPath(String imagePath, List<FaceProfile> profiles) async {
    return const FaceRecognitionResult(
      state: FaceRecognitionState.unsupported,
      profile: null,
      confidence: 0,
      qualityScore: 0,
      detectedFaces: 0,
      message: 'Az arcfelismerő modul ezen a platformon nem támogatott.',
      engineLabel: 'Nem támogatott',
      candidates: [],
    );
  }

  Future<List<LiveFaceDetection>> recognizeFacesInInputImage(
    Object inputImage,
    List<FaceProfile> profiles,
  ) async {
    return const [];
  }

  Future<List<LiveFaceDetection>> recognizeFacesInCameraFrame({
    required CameraImage cameraImage,
    required Object inputImage,
    required Object rotation,
    required CameraLensDirection lensDirection,
    required List<FaceProfile> profiles,
  }) async {
    return const [];
  }

  void dispose() {}
}

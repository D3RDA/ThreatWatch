
class FaceRecognitionLog {
  final String id;
  final String source;
  final String personName;
  final String outcome;
  final double confidence;
  final DateTime timestamp;
  final String note;

  const FaceRecognitionLog({
    required this.id,
    required this.source,
    required this.personName,
    required this.outcome,
    required this.confidence,
    required this.timestamp,
    required this.note,
  });

  factory FaceRecognitionLog.fromJson(Map<String, dynamic> json) {
    return FaceRecognitionLog(
      id: (json['id'] ?? '').toString(),
      source: (json['source'] ?? '').toString(),
      personName: (json['personName'] ?? '').toString(),
      outcome: (json['outcome'] ?? '').toString(),
      confidence: double.tryParse((json['confidence'] ?? '0').toString()) ?? 0,
      timestamp: DateTime.tryParse((json['timestamp'] ?? '').toString()) ?? DateTime.now(),
      note: (json['note'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source': source,
      'personName': personName,
      'outcome': outcome,
      'confidence': confidence,
      'timestamp': timestamp.toIso8601String(),
      'note': note,
    };
  }
}

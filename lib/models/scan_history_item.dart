import 'risk_level.dart';

class ScanHistoryItem {
  final String id;
  final String type;
  final String input;
  final RiskLevel level;
  final int score;
  final List<String> reasons;
  final String summary;
  final String source;
  final DateTime timestamp;

  const ScanHistoryItem({
    required this.id,
    required this.type,
    required this.input,
    required this.level,
    required this.score,
    required this.reasons,
    required this.summary,
    required this.source,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'input': input,
      'level': level.storageValue,
      'score': score,
      'reasons': reasons,
      'summary': summary,
      'source': source,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) {
    return ScanHistoryItem(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      input: (json['input'] ?? '').toString(),
      level: RiskLevelX.fromStorage((json['level'] ?? '').toString()),
      score: int.tryParse((json['score'] ?? '0').toString()) ?? 0,
      reasons:
          (json['reasons'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .toList(),
      summary: (json['summary'] ?? '').toString(),
      source: (json['source'] ?? '').toString(),
      timestamp:
          DateTime.tryParse((json['timestamp'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

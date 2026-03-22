import 'risk_level.dart';
import 'scan_history_item.dart';

class ThreatAssessment {
  final String type;
  final String input;
  final RiskLevel level;
  final int score;
  final List<String> reasons;
  final String summary;
  final String source;

  const ThreatAssessment({
    required this.type,
    required this.input,
    required this.level,
    required this.score,
    required this.reasons,
    required this.summary,
    required this.source,
  });

  ScanHistoryItem toHistoryItem() {
    return ScanHistoryItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      input: input,
      level: level,
      score: score,
      reasons: reasons,
      summary: summary,
      source: source,
      timestamp: DateTime.now(),
    );
  }
}

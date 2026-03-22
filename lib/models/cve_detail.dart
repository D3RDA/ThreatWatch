class CveDetail {
  final String cveId;
  final String description;
  final String severity;
  final double? baseScore;
  final String weakness;
  final List<String> references;

  const CveDetail({
    required this.cveId,
    required this.description,
    required this.severity,
    required this.baseScore,
    required this.weakness,
    required this.references,
  });
}

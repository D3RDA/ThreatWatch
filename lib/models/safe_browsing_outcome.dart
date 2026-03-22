class SafeBrowsingOutcome {
  final bool checked;
  final bool isUnsafe;
  final List<String> threatTypes;
  final String message;

  const SafeBrowsingOutcome({
    required this.checked,
    required this.isUnsafe,
    required this.threatTypes,
    required this.message,
  });

  factory SafeBrowsingOutcome.unavailable() {
    return const SafeBrowsingOutcome(
      checked: false,
      isUnsafe: false,
      threatTypes: [],
      message: 'Google Safe Browsing API kulcs nélkül csak helyi heurisztikák futnak.',
    );
  }
}

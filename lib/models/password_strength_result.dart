class PasswordStrengthResult {
  final int score;
  final String label;
  final List<String> feedback;

  const PasswordStrengthResult({
    required this.score,
    required this.label,
    required this.feedback,
  });
}

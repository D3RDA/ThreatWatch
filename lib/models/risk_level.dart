enum RiskLevel { safe, suspicious, dangerous }

extension RiskLevelX on RiskLevel {
  String get label {
    switch (this) {
      case RiskLevel.safe:
        return 'Biztonságos';
      case RiskLevel.suspicious:
        return 'Gyanús';
      case RiskLevel.dangerous:
        return 'Veszélyes';
    }
  }

  String get storageValue => name;

  static RiskLevel fromStorage(String value) {
    return RiskLevel.values.firstWhere(
      (item) => item.name == value,
      orElse: () => RiskLevel.suspicious,
    );
  }
}

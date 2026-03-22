class SecurityChecklist {
  final bool twoFactorEnabled;
  final bool deviceUpdated;
  final bool uniquePasswords;
  final bool backupsEnabled;
  final bool screenLockEnabled;
  final bool publicWifiCareful;

  const SecurityChecklist({
    required this.twoFactorEnabled,
    required this.deviceUpdated,
    required this.uniquePasswords,
    required this.backupsEnabled,
    required this.screenLockEnabled,
    required this.publicWifiCareful,
  });

  factory SecurityChecklist.empty() {
    return const SecurityChecklist(
      twoFactorEnabled: false,
      deviceUpdated: false,
      uniquePasswords: false,
      backupsEnabled: false,
      screenLockEnabled: false,
      publicWifiCareful: false,
    );
  }

  int get completedCount {
    return [
      twoFactorEnabled,
      deviceUpdated,
      uniquePasswords,
      backupsEnabled,
      screenLockEnabled,
      publicWifiCareful,
    ].where((item) => item).length;
  }

  double get progress => completedCount / 6;

  Map<String, dynamic> toJson() {
    return {
      'twoFactorEnabled': twoFactorEnabled,
      'deviceUpdated': deviceUpdated,
      'uniquePasswords': uniquePasswords,
      'backupsEnabled': backupsEnabled,
      'screenLockEnabled': screenLockEnabled,
      'publicWifiCareful': publicWifiCareful,
    };
  }

  factory SecurityChecklist.fromJson(Map<String, dynamic> json) {
    return SecurityChecklist(
      twoFactorEnabled: json['twoFactorEnabled'] == true,
      deviceUpdated: json['deviceUpdated'] == true,
      uniquePasswords: json['uniquePasswords'] == true,
      backupsEnabled: json['backupsEnabled'] == true,
      screenLockEnabled: json['screenLockEnabled'] == true,
      publicWifiCareful: json['publicWifiCareful'] == true,
    );
  }

  SecurityChecklist copyWith({
    bool? twoFactorEnabled,
    bool? deviceUpdated,
    bool? uniquePasswords,
    bool? backupsEnabled,
    bool? screenLockEnabled,
    bool? publicWifiCareful,
  }) {
    return SecurityChecklist(
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      deviceUpdated: deviceUpdated ?? this.deviceUpdated,
      uniquePasswords: uniquePasswords ?? this.uniquePasswords,
      backupsEnabled: backupsEnabled ?? this.backupsEnabled,
      screenLockEnabled: screenLockEnabled ?? this.screenLockEnabled,
      publicWifiCareful: publicWifiCareful ?? this.publicWifiCareful,
    );
  }
}

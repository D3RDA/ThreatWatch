class SavedCveEntry {
  final String cveId;
  final String note;
  final String status;
  final String priority;
  final DateTime updatedAt;

  const SavedCveEntry({
    required this.cveId,
    required this.note,
    required this.status,
    required this.priority,
    required this.updatedAt,
  });

  factory SavedCveEntry.empty(String cveId) {
    return SavedCveEntry(
      cveId: cveId,
      note: '',
      status: 'Új',
      priority: 'Közepes',
      updatedAt: DateTime.now(),
    );
  }

  factory SavedCveEntry.fromJson(Map<String, dynamic> json) {
    return SavedCveEntry(
      cveId: (json['cveId'] ?? '').toString(),
      note: (json['note'] ?? '').toString(),
      status: (json['status'] ?? 'Új').toString(),
      priority: (json['priority'] ?? 'Közepes').toString(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cveId': cveId,
      'note': note,
      'status': status,
      'priority': priority,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  SavedCveEntry copyWith({
    String? note,
    String? status,
    String? priority,
    DateTime? updatedAt,
  }) {
    return SavedCveEntry(
      cveId: cveId,
      note: note ?? this.note,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

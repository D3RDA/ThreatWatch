
class FaceSample {
  final List<double> signature;
  final double qualityScore;
  final DateTime createdAt;

  const FaceSample({
    required this.signature,
    required this.qualityScore,
    required this.createdAt,
  });

  factory FaceSample.fromJson(Map<String, dynamic> json) {
    return FaceSample(
      signature: (json['signature'] as List<dynamic>? ?? const [])
          .map((item) => double.tryParse(item.toString()) ?? 0)
          .toList(),
      qualityScore: double.tryParse((json['qualityScore'] ?? '0').toString()) ?? 0,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'signature': signature,
      'qualityScore': qualityScore,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class FaceProfile {
  final String id;
  final String name;
  final String label;
  final String note;
  final List<FaceSample> samples;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastSeenAt;

  const FaceProfile({
    required this.id,
    required this.name,
    required this.label,
    required this.note,
    required this.samples,
    required this.createdAt,
    required this.updatedAt,
    required this.lastSeenAt,
  });

  int get sampleCount => samples.length;

  double get averageQuality {
    if (samples.isEmpty) {
      return 0;
    }
    final total = samples.fold<double>(0, (sum, item) => sum + item.qualityScore);
    return total / samples.length;
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((item) => item.isNotEmpty).toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      final single = parts.first;
      return single.length >= 2 ? single.substring(0, 2).toUpperCase() : single.toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  factory FaceProfile.fromJson(Map<String, dynamic> json) {
    return FaceProfile(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      note: (json['note'] ?? '').toString(),
      samples: (json['samples'] as List<dynamic>? ?? const [])
          .map((item) => FaceSample.fromJson(item as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ?? DateTime.now(),
      lastSeenAt: DateTime.tryParse((json['lastSeenAt'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'label': label,
      'note': note,
      'samples': samples.map((item) => item.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastSeenAt': lastSeenAt?.toIso8601String(),
    };
  }

  FaceProfile copyWith({
    String? name,
    String? label,
    String? note,
    List<FaceSample>? samples,
    DateTime? updatedAt,
    DateTime? lastSeenAt,
  }) {
    return FaceProfile(
      id: id,
      name: name ?? this.name,
      label: label ?? this.label,
      note: note ?? this.note,
      samples: samples ?? this.samples,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}

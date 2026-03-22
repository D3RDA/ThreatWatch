import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/cve_detail.dart';

class NvdService {
  Future<CveDetail?> fetchCveDetail(String cveId) async {
    final uri = Uri.parse(
      'https://services.nvd.nist.gov/rest/json/cves/2.0?cveId=$cveId',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final vulnerabilities = json['vulnerabilities'] as List<dynamic>?;
      if (vulnerabilities == null || vulnerabilities.isEmpty) {
        return null;
      }

      final cve =
          (vulnerabilities.first as Map<String, dynamic>)['cve']
              as Map<String, dynamic>?;
      if (cve == null) {
        return null;
      }

      final description = _readDescription(cve);
      final severityAndScore = _readSeverityAndScore(cve);
      final weakness = _readWeakness(cve);
      final references = _readReferences(cve);

      return CveDetail(
        cveId: cveId,
        description: description,
        severity: severityAndScore.$1,
        baseScore: severityAndScore.$2,
        weakness: weakness,
        references: references,
      );
    } catch (_) {
      return null;
    }
  }

  String _readDescription(Map<String, dynamic> cve) {
    final descriptions = cve['descriptions'] as List<dynamic>? ?? [];
    for (final item in descriptions) {
      final entry = item as Map<String, dynamic>;
      if (entry['lang'] == 'en') {
        return (entry['value'] ?? '').toString();
      }
    }
    return 'Nincs részletes leírás.';
  }

  (String, double?) _readSeverityAndScore(Map<String, dynamic> cve) {
    final metrics = cve['metrics'] as Map<String, dynamic>? ?? {};
    final candidates = [
      metrics['cvssMetricV40'],
      metrics['cvssMetricV31'],
      metrics['cvssMetricV30'],
      metrics['cvssMetricV2'],
    ];

    for (final candidate in candidates) {
      final list = candidate as List<dynamic>?;
      if (list == null || list.isEmpty) {
        continue;
      }
      final first = list.first as Map<String, dynamic>;
      final severity = (first['baseSeverity'] ?? '').toString();
      final cvssData = first['cvssData'] as Map<String, dynamic>? ?? {};
      final baseScore =
          double.tryParse((cvssData['baseScore'] ?? '').toString());
      if (severity.isNotEmpty || baseScore != null) {
        return (severity.isNotEmpty ? severity : 'UNKNOWN', baseScore);
      }
    }

    return ('UNKNOWN', null);
  }

  String _readWeakness(Map<String, dynamic> cve) {
    final weaknesses = cve['weaknesses'] as List<dynamic>? ?? [];
    for (final weakness in weaknesses) {
      final descriptions =
          (weakness as Map<String, dynamic>)['description'] as List<dynamic>? ??
          [];
      for (final item in descriptions) {
        final entry = item as Map<String, dynamic>;
        if (entry['lang'] == 'en') {
          return (entry['value'] ?? '').toString();
        }
      }
    }
    return 'Nincs megadva';
  }

  List<String> _readReferences(Map<String, dynamic> cve) {
    final refs = cve['references'] as List<dynamic>? ?? [];
    return refs
        .map((item) => (item as Map<String, dynamic>)['url']?.toString() ?? '')
        .where((url) => url.isNotEmpty)
        .take(5)
        .toList();
  }
}

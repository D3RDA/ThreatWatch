import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/vulnerability_item.dart';

class CisaKevService {
  static final Uri _officialEndpoint = Uri.parse(
    'https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json',
  );

  static final Uri _mirrorEndpoint = Uri.parse(
    'https://raw.githubusercontent.com/cisagov/kev-data/develop/known_exploited_vulnerabilities.json',
  );

  Future<List<VulnerabilityItem>> fetchLatest() async {
    final responses = <Uri>[_officialEndpoint, _mirrorEndpoint];

    for (final endpoint in responses) {
      try {
        final response = await http.get(endpoint).timeout(
          const Duration(seconds: 12),
        );

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final vulnerabilities = body['vulnerabilities'] as List<dynamic>? ?? [];
          final items = vulnerabilities
              .map(
                (item) =>
                    VulnerabilityItem.fromJson(item as Map<String, dynamic>),
              )
              .toList();
          items.sort((a, b) {
            final left = a.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);
            final right = b.dateAdded ?? DateTime.fromMillisecondsSinceEpoch(0);
            return right.compareTo(left);
          });
          return items;
        }
      } catch (_) {
        // Try the mirror endpoint next.
      }
    }

    throw Exception('A KEV feed jelenleg nem érhető el.');
  }
}

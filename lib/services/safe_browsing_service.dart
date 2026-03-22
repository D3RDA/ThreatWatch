import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_secrets.dart';
import '../models/safe_browsing_outcome.dart';

class SafeBrowsingService {
  Future<SafeBrowsingOutcome> checkUrl(String url) async {
    if (AppSecrets.safeBrowsingApiKey.isEmpty) {
      return SafeBrowsingOutcome.unavailable();
    }

    final uri = Uri.parse(
      'https://safebrowsing.googleapis.com/v4/threatMatches:find?key=${AppSecrets.safeBrowsingApiKey}',
    );

    final payload = {
      'client': {
        'clientId': 'threatwatch-ai',
        'clientVersion': '1.0.0',
      },
      'threatInfo': {
        'threatTypes': [
          'MALWARE',
          'SOCIAL_ENGINEERING',
          'UNWANTED_SOFTWARE',
          'POTENTIALLY_HARMFUL_APPLICATION',
        ],
        'platformTypes': ['ANY_PLATFORM'],
        'threatEntryTypes': ['URL'],
        'threatEntries': [
          {'url': url},
        ],
      },
    };

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return const SafeBrowsingOutcome(
          checked: false,
          isUnsafe: false,
          threatTypes: [],
          message: 'A Safe Browsing ellenőrzés sikertelen volt.',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final matches = decoded['matches'] as List<dynamic>? ?? [];
      if (matches.isEmpty) {
        return const SafeBrowsingOutcome(
          checked: true,
          isUnsafe: false,
          threatTypes: [],
          message: 'A Google Safe Browsing nem jelzett ismert fenyegetést.',
        );
      }

      final threatTypes = matches
          .map(
            (item) =>
                (item as Map<String, dynamic>)['threatType']?.toString() ?? '',
          )
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();

      return SafeBrowsingOutcome(
        checked: true,
        isUnsafe: true,
        threatTypes: threatTypes,
        message: 'A Google Safe Browsing ismert veszélyként jelölte ezt az URL-t.',
      );
    } catch (_) {
      return const SafeBrowsingOutcome(
        checked: false,
        isUnsafe: false,
        threatTypes: [],
        message: 'A Safe Browsing kapcsolat közben hiba történt.',
      );
    }
  }
}

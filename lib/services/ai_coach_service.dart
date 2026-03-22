import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_secrets.dart';

class AiCoachService {
  Future<String> getAdvice({
    required String input,
    String context = 'general',
  }) async {
    if (input.trim().isEmpty) {
      return 'Írj be egy URL-t, üzenetet, CVE-t vagy rövid problémaleírást.';
    }

    if (AppSecrets.geminiApiKey.isEmpty) {
      return _offlineAdvice(input, context);
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${AppSecrets.geminiApiKey}',
    );

    final prompt = '''
Te egy rövid, gyakorlati kiberbiztonsági coach vagy magyar nyelven.
Feladatod:
- kockázat rövid értékelése
- 3 konkrét teendő prioritási sorrendben
- egyszerű, közérthető magyarázat

Kontextus: $context
Bemenet: $input

Válaszolj magyarul, tömören, 6-10 sorban.
''';

    final body = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 350,
      },
    };

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        return _offlineAdvice(input, context);
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List<dynamic>? ?? [];
      if (candidates.isEmpty) {
        return _offlineAdvice(input, context);
      }

      final content =
          (candidates.first as Map<String, dynamic>)['content']
              as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>? ?? [];
      if (parts.isEmpty) {
        return _offlineAdvice(input, context);
      }

      return (parts.first as Map<String, dynamic>)['text']?.toString() ??
          _offlineAdvice(input, context);
    } catch (_) {
      return _offlineAdvice(input, context);
    }
  }

  String _offlineAdvice(String input, String context) {
    final lower = input.toLowerCase();
    final bullets = <String>[];

    if (lower.contains('http') || lower.contains('link') || lower.contains('url')) {
      bullets.add('Ellenőrizd a domaint, a HTTPS használatát és a gyanús kulcsszavakat.');
      bullets.add('Ha kéretlen üzenetben kaptad, ne kattints közvetlenül a linkre.');
    }

    if (lower.contains('cve-')) {
      bullets.add('Azonosítsd az érintett terméket és verziót, majd ellenőrizd a gyártói frissítést.');
      bullets.add('Ha publikus szolgáltatás érintett, priorizáld a javítást vagy az ideiglenes mitigációt.');
    }

    if (lower.contains('email') || lower.contains('üzenet') || lower.contains('message')) {
      bullets.add('Vizsgáld meg a sürgető hangnemet, a hitelesítőadat-kérést és a rövidített linkeket.');
      bullets.add('Kérj másodlagos megerősítést ismert csatornán, mielőtt válaszolsz.');
    }

    if (bullets.isEmpty) {
      bullets.add('Prioritás 1: erősítsd meg, pontosan mi érintett.');
      bullets.add('Prioritás 2: csökkentsd a kitettséget frissítéssel, 2FA-val vagy hozzáférés-szűkítéssel.');
      bullets.add('Prioritás 3: naplózd a megfigyelést és ellenőrizd a kapcsolódó rendszereket is.');
    }

    return '''
Offline AI coach mód fut.
Kontextus: $context

Rövid értékelés:
A megadott bemenetet érdemes óvatosan kezelni, és előbb tényekkel ellenőrizni.

Teendők:
- ${bullets.join('\n- ')}
''';
  }
}

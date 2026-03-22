import '../models/password_strength_result.dart';
import '../models/risk_level.dart';
import '../models/safe_browsing_outcome.dart';
import '../models/threat_assessment.dart';

class HeuristicAnalysisService {
  static const _shorteners = [
    'bit.ly',
    'tinyurl.com',
    't.co',
    'goo.gl',
    'ow.ly',
    'buff.ly',
  ];

  static const _dangerWords = [
    'verify',
    'reset',
    'urgent',
    'bank',
    'bonus',
    'free',
    'invoice',
    'payment',
    'suspended',
    'security',
    'account',
    'login',
    'confirm',
  ];

  ThreatAssessment analyzeUrl(
    String rawInput,
    SafeBrowsingOutcome safeBrowsing,
  ) {
    final reasons = <String>[];
    var score = 0;

    Uri? uri;
    try {
      uri = Uri.parse(rawInput.trim());
    } catch (_) {
      uri = null;
    }

    if (uri == null || uri.host.isEmpty) {
      return const ThreatAssessment(
        type: 'url',
        input: '',
        level: RiskLevel.dangerous,
        score: 95,
        reasons: ['Az URL formátuma hibás vagy hiányos.'],
        summary: 'Hibás URL',
        source: 'Helyi heurisztika',
      );
    }

    if (safeBrowsing.checked && safeBrowsing.isUnsafe) {
      score += 70;
      reasons.add(
        'A Google Safe Browsing ismert fenyegetésként jelölte ezt az oldalt.',
      );
      if (safeBrowsing.threatTypes.isNotEmpty) {
        reasons.add('Fenyegetés típus: ${safeBrowsing.threatTypes.join(', ')}');
      }
    }

    if (uri.scheme != 'https') {
      score += 12;
      reasons.add('Az oldal nem HTTPS-t használ.');
    }

    if (_shorteners.contains(uri.host.toLowerCase())) {
      score += 18;
      reasons.add('URL-rövidítő szolgáltatást használ.');
    }

    if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(uri.host)) {
      score += 18;
      reasons.add('A domain helyett közvetlen IP-cím szerepel.');
    }

    if (uri.host.contains('--')) {
      score += 8;
      reasons.add('A domain több kötőjelet tartalmaz.');
    }

    if (uri.host.length > 35) {
      score += 8;
      reasons.add('Szokatlanul hosszú a domain.');
    }

    if (uri.path.length > 45) {
      score += 6;
      reasons.add('Szokatlanul hosszú az útvonal.');
    }

    final host = uri.host.toLowerCase();
    final allText = '$host ${uri.path} ${uri.query}'.toLowerCase();
    final hitWords = _dangerWords.where(allText.contains).toList();
    if (hitWords.isNotEmpty) {
      score += 4 * hitWords.length;
      reasons.add('Gyanús kulcsszavak: ${hitWords.join(', ')}');
    }

    final level = _scoreToLevel(score);
    if (reasons.isEmpty) {
      reasons.add('Nem találtunk erős gyanús jelet az URL-ben.');
    }

    final summary = switch (level) {
      RiskLevel.safe => 'Alacsony kockázat',
      RiskLevel.suspicious => 'Közepes kockázat',
      RiskLevel.dangerous => 'Magas kockázat',
    };

    return ThreatAssessment(
      type: 'url',
      input: rawInput.trim(),
      level: level,
      score: score.clamp(0, 100),
      reasons: reasons,
      summary: summary,
      source: safeBrowsing.checked
          ? 'Safe Browsing + helyi heurisztika'
          : 'Helyi heurisztika',
    );
  }

  ThreatAssessment analyzeMessage(String input) {
    final text = input.toLowerCase();
    final reasons = <String>[];
    var score = 0;

    if (text.contains('urgent') ||
        text.contains('azonnal') ||
        text.contains('sürgős')) {
      score += 15;
      reasons.add('Sürgető nyelvezet jelenik meg az üzenetben.');
    }

    if (text.contains('jelszó') ||
        text.contains('password') ||
        text.contains('login') ||
        text.contains('belép')) {
      score += 18;
      reasons.add('Hitelesítő adatok bekérésére utaló minták látszanak.');
    }

    if (text.contains('bank') ||
        text.contains('payment') ||
        text.contains('utalás') ||
        text.contains('invoice')) {
      score += 16;
      reasons.add('Pénzügyi vagy fizetési kérésre utaló tartalom található benne.');
    }

    if (text.contains('http://') ||
        text.contains('bit.ly') ||
        text.contains('tinyurl')) {
      score += 16;
      reasons.add('Az üzenet linket vagy rövidített URL-t tartalmaz.');
    }

    if (text.contains('nyeremény') ||
        text.contains('free') ||
        text.contains('gift') ||
        text.contains('ajándék')) {
      score += 10;
      reasons.add('Túl szép ajánlatra vagy jutalomra utaló elemek vannak benne.');
    }

    if (text.contains('melléklet') || text.contains('attachment')) {
      score += 8;
      reasons.add('Melléklet megnyitására próbálhat rávenni.');
    }

    final level = _scoreToLevel(score);
    if (reasons.isEmpty) {
      reasons.add('Nem találtunk egyértelmű phishing mintát a szövegben.');
    }

    final summary = switch (level) {
      RiskLevel.safe => 'Valószínűleg rendben van',
      RiskLevel.suspicious => 'Érdemes ellenőrizni',
      RiskLevel.dangerous => 'Erősen gyanús üzenet',
    };

    return ThreatAssessment(
      type: 'message',
      input: input.trim(),
      level: level,
      score: score.clamp(0, 100),
      reasons: reasons,
      summary: summary,
      source: 'Helyi phishing heurisztika',
    );
  }

  PasswordStrengthResult evaluatePassword(String password) {
    var score = 0;
    final feedback = <String>[];

    if (password.length >= 12) {
      score += 25;
    } else {
      feedback.add('Legyen legalább 12 karakter hosszú.');
    }

    if (RegExp(r'[A-Z]').hasMatch(password)) {
      score += 20;
    } else {
      feedback.add('Hiányzik a nagybetű.');
    }

    if (RegExp(r'[a-z]').hasMatch(password)) {
      score += 15;
    } else {
      feedback.add('Hiányzik a kisbetű.');
    }

    if (RegExp(r'\d').hasMatch(password)) {
      score += 20;
    } else {
      feedback.add('Hiányzik a szám.');
    }

    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      score += 20;
    } else {
      feedback.add('Hiányzik a speciális karakter.');
    }

    final label = score >= 80
        ? 'Erős'
        : score >= 55
        ? 'Közepes'
        : 'Gyenge';

    if (feedback.isEmpty) {
      feedback.add('Jó irány, ez a jelszó több alapvető elvárásnak megfelel.');
    }

    return PasswordStrengthResult(
      score: score.clamp(0, 100),
      label: label,
      feedback: feedback,
    );
  }

  RiskLevel _scoreToLevel(int score) {
    if (score >= 60) {
      return RiskLevel.dangerous;
    }
    if (score >= 30) {
      return RiskLevel.suspicious;
    }
    return RiskLevel.safe;
  }
}

import 'package:flutter/material.dart';

import '../services/ai_coach_service.dart';

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final _controller = TextEditingController();
  final _service = AiCoachService();

  String _context = 'general';
  bool _loading = false;
  String? _result;

  final _examples = const [
    'Mit tegyek, ha kaptam egy gyanús login oldalt tartalmazó emailt?',
    'Magyarázd el egyszerűen: CVE-2025-5777',
    'Mire figyeljek nyilvános Wi‑Fi használatakor?',
    'Egy üzenet sürgeti a jelszócserét. Mi a biztonságos ellenőrzési folyamat?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _askCoach() async {
    if (_controller.text.trim().isEmpty) {
      return;
    }

    setState(() {
      _loading = true;
    });

    final reply = await _service.getAdvice(
      input: _controller.text.trim(),
      context: _context,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _result = reply;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Az AI coach kulcs nélkül is használható offline szabályalapú módban. Ha beállítod a Gemini API kulcsot az app_secrets.dart fájlban, akkor generatív válaszokat ad.',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kérdés az AI coachhoz',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _context,
                  decoration: const InputDecoration(
                    labelText: 'Kontextus',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'general', child: Text('Általános tanács')), 
                    DropdownMenuItem(value: 'url_review', child: Text('URL / link értelmezés')), 
                    DropdownMenuItem(value: 'vulnerability_explanation', child: Text('Sebezhetőség magyarázat')), 
                    DropdownMenuItem(value: 'phishing_help', child: Text('Phishing segítség')), 
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _context = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  maxLines: 7,
                  decoration: const InputDecoration(
                    labelText: 'Írd be a kérdést vagy a problémát',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _examples
                      .map(
                        (item) => ActionChip(
                          label: Text(item),
                          onPressed: () {
                            setState(() {
                              _controller.text = item;
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _askCoach,
                  icon: const Icon(Icons.psychology_alt_outlined),
                  label: const Text('Tanács kérése'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SelectableText(
                    _result ??
                        'Az AI coach itt rövid, gyakorlati tanácsot ad: kockázatértékelést, prioritási sorrendet és egyszerű teendőlistát.',
                  ),
          ),
        ),
      ],
    );
  }
}

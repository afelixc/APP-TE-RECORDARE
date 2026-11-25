import 'dart:convert';

import 'ai_provider.dart';

/// IA de mentira para la vista web: lo que se escribe queda como recordatorio
/// para dentro de una hora. Solo sirve para mirar cómo se ve.
class DemoAiProvider implements AiProvider {
  const DemoAiProvider();

  @override
  String get id => 'claude';
  @override
  String get name => 'Prueba';
  @override
  String get defaultModel => 'prueba';
  @override
  List<(String, String)> get suggestedModels => const [];
  @override
  String get keyPrefix => '';
  @override
  String get keysUrl => '';
  @override
  String get billingUrl => '';
  @override
  List<String> get guideSteps => const [];

  @override
  Future<List<String>> listModels(String apiKey) async => ['prueba'];

  @override
  Future<AiResult> completeJson({
    required String apiKey,
    required String model,
    required String system,
    required String user,
    required Map<String, dynamic> schema,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final last = user.split('\n').last;
    final title = last
        .replaceAll(RegExp(r'^(Después dijo:\s*)', caseSensitive: false), '')
        .replaceAll(
          RegExp(r'\b(recordame|recordarme|acordame)\b', caseSensitive: false),
          '',
        )
        .trim();
    final now = DateTime.now().add(const Duration(hours: 1));
    String two(int n) => n.toString().padLeft(2, '0');
    return AiResult(
      jsonEncode({
        'reminders': [
          {
            'ok': true,
            'title': title.isEmpty ? 'Recordatorio de prueba' : title,
            'date': '${now.year}-${two(now.month)}-${two(now.day)}',
            'time': '${two(now.hour)}:${two(now.minute)}',
            'repeat': 'none',
            'weekdays': [],
            'dates': [],
            'in_minutes': 60,
            'message': '',
          },
        ],
        'message': '',
      }),
    );
  }
}

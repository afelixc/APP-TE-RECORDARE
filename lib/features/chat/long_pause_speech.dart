import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Reconocimiento de voz de Android pidiéndole pausas largas (canal
/// `recordame/voz`, `VoiceChannel.kt`). Hace lo mismo que usa [Dictation] del
/// plugin `speech_to_text`, así que `Dictation` lo usa igual.
class LongPauseSpeech implements SpeechToText {
  static const _channel = MethodChannel('recordame/voz');

  void Function(SpeechRecognitionResult)? _onResult;
  void Function(String)? _onStatus;
  bool _listening = false;

  @override
  bool get isListening => _listening;

  @override
  Future<bool> initialize({
    dynamic onError,
    dynamic onStatus,
    dynamic debugLogging = false,
    dynamic finalTimeout,
    dynamic options,
  }) async {
    _onStatus = onStatus as void Function(String)?;
    // El plugin es el que pide el permiso del micrófono.
    final permission = SpeechToText();
    final ok = await permission.initialize();
    await permission.cancel();
    if (!ok) return false;
    _channel.setMethodCallHandler(_fromPhone);
    return await _channel.invokeMethod<bool>('disponible') ?? false;
  }

  Future<dynamic> _fromPhone(MethodCall call) async {
    switch (call.method) {
      case 'texto':
        final args = Map<String, dynamic>.from(call.arguments as Map);
        _onResult?.call(
          SpeechRecognitionResult.init(
            [SpeechRecognitionWords(args['texto'] as String, null, 0.9)],
            args['final'] == true ? ResultType.finalResult : ResultType.partial,
          ),
        );
      case 'error':
        // El error ya viene seguido de "fin": con eso se vuelve a escuchar.
        break;
      case 'fin':
        _listening = false;
        _onStatus?.call(SpeechToText.doneStatus);
        _onStatus?.call(SpeechToText.notListeningStatus);
    }
  }

  @override
  Future<dynamic> listen({
    dynamic onResult,
    dynamic listenFor,
    dynamic pauseFor,
    dynamic localeId,
    dynamic onSoundLevelChange,
    dynamic cancelOnError = false,
    dynamic partialResults = true,
    dynamic onDevice = false,
    dynamic listenMode,
    dynamic sampleRate = 0,
    dynamic listenOptions,
  }) async {
    _onResult = onResult as void Function(SpeechRecognitionResult)?;
    final locale = ((listenOptions?.localeId ?? localeId) as String? ?? 'es_AR')
        .replaceAll('_', '-');
    _listening = true;
    final ok = await _channel.invokeMethod<bool>('escuchar', {
      'idioma': locale,
    });
    if (ok != true) _listening = false;
  }

  @override
  Future<void> stop() async {
    await _channel.invokeMethod<void>('parar');
  }

  @override
  Future<void> cancel() async {
    _listening = false;
    await _channel.invokeMethod<void>('cancelar');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

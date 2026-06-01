import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceService {
  static final SpeechToText _speech = SpeechToText();
  static bool _isInitialized = false;

  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    _isInitialized = await _speech.initialize(
      onError: (error) => debugPrint('STT Error: $error'),
      onStatus: (status) => debugPrint('STT Status: $status'),
    );
    return _isInitialized;
  }

  static bool get isListening => _speech.isListening;
  static bool get isAvailable => _speech.isAvailable;

  static Future<void> startListening({
    required Function(String text) onResult,
    required Function() onDone,
    String localeId = 'en_US',
  }) async {
    if (!_isInitialized) await initialize();
    if (!_isInitialized) return;

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenMode: ListenMode.confirmation,
        cancelOnError: false,
        partialResults: true,
      ),
    );
  }

  static Future<void> stopListening() async {
    await _speech.stop();
  }

  static Future<void> cancelListening() async {
    await _speech.cancel();
  }

  static Future<List<LocaleName>> getLocales() async {
    if (!_isInitialized) await initialize();
    return _speech.locales();
  }
}

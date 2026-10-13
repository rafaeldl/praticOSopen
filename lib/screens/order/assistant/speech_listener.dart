import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Turns speech into text. [DeviceSpeechListener] uses the phone's speech
/// recognition; tests inject a fake.
abstract class SpeechListener {
  /// Starts listening. [onWords] receives the whole text heard so far.
  /// Returns false when the microphone or speech recognition is not allowed
  /// or not available.
  Future<bool> start({
    required String localeId,
    required void Function(String words) onWords,
    required void Function() onDone,
  });

  Future<void> stop();
}

class DeviceSpeechListener implements SpeechListener {
  DeviceSpeechListener([SpeechToText? speech])
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  bool _ready = false;

  @override
  Future<bool> start({
    required String localeId,
    required void Function(String words) onWords,
    required void Function() onDone,
  }) async {
    try {
      _ready =
          _ready ||
          await _speech.initialize(
            onStatus: (status) {
              if (status == SpeechToText.doneStatus ||
                  status == SpeechToText.notListeningStatus) {
                onDone();
              }
            },
            onError: (_) => onDone(),
          );
      if (!_ready) return false;
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenFor: const Duration(minutes: 2),
          pauseFor: const Duration(seconds: 5),
          partialResults: true,
          listenMode: ListenMode.dictation,
        ),
        onResult: (SpeechRecognitionResult result) =>
            onWords(result.recognizedWords),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> stop() => _speech.stop();
}

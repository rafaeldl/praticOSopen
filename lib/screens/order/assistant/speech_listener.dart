import 'dart:async';

import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Turns speech into text. [DeviceSpeechListener] uses the phone's speech
/// recognition, keeps listening until the user taps stop and keeps the
/// screen on meanwhile; tests inject a fake.
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

/// One recognition session of the phone. It ends by itself after a pause or
/// when the system's time limit runs out (about a minute on iPhone).
abstract class SpeechEngine {
  /// [onEnded] is called once per session, when it ends by itself or with an
  /// error.
  Future<bool> init(void Function() onEnded);
  Future<void> listen(String localeId, void Function(String words) onWords);
  Future<void> stop();
}

/// Keeps listening across the phone's sessions: when one ends by itself
/// (a pause to think, or the system's limit), a new one starts and its words
/// go after the ones already heard. It only ends when the user taps stop,
/// after [silenceLimit] without new words, or after [maxDuration].
class DeviceSpeechListener implements SpeechListener {
  DeviceSpeechListener({
    SpeechEngine? engine,
    Future<void> Function(bool on)? setAwake,
    DateTime Function()? now,
  }) : _engine = engine ?? _PhoneSpeechEngine(),
       _setAwake = setAwake ?? _wakelock,
       _now = now ?? DateTime.now;

  static const silenceLimit = Duration(seconds: 20);
  static const maxDuration = Duration(minutes: 5);

  final SpeechEngine _engine;
  final Future<void> Function(bool on) _setAwake;
  final DateTime Function() _now;

  bool _ready = false;
  bool _active = false;
  bool _sessionOpen = false;
  String _localeId = '';
  String _before = '';
  String _session = '';
  DateTime _startedAt = DateTime(0);
  DateTime _lastWordsAt = DateTime(0);
  void Function(String words)? _onWords;
  void Function()? _onDone;

  @override
  Future<bool> start({
    required String localeId,
    required void Function(String words) onWords,
    required void Function() onDone,
  }) async {
    _localeId = localeId;
    _onWords = onWords;
    _onDone = onDone;
    _before = '';
    _session = '';
    _startedAt = _now();
    _lastWordsAt = _startedAt;
    try {
      _ready = _ready || await _engine.init(_sessionEnded);
      if (!_ready) return false;
      _active = true;
      _keepAwake(true);
      await _listen();
      return true;
    } catch (_) {
      _finish(notify: false);
      return false;
    }
  }

  @override
  Future<void> stop() {
    _finish(notify: false);
    return _engine.stop();
  }

  Future<void> _listen() {
    _sessionOpen = true;
    return _engine.listen(_localeId, (words) {
      if (!_active) return;
      if (words.trim() != _session.trim()) _lastWordsAt = _now();
      _session = words;
      _onWords?.call(_text);
    });
  }

  String get _text => [
    _before,
    _session,
  ].map((s) => s.trim()).where((s) => s.isNotEmpty).join(' ');

  /// A session ended by itself.
  Future<void> _sessionEnded() async {
    if (!_active || !_sessionOpen) return;
    _sessionOpen = false;
    _before = _text;
    _session = '';
    final now = _now();
    if (now.difference(_lastWordsAt) >= silenceLimit ||
        now.difference(_startedAt) >= maxDuration) {
      _finish(notify: true);
      return;
    }
    try {
      await _listen();
    } catch (_) {
      _finish(notify: true);
    }
  }

  void _finish({required bool notify}) {
    final wasActive = _active;
    _active = false;
    _sessionOpen = false;
    _keepAwake(false);
    if (notify && wasActive) _onDone?.call();
  }

  void _keepAwake(bool on) {
    _setAwake(on).catchError((_) {});
  }

  static Future<void> _wakelock(bool on) => WakelockPlus.toggle(enable: on);
}

class _PhoneSpeechEngine implements SpeechEngine {
  final SpeechToText _speech = SpeechToText();

  /// The phone may report the same end more than once (status and error);
  /// only the first one of each session counts.
  bool _listening = false;

  @override
  Future<bool> init(void Function() onEnded) {
    void ended() {
      if (!_listening) return;
      _listening = false;
      onEnded();
    }

    return _speech.initialize(
      onStatus: (status) {
        if (status == SpeechToText.doneStatus ||
            status == SpeechToText.notListeningStatus) {
          ended();
        }
      },
      onError: (_) => ended(),
    );
  }

  @override
  Future<void> listen(String localeId, void Function(String words) onWords) {
    _listening = true;
    return _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenFor: DeviceSpeechListener.maxDuration,
        pauseFor: const Duration(seconds: 10),
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
      onResult: (SpeechRecognitionResult result) =>
          onWords(result.recognizedWords),
    );
  }

  @override
  Future<void> stop() {
    _listening = false;
    return _speech.stop();
  }
}

/// Store screenshots and video only (`--dart-define=SCREENSHOT_MODE=true`):
/// "hears" a fixed sentence about the demo account's data, word by word,
/// so the real assistant fills the order without a microphone.
class ScriptedSpeechListener implements SpeechListener {
  static const sentences = {
    'pt': 'Onix da Juliana Costa, troca de óleo com filtro, '
        'alinhamento e balanceamento',
    'en': "Julia Carter's Civic, oil change with oil filter, "
        'wheel alignment and wheel balancing',
    'es': 'El Clio de Julia Martín, cambio de aceite con filtro, '
        'alineación y balanceo',
  };

  Timer? _timer;

  @override
  Future<bool> start({
    required String localeId,
    required void Function(String words) onWords,
    required void Function() onDone,
  }) async {
    final words = (sentences[localeId.split(RegExp('[-_]')).first] ??
            sentences['pt']!)
        .split(' ');
    var heard = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 280), (timer) {
      heard++;
      onWords(words.take(heard).join(' '));
      if (heard >= words.length) timer.cancel();
    });
    return true;
  }

  @override
  Future<void> stop() async => _timer?.cancel();
}

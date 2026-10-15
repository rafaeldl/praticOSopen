import 'package:flutter_test/flutter_test.dart';
import 'package:praticos/screens/order/assistant/speech_listener.dart';

class _FakeEngine implements SpeechEngine {
  void Function()? onEnded;
  void Function(String words)? onWords;
  int sessions = 0;
  bool stopped = false;

  @override
  Future<bool> init(void Function() onEnded) async {
    this.onEnded = onEnded;
    return true;
  }

  @override
  Future<void> listen(String localeId, void Function(String) onWords) async {
    sessions++;
    this.onWords = onWords;
  }

  @override
  Future<void> stop() async => stopped = true;
}

void main() {
  late _FakeEngine engine;
  late DateTime clock;
  late List<bool> awake;
  late DeviceSpeechListener listener;
  late List<String> heard;
  late int done;

  setUp(() {
    engine = _FakeEngine();
    clock = DateTime(2026, 10, 15, 10);
    awake = [];
    heard = [];
    done = 0;
    listener = DeviceSpeechListener(
      engine: engine,
      setAwake: (on) async => awake.add(on),
      now: () => clock,
    );
  });

  Future<void> start() => listener.start(
    localeId: 'pt_BR',
    onWords: heard.add,
    onDone: () => done++,
  );

  test('keeps the screen on while listening and lets it go on stop', () async {
    await start();
    expect(awake, [true]);
    await listener.stop();
    expect(awake.last, isFalse);
    expect(engine.stopped, isTrue);
  });

  test('a pause does not end it: a new session continues the text', () async {
    await start();
    engine.onWords!('troca de óleo');
    clock = clock.add(const Duration(seconds: 12));
    engine.onEnded!();
    await Future<void>.delayed(Duration.zero);

    expect(engine.sessions, 2);
    expect(done, 0);
    engine.onWords!('e pintura do capô');
    expect(heard.last, 'troca de óleo e pintura do capô');
  });

  test('ends by itself after a long silence', () async {
    await start();
    engine.onWords!('troca de óleo');
    clock = clock.add(DeviceSpeechListener.silenceLimit);
    engine.onEnded!();
    await Future<void>.delayed(Duration.zero);

    expect(done, 1);
    expect(engine.sessions, 1);
    expect(awake.last, isFalse);
  });

  test('stopping by the user does not call onDone', () async {
    await start();
    await listener.stop();
    engine.onEnded!();
    expect(done, 0);
    expect(engine.sessions, 1);
  });
}

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/widgets/app_sheet.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';
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

/// "Falar o serviço" (prototype "Nova OS · falar"): listens as soon as it
/// opens and shows what was heard. "Preencher a OS" pops with the text;
/// "Digitar em vez de falar" turns the text into a field. Pops null when
/// cancelled.
class SpeechInputSheet extends StatefulWidget {
  const SpeechInputSheet({super.key, this.listener});

  /// Defaults to [DeviceSpeechListener].
  final SpeechListener? listener;

  @override
  State<SpeechInputSheet> createState() => _SpeechInputSheetState();
}

class _SpeechInputSheetState extends State<SpeechInputSheet> {
  late final SpeechListener _listener =
      widget.listener ?? DeviceSpeechListener();
  final _controller = TextEditingController();

  bool _listening = false;
  bool _typing = false;
  bool _unavailable = false;

  /// Text kept from earlier takes, so "Falar de novo" adds to it.
  String _before = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  @override
  void dispose() {
    if (_listening) _listener.stop();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _listen() async {
    if (!mounted) return;
    _before = _controller.text.trim();
    setState(() {
      _listening = true;
      _typing = false;
    });
    final ok = await _listener.start(
      localeId: context.l10n.localeName,
      onWords: (words) {
        if (!mounted) return;
        _controller.text = [_before, words].where((s) => s.isNotEmpty).join(' ');
      },
      onDone: () {
        if (mounted && _listening) setState(() => _listening = false);
      },
    );
    if (!ok && mounted) {
      setState(() {
        _listening = false;
        _unavailable = true;
        _typing = true;
      });
    }
  }

  Future<void> _stop() async {
    await _listener.stop();
    if (mounted) setState(() => _listening = false);
  }

  Future<void> _type() async {
    if (_listening) await _stop();
    if (mounted) setState(() => _typing = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AppColors.text.resolveFrom(context);
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final heard = _controller.text.trim();
    return AppSheet(
      title: l10n.speechTitle,
      primaryLabel: l10n.speechFill,
      onAction: heard.isEmpty
          ? null
          : () async {
              if (_listening) await _stop();
              if (context.mounted) Navigator.pop(context, heard);
            },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pageMargin),
        children: [
          Text(
            _unavailable ? l10n.speechUnavailable : l10n.speechHint,
            key: const ValueKey('speech_hint'),
            style: AppTypography.callout.copyWith(color: secondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_typing)
            CupertinoTextField(
              key: const ValueKey('speech_text_field'),
              controller: _controller,
              autofocus: true,
              minLines: 3,
              maxLines: 8,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              padding: const EdgeInsets.all(AppSpacing.md),
              style: AppTypography.body.copyWith(color: text),
              decoration: BoxDecoration(
                color: AppColors.secondaryFill.resolveFrom(context),
                borderRadius: BorderRadius.circular(AppRadii.field),
              ),
            )
          else
            Text(
              heard.isEmpty ? l10n.speechListening : heard,
              key: const ValueKey('speech_heard'),
              style: AppTypography.title.copyWith(
                color: heard.isEmpty ? secondary : text,
                fontSize: 26,
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          if (!_unavailable)
            Center(child: _MicButton(listening: _listening, onStart: _listen, onStop: _stop)),
          if (!_typing)
            Center(
              child: CupertinoButton(
                key: const ValueKey('speech_type'),
                onPressed: _type,
                child: Text(
                  l10n.speechType,
                  style: AppTypography.callout.copyWith(
                    color: AppColors.accentText.resolveFrom(context),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Round button: red "stop" while listening, mic to talk again.
class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.listening,
    required this.onStart,
    required this.onStop,
  });

  final bool listening;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fill = listening
        ? AppColors.danger.resolveFrom(context)
        : AppColors.secondaryFill.resolveFrom(context);
    return Column(
      children: [
        Semantics(
          button: true,
          label: listening ? l10n.speechStop : l10n.speechStart,
          excludeSemantics: true,
          child: CupertinoButton(
            key: const ValueKey('speech_mic'),
            padding: EdgeInsets.zero,
            onPressed: listening ? onStop : onStart,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
              child: Icon(
                listening ? CupertinoIcons.stop_fill : CupertinoIcons.mic_fill,
                size: 30,
                color: listening
                    ? AppColors.onAccent.resolveFrom(context)
                    : AppColors.text.resolveFrom(context),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          listening ? l10n.speechStop : l10n.speechStart,
          style: AppTypography.label.copyWith(
            color: AppColors.textSecondary.resolveFrom(context),
          ),
        ),
      ],
    );
  }
}

import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_glass.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Pieces of the "Nova OS" sheet (prototype "Nova OS · campos por ordem de
/// importância"), drawn like the Lembretes and Calendário sheets: gray
/// background, white rounded cards, "X" and "✓" in glass at the top and the
/// assistant tools (Foto, Falar) in a glass bar at the bottom.

/// Radius of the white cards of the form.
const double kFormCardRadius = 26;

/// "X" | title | "✓" over the gray background. The "✓" is gray until the
/// order can be saved (HIG: inactive while the task is incomplete) and blue
/// filled once it can.
class NewOrderTopBar extends StatelessWidget {
  const NewOrderTopBar({
    super.key,
    required this.title,
    required this.onClose,
    required this.onSave,
    this.busy = false,
  });

  final String title;
  final VoidCallback onClose;

  /// Null while the order cannot be saved.
  final VoidCallback? onSave;

  /// Saving: a spinner takes the place of the "✓".
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.blockMargin,
        AppSpacing.md,
        AppSpacing.blockMargin,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          GlassBarButton(
            key: const ValueKey('new_order_close'),
            label: l10n.cancel,
            icon: CupertinoIcons.xmark,
            onPressed: onClose,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.bodyStrong.copyWith(
                color: AppColors.text.resolveFrom(context),
              ),
            ),
          ),
          if (busy)
            const SizedBox(
              key: ValueKey('new_order_saving'),
              width: AppSizes.minTouchTarget,
              height: AppSizes.minTouchTarget,
              child: CupertinoActivityIndicator(),
            )
          else
            _SaveButton(onPressed: onSave),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final icon = Icon(
      CupertinoIcons.checkmark_alt,
      color: enabled
          ? AppColors.onAccent.resolveFrom(context)
          : AppColors.textSecondary.resolveFrom(context),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: context.l10n.save,
      excludeSemantics: true,
      child: CupertinoButton(
        key: const ValueKey('new_order_save'),
        padding: EdgeInsets.zero,
        minimumSize: const Size(
          AppSizes.minTouchTarget,
          AppSizes.minTouchTarget,
        ),
        onPressed: onPressed,
        child: enabled
            // The one blue action of the sheet: opaque, not glass.
            ? Container(
                width: AppSizes.minTouchTarget,
                height: AppSizes.minTouchTarget,
                decoration: BoxDecoration(
                  color: AppColors.accent.resolveFrom(context),
                  shape: BoxShape.circle,
                ),
                child: icon,
              )
            : AppGlass(
                elevated: true,
                borderRadius: BorderRadius.circular(
                  AppSizes.minTouchTarget / 2,
                ),
                child: SizedBox(
                  width: AppSizes.minTouchTarget,
                  height: AppSizes.minTouchTarget,
                  child: icon,
                ),
              ),
      ),
    );
  }
}

/// White rounded card holding [FormRow]s, with an optional section title
/// above and a note below (gray, like "Marque este lembrete…").
class FormCard extends StatelessWidget {
  const FormCard({super.key, this.title, required this.children, this.note});

  final String? title;
  final List<Widget> children;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Container(
              height: 0.5,
              color: AppColors.separator.resolveFrom(context),
            ),
          ),
        );
      }
      rows.add(children[i]);
    }
    final secondary = AppColors.textSecondary.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.blockMargin,
        AppSpacing.lg,
        AppSpacing.blockMargin,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  title!,
                  style: AppTypography.callout.copyWith(
                    color: secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(kFormCardRadius),
            child: ColoredBox(
              color: AppColors.surface.resolveFrom(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rows,
              ),
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: Text(
                note!,
                key: const ValueKey('form_card_note'),
                style: AppTypography.label.copyWith(color: secondary),
              ),
            ),
        ],
      ),
    );
  }
}

/// One line of a [FormCard]: icon, title (and subtitle), value at the right
/// and "›" when it opens something. [accent] draws an "add" line in blue.
/// The text wraps; nothing is cut with an ellipsis.
class FormRow extends StatelessWidget {
  const FormRow({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.accent = false,
    this.marked = false,
    this.showChevron = true,
  });

  final String title;
  final IconData? icon;
  final String? subtitle;
  final String? value;

  /// Replaces [value] (e.g. the date pills).
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool accent;

  /// Filled by the assistant: a blue sparkle after the title.
  final bool marked;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final text = AppColors.text.resolveFrom(context);
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final accentText = AppColors.accentText.resolveFrom(context);
    final titleStyle = AppTypography.body.copyWith(
      color: accent ? accentText : text,
      fontWeight: accent ? FontWeight.w600 : null,
    );
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 54),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: icon == null
                  ? null
                  : Icon(
                      icon,
                      size: 22,
                      color: accent ? accentText : secondary,
                    ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (marked)
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '$title '),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Semantics(
                              label: context.l10n.orderAssistantMarked,
                              child: Icon(
                                CupertinoIcons.sparkles,
                                size: 16,
                                color: accentText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      style: titleStyle,
                    )
                  else
                    Text(title, style: titleStyle),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      style: AppTypography.label.copyWith(color: secondary),
                    ),
                ],
              ),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: trailing,
              )
            else if (value != null)
              // Tight, so the value hugs the right edge next to the chevron.
              Flexible(
                fit: FlexFit.tight,
                child: Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Text(
                    value!,
                    textAlign: TextAlign.end,
                    style: AppTypography.body.copyWith(
                      color: secondary,
                      fontFeatures: AppTypography.tabular,
                    ),
                  ),
                ),
              ),
            if (onTap != null && showChevron && !accent)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: Icon(
                  CupertinoIcons.chevron_forward,
                  size: 16,
                  color: AppColors.separator.resolveFrom(context),
                ),
              ),
          ],
        ),
      ),
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: content,
      ),
    );
  }
}

/// Gray pill with a value, like the dates of the Calendário sheet.
class FormPill extends StatelessWidget {
  const FormPill(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.secondaryFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: AppTypography.callout.copyWith(
          color: AppColors.text.resolveFrom(context),
          fontFeatures: AppTypography.tabular,
        ),
      ),
    );
  }
}

/// Photos attached in the sheet, as thumbnails in a row that wraps, with a
/// last tile to add more. Tapping a photo offers to remove it.
class FormPhotos extends StatelessWidget {
  const FormPhotos({
    super.key,
    required this.photos,
    required this.onAdd,
    required this.onTapPhoto,
  });

  final List<Uint8List> photos;
  final VoidCallback onAdd;
  final void Function(int index) onTapPhoto;

  static const double _size = 76;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final radius = BorderRadius.circular(14);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (var i = 0; i < photos.length; i++)
            Semantics(
              button: true,
              label: l10n.removePhoto,
              child: GestureDetector(
                key: ValueKey('new_order_photo_$i'),
                onTap: () => onTapPhoto(i),
                child: ClipRRect(
                  borderRadius: radius,
                  child: Image.memory(
                    photos[i],
                    width: _size,
                    height: _size,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => Container(
                      width: _size,
                      height: _size,
                      color: AppColors.secondaryFill.resolveFrom(context),
                    ),
                  ),
                ),
              ),
            ),
          Semantics(
            button: true,
            label: l10n.orderAssistantPhoto,
            excludeSemantics: true,
            child: GestureDetector(
              key: const ValueKey('new_order_photo_add'),
              onTap: onAdd,
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  color: AppColors.secondaryFill.resolveFrom(context),
                  borderRadius: radius,
                ),
                child: Icon(
                  CupertinoIcons.camera,
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

/// What the assistant bar at the bottom of the sheet is doing.
enum AssistantBarMode {
  /// "Foto" and "Falar" (only "Foto" without the AI assistant).
  idle,

  /// The microphone is on: "X", wave, "Ouvindo…" and the blue stop.
  listening,

  /// No microphone: "X", a text field and the blue send.
  typing,

  /// The assistant is reading what was said or the photos.
  reading,
}

/// Radius of the glass capsules of the assistant bar (half their height).
const double _kCapsuleRadius = AppSizes.primaryButtonHeight / 2;

/// Glass capsule of the assistant bar: the material of the navigation layer
/// (Liquid Glass), at least as tall as the main button.
class _GlassCapsule extends StatelessWidget {
  const _GlassCapsule({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return AppGlass(
      elevated: true,
      borderRadius: BorderRadius.circular(_kCapsuleRadius),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppSizes.primaryButtonHeight,
        ),
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}

/// Opaque floating surface for content shown over the form (what was heard,
/// the assistant's note). Glass stays only on the bar's controls.
class _OpaqueFloat extends StatelessWidget {
  const _OpaqueFloat({
    required this.child,
    required this.borderRadius,
    this.padding,
    this.minHeight = 0,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface.resolveFrom(context),
        borderRadius: borderRadius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Assistant tools at the bottom of the "Nova OS" sheet (prototype "Nova OS
/// · campos por ordem", "ouve ali mesmo" and "a IA lê ali mesmo"). Everything
/// happens here, without another screen:
/// - idle: "Foto" and "Falar" as glass capsules ("Falar" in blue);
/// - listening: "X" to cancel, a wave with "Ouvindo…" and a blue stop that
///   fills the order;
/// - typing (no microphone): "X", a field and a blue send;
/// - reading: a spinner with what the assistant is reading.
class AssistantBar extends StatelessWidget {
  const AssistantBar({
    super.key,
    required this.mode,
    required this.onPhoto,
    this.onTalk,
    this.onCancel,
    this.onStop,
    this.onSend,
    this.textController,
    this.readingLabel,
  });

  final AssistantBarMode mode;
  final VoidCallback onPhoto;

  /// Null without the AI assistant: only "Foto" (attach) shows.
  final VoidCallback? onTalk;

  /// "X" while listening or typing.
  final VoidCallback? onCancel;

  /// Blue stop while listening: stops and fills the order.
  final VoidCallback? onStop;

  /// Blue send while typing.
  final VoidCallback? onSend;
  final TextEditingController? textController;

  /// What the assistant is reading (mode [AssistantBarMode.reading]).
  final String? readingLabel;

  @override
  Widget build(BuildContext context) {
    return switch (mode) {
      AssistantBarMode.idle => _idle(context),
      AssistantBarMode.listening => _withCancel(context, _listening(context)),
      AssistantBarMode.typing => _withCancel(context, _typing(context)),
      AssistantBarMode.reading => _reading(context),
    };
  }

  Widget _idle(BuildContext context) {
    final l10n = context.l10n;
    Widget capsule({
      required Key key,
      required IconData icon,
      required String label,
      required String semantics,
      required Color color,
      required VoidCallback onPressed,
    }) {
      return Semantics(
        button: true,
        label: semantics,
        excludeSemantics: true,
        child: GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: _GlassCapsule(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    label,
                    style: AppTypography.body.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        capsule(
          key: const ValueKey('assistant_photo'),
          icon: CupertinoIcons.camera,
          label: l10n.orderAssistantPhoto,
          semantics: l10n.orderAssistantPhoto,
          color: AppColors.text.resolveFrom(context),
          onPressed: onPhoto,
        ),
        if (onTalk != null)
          capsule(
            key: const ValueKey('assistant_talk'),
            icon: CupertinoIcons.mic,
            label: l10n.orderAssistantTalkShort,
            semantics: l10n.orderTalkAction,
            color: AppColors.accentText.resolveFrom(context),
            onPressed: onTalk!,
          ),
      ],
    );
  }

  Widget _withCancel(BuildContext context, Widget main) {
    return Row(
      children: [
        Semantics(
          button: true,
          label: context.l10n.speechCancel,
          excludeSemantics: true,
          child: GestureDetector(
            key: const ValueKey('assistant_cancel'),
            behavior: HitTestBehavior.opaque,
            onTap: onCancel,
            child: AppGlass(
              elevated: true,
              borderRadius: BorderRadius.circular(_kCapsuleRadius),
              child: SizedBox.square(
                dimension: AppSizes.primaryButtonHeight,
                child: Icon(
                  CupertinoIcons.xmark,
                  size: 20,
                  color: AppColors.text.resolveFrom(context),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: main),
      ],
    );
  }

  /// Round blue button inside a capsule (stop or send).
  Widget _roundButton(
    BuildContext context, {
    required Key key,
    required String label,
    required Widget child,
    VoidCallback? onPressed,
  }) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          width: AppSizes.minTouchTarget,
          height: AppSizes.minTouchTarget,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled
                ? AppColors.accent.resolveFrom(context)
                : AppColors.secondaryFill.resolveFrom(context),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _listening(BuildContext context) {
    final l10n = context.l10n;
    final onAccent = AppColors.onAccent.resolveFrom(context);
    return _GlassCapsule(
      padding: const EdgeInsets.only(
        left: AppSpacing.lg,
        right: 7,
        top: 7,
        bottom: 7,
      ),
      child: Row(
        children: [
          const _Wave(),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              l10n.speechListening,
              style: AppTypography.body.copyWith(
                color: AppColors.text.resolveFrom(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _roundButton(
            context,
            key: const ValueKey('assistant_stop'),
            label: l10n.speechStopAndFill,
            onPressed: onStop,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: onAccent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typing(BuildContext context) {
    final l10n = context.l10n;
    final controller = textController!;
    return _GlassCapsule(
      padding: const EdgeInsets.only(left: AppSpacing.md, right: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: CupertinoTextField(
              key: const ValueKey('assistant_text_field'),
              controller: controller,
              autofocus: true,
              minLines: 1,
              maxLines: 4,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              placeholder: l10n.speechTypeHint,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              style: AppTypography.body.copyWith(
                color: AppColors.text.resolveFrom(context),
              ),
              decoration: null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => _roundButton(
                context,
                key: const ValueKey('assistant_send'),
                label: l10n.speechFill,
                onPressed: controller.text.trim().isEmpty ? null : onSend,
                child: Icon(
                  CupertinoIcons.arrow_up,
                  size: 20,
                  color: controller.text.trim().isEmpty
                      ? AppColors.textSecondary.resolveFrom(context)
                      : AppColors.onAccent.resolveFrom(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reading(BuildContext context) {
    return Center(
      child: _GlassCapsule(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                readingLabel ?? '',
                key: const ValueKey('assistant_busy'),
                style: AppTypography.body.copyWith(
                  color: AppColors.text.resolveFrom(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Five blue bars that pulse while the microphone is on. Still when the
/// iPhone asks for less motion.
class _Wave extends StatefulWidget {
  const _Wave();

  @override
  State<_Wave> createState() => _WaveState();
}

class _WaveState extends State<_Wave> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  static const _delays = [0.0, 0.2, 0.4, 0.1, 0.3];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.accent.resolveFrom(context);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final delay in _delays)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  width: 4,
                  height: 26 * _scale(delay),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 0.35..1, like the CSS pulse of the prototype.
  double _scale(double delay) {
    if (!_controller.isAnimating) return 0.7;
    final t = (_controller.value + 1 - delay) % 1;
    return 0.35 + 0.65 * (1 - (2 * t - 1).abs());
  }
}

/// What was heard so far, on an opaque card above the bar while listening
/// (it is content, so it is not glass).
class AssistantTranscript extends StatelessWidget {
  const AssistantTranscript({super.key, required this.heard});

  final String heard;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final secondary = AppColors.textSecondary.resolveFrom(context);
    return _OpaqueFloat(
      borderRadius: BorderRadius.circular(kFormCardRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.speechHint,
              style: AppTypography.label.copyWith(color: secondary),
            ),
            if (heard.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Semantics(
                liveRegion: true,
                child: Text(
                  '“$heard”',
                  key: const ValueKey('assistant_heard'),
                  style: AppTypography.title.copyWith(
                    color: AppColors.text.resolveFrom(context),
                    fontSize: 22,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Opaque note above the bar (content, not navigation): what the assistant did ("Preenchi o que está
/// marcado…" with "Desfazer") or why it could not (with "Fechar"). Takes
/// the place of an alert, so nothing interrupts the form.
class AssistantNote extends StatelessWidget {
  const AssistantNote({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.filled = false,
    this.icon,
    this.onClose,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  /// Shows an "X" beside the action, when the action does not close the note.
  final VoidCallback? onClose;

  /// The assistant filled the order: blue sparkle; otherwise a warning.
  final bool filled;

  /// Replaces the sparkle/warning (green): a note about something done, like
  /// "Pronta. Avisar Ana?" after a status change.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: _OpaqueFloat(
        borderRadius: BorderRadius.circular(_kCapsuleRadius),
        minHeight: AppSizes.primaryButtonHeight,
        padding: const EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.xs,
          top: AppSpacing.xs,
          bottom: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(
              icon ??
                  (filled
                      ? CupertinoIcons.sparkles
                      : CupertinoIcons.exclamationmark_circle),
              size: 20,
              color: icon != null
                  ? AppColors.success.resolveFrom(context)
                  : filled
                  ? AppColors.accentText.resolveFrom(context)
                  : AppColors.textSecondary.resolveFrom(context),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                key: const ValueKey('assistant_note'),
                style: AppTypography.callout.copyWith(
                  color: AppColors.text.resolveFrom(context),
                ),
              ),
            ),
            CupertinoButton(
              key: const ValueKey('assistant_note_action'),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              minimumSize: const Size.square(AppSizes.minTouchTarget),
              onPressed: onAction,
              child: Text(
                actionLabel,
                style: AppTypography.callout.copyWith(
                  color: AppColors.accentText.resolveFrom(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onClose != null)
              CupertinoButton(
                key: const ValueKey('assistant_note_close'),
                padding: EdgeInsets.zero,
                minimumSize: const Size.square(AppSizes.minTouchTarget),
                onPressed: onClose,
                child: Icon(
                  CupertinoIcons.xmark,
                  size: 18,
                  semanticLabel: context.l10n.close,
                  color: AppColors.textSecondary.resolveFrom(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

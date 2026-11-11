import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/order/new_order_form.dart' show AssistantNote;
import 'package:praticos/services/ai_form_photo_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_typography.dart';

/// What the AI's reading of a checklist photo turned into.
enum ChecklistAiNoticeKind {
  /// Filled the answer and/or the note: "Desfazer".
  filled,

  /// Saw something the person's note does not say: "Acrescentar".
  seenAlso,

  /// Read an answer different from the one given: "Trocar".
  differs,

  /// Dark, blurry or off target photo: "Tirar de novo".
  badPhoto,

  /// Found nothing to fill.
  nothing,

  /// No connection, server down: the checklist goes on without the AI.
  failed,

  /// The month's readings are used up.
  quota,
}

/// The opaque notice of one reading (never an alert, design system rule on
/// AI). [text] is what was filled, seen or read, already in words.
class ChecklistAiNotice {
  const ChecklistAiNotice({
    required this.itemId,
    required this.kind,
    this.text,
    this.issue,
  });

  final String itemId;
  final ChecklistAiNoticeKind kind;
  final String? text;
  final AiPhotoIssue? issue;

  /// Whether the notice offers an action on its question (not only "Fechar").
  bool get hasAction => switch (kind) {
    ChecklistAiNoticeKind.filled ||
    ChecklistAiNoticeKind.seenAlso ||
    ChecklistAiNoticeKind.differs ||
    ChecklistAiNoticeKind.badPhoto => true,
    _ => false,
  };
}

/// The notice above the bottom of the checklist. On another question than
/// its own ([questionLabel] not null) it says which one and offers "Ver"
/// ([onView]) instead of the action.
class ChecklistAiNoticeView extends StatelessWidget {
  const ChecklistAiNoticeView({
    super.key,
    required this.notice,
    required this.onAction,
    required this.onClose,
    this.questionLabel,
    this.onView,
  });

  final ChecklistAiNotice notice;
  final String? questionLabel;
  final VoidCallback onAction;
  final VoidCallback onClose;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = notice.text ?? '';
    var message = switch (notice.kind) {
      ChecklistAiNoticeKind.filled =>
        questionLabel == null ? l10n.checklistAiFilled(text) : text,
      ChecklistAiNoticeKind.seenAlso => l10n.checklistAiSeenAlso(text),
      ChecklistAiNoticeKind.differs => l10n.checklistAiDiffers(text),
      ChecklistAiNoticeKind.badPhoto => switch (notice.issue) {
        AiPhotoIssue.dark => l10n.checklistAiDark,
        AiPhotoIssue.blurry => l10n.checklistAiBlurry,
        _ => l10n.checklistAiOffTarget,
      },
      ChecklistAiNoticeKind.nothing => l10n.checklistAiNothing,
      ChecklistAiNoticeKind.failed => l10n.checklistAiFailed,
      ChecklistAiNoticeKind.quota => l10n.checklistAiQuota,
    };
    final elsewhere = questionLabel != null && notice.hasAction;
    if (elsewhere) message = l10n.checklistNoteLine(questionLabel!, message);
    final filled =
        notice.kind == ChecklistAiNoticeKind.filled ||
        notice.kind == ChecklistAiNoticeKind.seenAlso ||
        notice.kind == ChecklistAiNoticeKind.differs;
    final String label;
    final VoidCallback action;
    if (elsewhere && onView != null) {
      label = l10n.checklistAiView;
      action = onView!;
    } else {
      (label, action) = switch (notice.kind) {
        ChecklistAiNoticeKind.filled => (l10n.orderAssistantUndo, onAction),
        ChecklistAiNoticeKind.seenAlso => (l10n.checklistAiAppend, onAction),
        ChecklistAiNoticeKind.differs => (l10n.checklistAiUseAnswer, onAction),
        ChecklistAiNoticeKind.badPhoto => (l10n.checklistAiRetake, onAction),
        _ => (l10n.close, onClose),
      };
    }
    return AssistantNote(
      key: const ValueKey('checklist_ai_notice'),
      message: message,
      filled: filled,
      actionLabel: label,
      onAction: action,
      onClose: label == l10n.close ? null : onClose,
    );
  }
}

/// "✦ Lendo a foto…" under the photos while the AI reads.
class ChecklistAiReading extends StatelessWidget {
  const ChecklistAiReading({super.key});

  @override
  Widget build(BuildContext context) {
    final secondary = AppColors.textSecondary.resolveFrom(context);
    return Row(
      key: const ValueKey('checklist_ai_reading'),
      children: [
        Icon(
          CupertinoIcons.sparkles,
          size: 16,
          color: AppColors.accentText.resolveFrom(context),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            context.l10n.checklistAiReading,
            style: AppTypography.callout.copyWith(color: secondary),
          ),
        ),
      ],
    );
  }
}

/// The ✦ beside what the AI filled ([semanticLabel]: "Preenchido pela IA").
class ChecklistAiMark extends StatelessWidget {
  const ChecklistAiMark({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      CupertinoIcons.sparkles,
      size: size,
      semanticLabel: context.l10n.checklistAiFilledMark,
      color: AppColors.accentText.resolveFrom(context),
    );
  }
}

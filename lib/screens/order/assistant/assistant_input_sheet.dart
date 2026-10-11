import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/widgets/app_sheet.dart';
import 'package:praticos/services/ai_order_assist_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// What the user sends to the assistant in one go (one request = one order).
class AssistantInput {
  const AssistantInput({this.text, this.photos = const []});

  final String? text;
  final List<AiPhoto> photos;

  bool get isEmpty => (text?.trim().isEmpty ?? true) && photos.isEmpty;
}

/// "Falar o que fazer": a text field (the keyboard's dictation mic does the
/// talking, so the app never asks for microphone permission) plus the photos
/// taken with Foto. "Pronto" sends everything together. Pops with an
/// [AssistantInput], or null when cancelled.
class AssistantInputSheet extends StatefulWidget {
  const AssistantInputSheet({
    super.key,
    this.initialPhotos = const [],
    this.capturePhoto,
    this.maxPhotos = 4,
  });

  final List<AiPhoto> initialPhotos;

  /// Opens the camera; null hides "Tirar outra foto".
  final Future<AiPhoto?> Function()? capturePhoto;
  final int maxPhotos;

  @override
  State<AssistantInputSheet> createState() => _AssistantInputSheetState();
}

class _AssistantInputSheetState extends State<AssistantInputSheet> {
  final _controller = TextEditingController();
  late final List<AiPhoto> _photos = [...widget.initialPhotos];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  AssistantInput get _input =>
      AssistantInput(text: _controller.text, photos: _photos);

  Future<void> _addPhoto() async {
    final photo = await widget.capturePhoto?.call();
    if (photo != null && mounted) setState(() => _photos.add(photo));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final secondary = AppColors.textSecondary.resolveFrom(context);
    return AppSheet(
      title: l10n.orderTalkAction,
      actionLabel: l10n.orderAssistantDone,
      onAction: _input.isEmpty ? null : () => Navigator.pop(context, _input),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pageMargin),
        children: [
          if (_photos.isNotEmpty) ...[
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.field),
                  child: Image.memory(
                    _photos[i].bytes,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 72,
                      height: 72,
                      color: AppColors.secondaryFill.resolveFrom(context),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.orderAssistantPhotoCount(_photos.length),
              style: AppTypography.label.copyWith(color: secondary),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          CupertinoTextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 8,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            placeholder: l10n.orderAssistantPlaceholder,
            padding: const EdgeInsets.all(AppSpacing.md),
            style: AppTypography.body.copyWith(
              color: AppColors.text.resolveFrom(context),
            ),
            decoration: BoxDecoration(
              color: AppColors.surface.resolveFrom(context),
              borderRadius: BorderRadius.circular(AppRadii.field),
            ),
          ),
          if (widget.capturePhoto != null && _photos.length < widget.maxPhotos)
            Align(
              alignment: Alignment.centerLeft,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                onPressed: _addPhoto,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.camera),
                    const SizedBox(width: AppSpacing.sm),
                    Text(l10n.orderAssistantAddPhoto),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

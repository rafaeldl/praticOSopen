import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:praticos/extensions/context_extensions.dart';

class MessageInput extends StatefulWidget {
  final Future<void> Function(String text, bool isPublic) onSend;
  final bool isSending;
  final String? customerName;
  final VoidCallback? onAttachmentTap;
  final VoidCallback? onCameraTap;

  const MessageInput({
    super.key,
    required this.onSend,
    required this.isSending,
    this.customerName,
    this.onAttachmentTap,
    this.onCameraTap,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _controller = TextEditingController();
  bool _isHoldingForPublic = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend({bool isPublic = false}) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Confirm if sending to customer
    if (isPublic && widget.customerName != null) {
      final confirmed = await _showPublicConfirmation();
      if (confirmed != true) {
        setState(() => _isHoldingForPublic = false);
        return;
      }
    }

    _controller.clear();
    setState(() => _isHoldingForPublic = false);
    await widget.onSend(text, isPublic);
  }

  Future<bool?> _showPublicConfirmation() {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(context.l10n.sendToCustomer),
        content: Text(
            context.l10n.sendToCustomerDescription(widget.customerName ?? '')),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(context.l10n.cancel),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            child: Text(context.l10n.sendMessage),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (widget.isSending || _controller.text.trim().isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() => _isHoldingForPublic = true);
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_isHoldingForPublic) {
      _handleSend(isPublic: true);
    }
  }

  void _onLongPressCancel() {
    setState(() => _isHoldingForPublic = false);
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        border: Border(
          top: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attachment Button (+)
              if (widget.onAttachmentTap != null)
                CupertinoButton(
                  padding: const EdgeInsets.all(6),
                  minimumSize: Size.zero,
                  onPressed: widget.onAttachmentTap,
                  child: Icon(
                    CupertinoIcons.plus_circle_fill,
                    size: 28,
                    color: CupertinoColors.activeBlue,
                  ),
                ),
              const SizedBox(width: 4),
              // Text Field
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6.resolveFrom(context),
                    borderRadius: BorderRadius.circular(20),
                    border: _isHoldingForPublic
                        ? Border.all(
                            color: CupertinoColors.systemGreen,
                            width: 2,
                          )
                        : null,
                  ),
                  child: CupertinoTextField(
                    controller: _controller,
                    placeholder: context.l10n.typeMessage,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: const BoxDecoration(),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    style: TextStyle(
                      fontSize: 16,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Camera Button
              if (widget.onCameraTap != null && !hasText)
                CupertinoButton(
                  padding: const EdgeInsets.all(6),
                  minimumSize: Size.zero,
                  onPressed: widget.onCameraTap,
                  child: Icon(
                    CupertinoIcons.camera_fill,
                    size: 24,
                    color: CupertinoColors.activeBlue,
                  ),
                ),
              // Send Button
              if (hasText || widget.onCameraTap == null)
                GestureDetector(
                  onTap: widget.isSending ? null : () => _handleSend(),
                  onLongPressStart: _onLongPressStart,
                  onLongPressEnd: _onLongPressEnd,
                  onLongPressCancel: _onLongPressCancel,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(left: 2),
                    decoration: BoxDecoration(
                      color: _isHoldingForPublic
                          ? CupertinoColors.systemGreen
                          : CupertinoColors.activeBlue,
                      shape: BoxShape.circle,
                    ),
                    child: widget.isSending
                        ? const CupertinoActivityIndicator(
                            color: CupertinoColors.white,
                          )
                        : Icon(
                            _isHoldingForPublic
                                ? CupertinoIcons.paperplane_fill
                                : CupertinoIcons.arrow_up,
                            color: CupertinoColors.white,
                            size: 18,
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

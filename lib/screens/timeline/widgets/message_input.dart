import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/timeline/widgets/visibility_toggle.dart';

class MessageInput extends StatefulWidget {
  final Future<void> Function(String text, bool isPublic) onSend;
  final bool isSending;
  final String? customerName;
  final VoidCallback? onAttachmentTap;

  const MessageInput({
    super.key,
    required this.onSend,
    required this.isSending,
    this.customerName,
    this.onAttachmentTap,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _controller = TextEditingController();
  bool _isPublic = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Confirm if sending to customer
    if (_isPublic && widget.customerName != null) {
      final confirmed = await _showPublicConfirmation();
      if (confirmed != true) return;
    }

    _controller.clear();
    await widget.onSend(text, _isPublic);
  }

  Future<bool?> _showPublicConfirmation() {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(context.l10n.sendToCustomer),
        content: Text(
            context.l10n.sendToCustomerDescription(widget.customerName ?? '')),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text(context.l10n.cancel),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: false,
            child: Text(context.l10n.sendMessage),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Visibility Toggle
              VisibilityToggle(
                isPublic: _isPublic,
                onChanged: (value) => setState(() => _isPublic = value),
              ),
              const SizedBox(height: 8),
              // Input Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Attachment Button (+)
                  if (widget.onAttachmentTap != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(36, 36),
                        onPressed: widget.onAttachmentTap,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey5.resolveFrom(context),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.plus,
                            size: 20,
                            color: CupertinoColors.activeBlue.resolveFrom(context),
                          ),
                        ),
                      ),
                    ),
                  // Text Field
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 120),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6.resolveFrom(context),
                        borderRadius: BorderRadius.circular(20),
                        border: _isPublic
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        style: TextStyle(
                          fontSize: 16,
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
                        onSubmitted: (_) => _handleSend(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send Button
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: widget.isSending ? null : _handleSend,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _isPublic
                            ? CupertinoColors.systemGreen
                            : CupertinoColors.activeBlue,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: widget.isSending
                          ? const CupertinoActivityIndicator(
                              color: CupertinoColors.white,
                            )
                          : const Icon(
                              CupertinoIcons.arrow_up,
                              color: CupertinoColors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

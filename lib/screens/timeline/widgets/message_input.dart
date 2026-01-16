import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/membership.dart';
import 'package:praticos/screens/timeline/widgets/mention_autocomplete.dart';

class MessageInput extends StatefulWidget {
  final Future<void> Function(String text, bool isPublic, List<String> mentionIds) onSend;
  final bool isSending;
  final String? customerName;
  final VoidCallback? onAttachmentTap;
  final VoidCallback? onCameraTap;
  final List<Membership> collaborators;

  const MessageInput({
    super.key,
    required this.onSend,
    required this.isSending,
    this.customerName,
    this.onAttachmentTap,
    this.onCameraTap,
    this.collaborators = const [],
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isHoldingForPublic = false;
  bool _showMentionAutocomplete = false;
  String _mentionQuery = '';
  int _mentionStartIndex = -1;

  // Track mentioned user IDs
  final Set<String> _mentionedUserIds = {};

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    final selection = _controller.selection;

    if (!selection.isValid || selection.baseOffset != selection.extentOffset) {
      _hideMentionAutocomplete();
      return;
    }

    final cursorPos = selection.baseOffset;

    // Find if we're in a mention context (after @)
    int atIndex = -1;
    for (int i = cursorPos - 1; i >= 0; i--) {
      final char = text[i];
      if (char == '@') {
        atIndex = i;
        break;
      }
      if (char == ' ' || char == '\n') {
        break;
      }
    }

    if (atIndex >= 0) {
      // Check if @ is at start or after space/newline
      final isValidStart = atIndex == 0 ||
          text[atIndex - 1] == ' ' ||
          text[atIndex - 1] == '\n';

      if (isValidStart) {
        final query = text.substring(atIndex + 1, cursorPos);
        setState(() {
          _showMentionAutocomplete = true;
          _mentionQuery = query;
          _mentionStartIndex = atIndex;
        });
        return;
      }
    }

    _hideMentionAutocomplete();
  }

  void _hideMentionAutocomplete() {
    if (_showMentionAutocomplete) {
      setState(() {
        _showMentionAutocomplete = false;
        _mentionQuery = '';
        _mentionStartIndex = -1;
      });
    }
  }

  void _onMentionSelected(Membership membership) {
    final name = membership.user?.name ?? '';
    final userId = membership.userId;

    if (name.isEmpty || userId == null) return;

    // Track the mentioned user
    _mentionedUserIds.add(userId);

    // Replace @query with @Name
    final text = _controller.text;
    final cursorPos = _controller.selection.baseOffset;
    final beforeMention = text.substring(0, _mentionStartIndex);
    final afterMention = text.substring(cursorPos);
    final mentionText = '@$name ';

    final newText = beforeMention + mentionText + afterMention;
    final newCursorPos = beforeMention.length + mentionText.length;

    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(offset: newCursorPos);

    _hideMentionAutocomplete();
    _focusNode.requestFocus();
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

    // Extract mentioned user IDs from current text
    final mentionIds = _extractMentionIds(text);

    _controller.clear();
    _mentionedUserIds.clear();
    setState(() => _isHoldingForPublic = false);
    await widget.onSend(text, isPublic, mentionIds);
  }

  List<String> _extractMentionIds(String text) {
    // Find all @Name patterns and match with collaborators
    final mentionIds = <String>[];
    final mentionRegex = RegExp(r'@(\S+)');
    final matches = mentionRegex.allMatches(text);

    for (final match in matches) {
      final mentionName = match.group(1)?.toLowerCase();
      if (mentionName == null) continue;

      // Find collaborator with matching name
      for (final collab in widget.collaborators) {
        final collabName = collab.user?.name?.toLowerCase() ?? '';
        // Check if the mention matches the start of the name (first word)
        final firstName = collabName.split(' ').first;
        if (firstName == mentionName || collabName == mentionName) {
          if (collab.userId != null && !mentionIds.contains(collab.userId)) {
            mentionIds.add(collab.userId!);
          }
          break;
        }
      }
    }

    // Also include any IDs we tracked during typing
    for (final id in _mentionedUserIds) {
      if (!mentionIds.contains(id)) {
        mentionIds.add(id);
      }
    }

    return mentionIds;
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mention autocomplete overlay
        if (_showMentionAutocomplete && widget.collaborators.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: MentionAutocomplete(
              collaborators: widget.collaborators,
              query: _mentionQuery,
              onSelect: _onMentionSelected,
              onDismiss: _hideMentionAutocomplete,
            ),
          ),
        Container(
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
                        focusNode: _focusNode,
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
        ),
      ],
    );
  }
}

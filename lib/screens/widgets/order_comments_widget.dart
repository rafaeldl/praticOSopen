import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider;
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/order_comment.dart';
import 'package:praticos/services/format_service.dart';

/// Widget to display and add comments on an order
class OrderCommentsWidget extends StatefulWidget {
  final String orderId;
  final String companyId;
  final bool showInternalToggle;
  final String? highlightCommentId;

  const OrderCommentsWidget({
    super.key,
    required this.orderId,
    required this.companyId,
    this.showInternalToggle = true,
    this.highlightCommentId,
  });

  @override
  State<OrderCommentsWidget> createState() => _OrderCommentsWidgetState();
}

class _OrderCommentsWidgetState extends State<OrderCommentsWidget> {
  final TextEditingController _commentController = TextEditingController();
  final FormatService _formatService = FormatService();
  final Map<String, GlobalKey> _commentKeys = {};
  bool _isInternal = false;
  bool _isSending = false;
  bool _hasScrolledToComment = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _scrollToComment(String commentId) {
    if (_hasScrolledToComment) return;
    _hasScrolledToComment = true;

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final key = _commentKeys[commentId];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.3,
        );
      }
    });
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      final user = Global.currentUser;
      final comment = {
        'text': text,
        'authorType': 'internal',
        'author': {
          'name': user?.displayName ?? 'Equipe',
          'userId': user?.uid,
          'email': user?.email,
        },
        'source': 'app',
        'isInternal': _isInternal,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('orders')
          .doc(widget.orderId)
          .collection('comments')
          .add(comment);

      _commentController.clear();
    } catch (e) {
      // Show error dialog
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(context.l10n.errorOccurred),
            content: Text(e.toString()),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _formatService.setLocale(context.l10n.localeName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header - same style as other sections
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 8),
          child: Text(
            context.l10n.comments.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ),

        // Comments list in grouped card
        _buildCommentsList(),
      ],
    );
  }

  Widget _buildCommentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyId)
          .collection('orders')
          .doc(widget.orderId)
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildGroupedCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${context.l10n.errorOccurred}: ${snapshot.error}',
                  style: TextStyle(
                    color: CupertinoColors.systemRed.resolveFrom(context),
                  ),
                ),
              ),
            ],
          );
        }

        if (!snapshot.hasData) {
          return _buildGroupedCard(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CupertinoActivityIndicator()),
              ),
            ],
          );
        }

        final comments = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final comment = OrderComment.fromJson(data);
          comment.id = doc.id;
          return comment;
        }).where((c) => c.deleted != true).toList();

        // Scroll to highlighted comment after build
        if (widget.highlightCommentId != null && !_hasScrolledToComment && comments.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToComment(widget.highlightCommentId!);
          });
        }

        return _buildGroupedCard(
          children: [
            if (comments.isEmpty)
              _buildEmptyState()
            else
              ...comments.asMap().entries.map((entry) {
                final index = entry.key;
                final comment = entry.value;
                final isHighlighted = comment.id == widget.highlightCommentId;
                return _buildCommentRow(
                  comment,
                  isLast: index == comments.length - 1,
                  isHighlighted: isHighlighted,
                );
              }),
            // Divider before input
            Divider(
              height: 1,
              color: CupertinoColors.separator.resolveFrom(context),
            ),
            // Input row
            _buildCommentInput(),
          ],
        );
      },
    );
  }

  Widget _buildGroupedCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.chat_bubble_2,
            size: 20,
            color: CupertinoColors.tertiaryLabel.resolveFrom(context),
          ),
          const SizedBox(width: 12),
          Text(
            context.l10n.noComments,
            style: TextStyle(
              fontSize: 16,
              color: CupertinoColors.tertiaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentRow(OrderComment comment, {bool isLast = false, bool isHighlighted = false}) {
    final isCustomer = comment.authorType == 'customer';
    final isInternal = comment.isInternal == true;

    // Create or get key for this comment
    if (comment.id != null) {
      _commentKeys.putIfAbsent(comment.id!, () => GlobalKey());
    }

    // Icon and color based on comment type
    IconData icon;
    Color iconColor;
    Color? badgeColor;
    String? badgeText;

    if (isCustomer) {
      icon = CupertinoIcons.person_fill;
      iconColor = CupertinoColors.systemGreen;
    } else if (isInternal) {
      icon = CupertinoIcons.lock_fill;
      iconColor = CupertinoColors.systemOrange;
      badgeColor = CupertinoColors.systemOrange;
      badgeText = context.l10n.internalComment;
    } else {
      icon = CupertinoIcons.person_2_fill;
      iconColor = CupertinoColors.activeBlue;
    }

    return Column(
      key: comment.id != null ? _commentKeys[comment.id!] : null,
      children: [
        Container(
          color: isHighlighted
              ? CupertinoColors.systemYellow.withValues(alpha: 0.2)
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon indicator
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author row
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            comment.author?.name ??
                                (isCustomer ? context.l10n.commentFromCustomer : context.l10n.commentFromTeam),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badgeText,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Timestamp
                    Text(
                      comment.createdAt != null
                          ? _formatService.formatDateTime(comment.createdAt!)
                          : '',
                      style: TextStyle(
                        fontSize: 11,
                        color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Comment text
                    Text(
                      comment.text ?? '',
                      style: TextStyle(
                        fontSize: 15,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 60,
            color: CupertinoColors.separator.resolveFrom(context),
          ),
      ],
    );
  }

  Widget _buildCommentInput() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Internal toggle
          if (widget.showInternalToggle)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  CupertinoSwitch(
                    value: _isInternal,
                    onChanged: (value) {
                      setState(() {
                        _isInternal = value;
                      });
                    },
                    activeTrackColor: CupertinoColors.systemOrange,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isInternal ? context.l10n.internalComment : context.l10n.publicComment,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _isInternal
                            ? CupertinoColors.systemOrange
                            : CupertinoColors.activeBlue,
                      ),
                    ),
                  ),
                  Icon(
                    _isInternal ? CupertinoIcons.lock_fill : CupertinoIcons.globe,
                    size: 16,
                    color: _isInternal
                        ? CupertinoColors.systemOrange
                        : CupertinoColors.activeBlue,
                  ),
                ],
              ),
            ),

          // Input row
          Row(
            children: [
              Expanded(
                child: CupertinoTextField(
                  controller: _commentController,
                  placeholder: context.l10n.commentPlaceholder,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6.resolveFrom(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  maxLines: null,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendComment(),
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: const EdgeInsets.all(10),
                minimumSize: Size.zero,
                color: CupertinoColors.activeBlue,
                borderRadius: BorderRadius.circular(20),
                onPressed: _isSending ? null : _sendComment,
                child: _isSending
                    ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                    : const Icon(
                        CupertinoIcons.paperplane_fill,
                        color: CupertinoColors.white,
                        size: 18,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

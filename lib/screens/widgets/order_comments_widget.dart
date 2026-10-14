import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/global.dart';
import 'package:praticos/models/order_comment.dart';
import 'package:praticos/screens/widgets/app_toast.dart';
import 'package:praticos/screens/widgets/section_label.dart';
import 'package:praticos/services/format_service.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';
import 'package:praticos/theme/app_typography.dart';

/// Sends a comment: the text and whether only the team sees it.
typedef OrderCommentSender = Future<void> Function(String text, bool internal);

/// Comments of an order as a message thread (author and time in
/// `textSecondary`, the text wrapping under them) with the box to write a new
/// one at the end: "Só a equipe vê" switch, field and send.
///
/// [expand] fills the available height: the thread scrolls and the box stays
/// at the bottom (comments screen). Without it the widget sizes to its
/// content, under a "Comentários" label (legacy order form).
class OrderCommentsWidget extends StatefulWidget {
  final String orderId;
  final String companyId;
  final bool showInternalToggle;
  final String? highlightCommentId;
  final bool expand;

  /// Test seam; defaults to the order's `comments` subcollection.
  final Stream<List<OrderComment>>? commentsStream;

  /// Test seam; defaults to adding the comment to Firestore.
  final OrderCommentSender? onSend;

  const OrderCommentsWidget({
    super.key,
    required this.orderId,
    required this.companyId,
    this.showInternalToggle = true,
    this.highlightCommentId,
    this.expand = false,
    this.commentsStream,
    this.onSend,
  });

  @override
  State<OrderCommentsWidget> createState() => _OrderCommentsWidgetState();
}

class _OrderCommentsWidgetState extends State<OrderCommentsWidget> {
  final TextEditingController _commentController = TextEditingController();
  final FormatService _formatService = FormatService();
  final Map<String, GlobalKey> _commentKeys = {};
  late final Stream<List<OrderComment>> _stream = _watch();
  bool _isInternal = false;
  bool _isSending = false;
  bool _hasScrolledToComment = false;

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _commentController.removeListener(_onTextChanged);
    _commentController.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  Stream<List<OrderComment>> _watch() {
    final injected = widget.commentsStream;
    if (injected != null) return injected;
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('orders')
        .doc(widget.orderId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => [
            for (final doc in snapshot.docs)
              OrderComment.fromJson(doc.data())..id = doc.id,
          ].where((c) => c.deleted != true).toList(),
        );
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

  Future<void> _addToFirestore(String text, bool internal) {
    final user = Global.currentUser;
    return FirebaseFirestore.instance
        .collection('companies')
        .doc(widget.companyId)
        .collection('orders')
        .doc(widget.orderId)
        .collection('comments')
        .add({
          'text': text,
          'authorType': 'internal',
          'author': {
            'name': user?.displayName ?? 'Equipe',
            'userId': user?.uid,
            'email': user?.email,
          },
          'source': 'app',
          'isInternal': internal,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      await (widget.onSend ?? _addToFirestore)(text, _isInternal);
      _commentController.clear();
    } catch (_) {
      if (mounted) {
        showAppToast(
          context,
          context.l10n.commentSendError,
          icon: CupertinoIcons.exclamationmark_circle_fill,
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _formatService.setLocale(context.l10n.localeName);

    final thread = StreamBuilder<List<OrderComment>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _line(
            context.l10n.listLoadError,
            key: const ValueKey('order_comments_error'),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CupertinoActivityIndicator()),
          );
        }
        final comments = snapshot.data!;
        if (comments.isEmpty) {
          return _line(
            context.l10n.commentsEmpty,
            key: const ValueKey('order_comments_empty'),
          );
        }

        if (widget.highlightCommentId != null && !_hasScrolledToComment) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToComment(widget.highlightCommentId!);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final comment in comments) _buildCommentRow(comment)],
        );
      },
    );

    if (widget.expand) {
      return Column(
        children: [
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              children: [thread],
            ),
          ),
          _buildCommentInput(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(context.l10n.comments),
        thread,
        _buildCommentInput(),
      ],
    );
  }

  /// One line of `textSecondary` text (empty thread, load error).
  Widget _line(String text, {Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageMargin,
        vertical: AppSpacing.lg,
      ),
      child: Text(
        text,
        style: AppTypography.callout.copyWith(
          color: AppColors.textSecondary.resolveFrom(context),
        ),
      ),
    );
  }

  String _author(OrderComment comment) {
    final l10n = context.l10n;
    final userId = comment.author?.userId;
    if (userId != null && userId == Global.currentUser?.uid) {
      return l10n.orderCommentYou;
    }
    final name = comment.author?.name?.trim() ?? '';
    final isCustomer = comment.authorType == 'customer';
    if (name.isEmpty) {
      return isCustomer ? l10n.commentFromCustomer : l10n.commentFromTeam;
    }
    return isCustomer ? '$name · ${l10n.commentFromCustomer}' : name;
  }

  Widget _buildCommentRow(OrderComment comment) {
    if (comment.id != null) {
      _commentKeys.putIfAbsent(comment.id!, () => GlobalKey());
    }
    final highlighted =
        comment.id != null && comment.id == widget.highlightCommentId;
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final meta = [
      _author(comment),
      if (comment.createdAt != null)
        _formatService.formatDateTime(comment.createdAt!),
      if (comment.isInternal == true) context.l10n.commentTeamOnlyTag,
    ].join(' · ');

    return Container(
      key: comment.id != null ? _commentKeys[comment.id!] : null,
      color: highlighted ? AppColors.accentSoft.resolveFrom(context) : null,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.separator.resolveFrom(context),
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (comment.isInternal == true)
                  Padding(
                    padding: const EdgeInsets.only(
                      right: AppSpacing.xs,
                      top: 2,
                    ),
                    child: Icon(
                      CupertinoIcons.lock_fill,
                      size: 14,
                      color: secondary,
                    ),
                  ),
                Expanded(
                  child: Text(
                    meta,
                    style: AppTypography.label.copyWith(color: secondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              comment.text ?? '',
              style: AppTypography.body.copyWith(
                color: AppColors.text.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentInput() {
    final l10n = context.l10n;
    final text = AppColors.text.resolveFrom(context);
    final secondary = AppColors.textSecondary.resolveFrom(context);
    final canSend = _commentController.text.trim().isNotEmpty && !_isSending;

    final box = Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.blockMargin,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showInternalToggle)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.sm,
                right: AppSpacing.sm,
                bottom: AppSpacing.sm,
              ),
              child: MergeSemantics(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.commentsTeamOnly,
                            style: AppTypography.callout.copyWith(color: text),
                          ),
                          Text(
                            _isInternal
                                ? l10n.commentsCustomerHidden
                                : l10n.commentsCustomerSees,
                            key: const ValueKey('order_comments_audience'),
                            style: AppTypography.label.copyWith(
                              color: secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    CupertinoSwitch(
                      key: const ValueKey('order_comments_internal'),
                      value: _isInternal,
                      onChanged: (value) => setState(() => _isInternal = value),
                    ),
                  ],
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: CupertinoTextField(
                  key: const ValueKey('order_comments_field'),
                  controller: _commentController,
                  placeholder: l10n.commentPlaceholder,
                  style: AppTypography.body.copyWith(color: text),
                  placeholderStyle: AppTypography.body.copyWith(
                    color: secondary,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryFill.resolveFrom(context),
                    borderRadius: BorderRadius.circular(AppRadii.field),
                  ),
                  maxLines: 5,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendComment(),
                ),
              ),
              Semantics(
                button: true,
                enabled: canSend,
                label: l10n.send,
                excludeSemantics: true,
                child: CupertinoButton(
                  key: const ValueKey('order_comments_send'),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(
                    AppSizes.minTouchTarget,
                    AppSizes.minTouchTarget,
                  ),
                  onPressed: canSend ? _sendComment : null,
                  child: _isSending
                      ? const CupertinoActivityIndicator()
                      : Icon(
                          CupertinoIcons.arrow_up_circle_fill,
                          size: 32,
                          color: canSend
                              ? AppColors.accent.resolveFrom(context)
                              : secondary,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (!widget.expand) return box;
    return Container(
      color: AppColors.background.resolveFrom(context),
      child: SafeArea(top: false, child: box),
    );
  }
}

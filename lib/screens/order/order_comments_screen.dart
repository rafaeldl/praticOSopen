import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/models/order_comment.dart';
import 'package:praticos/screens/widgets/glass_bar_button.dart';
import 'package:praticos/screens/widgets/order_comments_widget.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_typography.dart';

/// All comments of an order, as a thread, with the box to write a new one
/// (only for the team or also for the customer) at the bottom. Opened from
/// "Ver todos" and "Comentário" of the order screen, which only shows the
/// last two.
class OrderCommentsScreen extends StatelessWidget {
  const OrderCommentsScreen({
    super.key,
    required this.orderId,
    required this.companyId,
    this.highlightCommentId,
    this.commentsStream,
    this.onSend,
  });

  final String orderId;
  final String companyId;
  final String? highlightCommentId;

  /// Test seams, passed to [OrderCommentsWidget].
  final Stream<List<OrderComment>>? commentsStream;
  final OrderCommentSender? onSend;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context) ? const GlassBackButton() : null,
        middle: Text(
          context.l10n.comments,
          style: AppTypography.bodyStrong.copyWith(
            color: AppColors.text.resolveFrom(context),
          ),
        ),
        backgroundColor: AppNavBar.barBackground(context),
        border: null,
      ),
      child: SafeArea(
        bottom: false,
        child: OrderCommentsWidget(
          orderId: orderId,
          companyId: companyId,
          showInternalToggle: true,
          highlightCommentId: highlightCommentId,
          commentsStream: commentsStream,
          onSend: onSend,
        ),
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/screens/widgets/order_comments_widget.dart';
import 'package:praticos/theme/app_colors.dart';

/// All comments of an order, with the box to write a new one (internal or
/// for the customer). Opened from "Ver todos" and "Comentário" of the order
/// screen, which only shows the last two.
class OrderCommentsScreen extends StatelessWidget {
  const OrderCommentsScreen({
    super.key,
    required this.orderId,
    required this.companyId,
    this.highlightCommentId,
  });

  final String orderId;
  final String companyId;
  final String? highlightCommentId;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.groupedBackground.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(context.l10n.comments),
        previousPageTitle: null,
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            OrderCommentsWidget(
              orderId: orderId,
              companyId: companyId,
              showInternalToggle: true,
              highlightCommentId: highlightCommentId,
            ),
          ],
        ),
      ),
    );
  }
}

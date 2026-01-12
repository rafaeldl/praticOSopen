import 'package:praticos/widgets/cached_image.dart';
import 'package:flutter/material.dart';
import 'package:praticos/services/format_service.dart';

class OrderItemRow extends StatelessWidget {
  final String? title;
  final String? description;
  final int? quantity;
  final double? value;
  final String? photoUrl;
  final IconData? fallbackIcon;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool showPrices; // Controla se exibe valores financeiros

  const OrderItemRow({
    super.key,
    this.title = '',
    this.description = '',
    this.quantity,
    this.value = 0.0,
    this.photoUrl,
    this.fallbackIcon,
    this.onTap,
    this.onDelete,
    this.showPrices = true, // Por padrão mostra (compatibilidade)
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dismissible(
      key: UniqueKey(),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete_outline,
          color: colorScheme.onErrorContainer,
          size: 24,
        ),
      ),
      onDismissed: (_) => onDelete?.call(),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Sempre mostra avatar com imagem ou fallback icon
                _buildAvatar(theme),
                const SizedBox(width: 12),
                // Item info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title ?? '',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (description != null && description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Value section - apenas se showPrices
                if (showPrices)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (quantity != null) ...[
                        Text(
                          '$quantity x ${_convertToCurrency(value)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        _convertToCurrency(_calculateTotal()),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;

    // Fallback widget com ícone - usa onPrimaryContainer para garantir contraste
    Widget fallbackWidget = CircleAvatar(
      radius: 20,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: Icon(
        fallbackIcon ?? Icons.image_outlined,
        color: theme.colorScheme.onPrimaryContainer,
        size: 20,
      ),
    );

    if (!hasPhoto) {
      return fallbackWidget;
    }

    // Com foto: mostra CachedImage com fallback em caso de erro
    return ClipOval(
      child: CachedImage(
        imageUrl: photoUrl!,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorWidget: fallbackWidget,
      ),
    );
  }

  double _calculateTotal() {
    if (quantity != null && value != null) {
      return quantity! * value!;
    }
    return value ?? 0.0;
  }

  String _convertToCurrency(double? total) {
    if (total == null) return '';
    return FormatService().formatCurrency(total, decimalDigits: 2);
  }
}

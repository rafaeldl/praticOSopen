import 'package:flutter/cupertino.dart';
import 'package:praticos/models/membership.dart';

/// Widget de autocomplete para menções (@).
/// Exibe lista filtrada de colaboradores quando o usuário digita @.
class MentionAutocomplete extends StatelessWidget {
  final List<Membership> collaborators;
  final String query;
  final void Function(Membership) onSelect;
  final VoidCallback onDismiss;

  const MentionAutocomplete({
    super.key,
    required this.collaborators,
    required this.query,
    required this.onSelect,
    required this.onDismiss,
  });

  List<Membership> get _filteredCollaborators {
    if (query.isEmpty) return collaborators;
    final lowerQuery = query.toLowerCase();
    return collaborators.where((m) {
      final name = m.user?.name?.toLowerCase() ?? '';
      return name.contains(lowerQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCollaborators;
    if (filtered.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: filtered.length,
          separatorBuilder: (_, __) => Container(
            height: 0.5,
            color: CupertinoColors.separator.resolveFrom(context),
          ),
          itemBuilder: (context, index) {
            final membership = filtered[index];
            final user = membership.user;
            final name = user?.name ?? 'Sem nome';
            final initials = _getInitials(name);

            return CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => onSelect(membership),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: CupertinoColors.activeBlue.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: user?.photo != null
                          ? ClipOval(
                              child: Image.network(
                                user!.photo!,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Text(
                                    initials,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: CupertinoColors.activeBlue,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                initials,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.activeBlue,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    // Name
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          color: CupertinoColors.label.resolveFrom(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts.last[0]}'.toUpperCase();
  }
}

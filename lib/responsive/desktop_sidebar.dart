import 'package:flutter/cupertino.dart';

/// A navigation destination for the desktop sidebar.
class SidebarDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const SidebarDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Desktop navigation sidebar with collapsible icon-only mode.
///
/// Displays a vertical list of navigation items with PraticOS branding.
/// Highlights the active item and supports toggling between expanded
/// (icon + label) and collapsed (icon-only) modes.
class DesktopSidebar extends StatefulWidget {
  final List<SidebarDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  const DesktopSidebar({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  @override
  State<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<DesktopSidebar> {
  bool _isCollapsed = false;

  static const double _expandedWidth = 220;
  static const double _collapsedWidth = 68;

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);
    final isDark = brightness == Brightness.dark;

    final bgColor = isDark
        ? const Color(0xFF1C1C1E)
        : const Color(0xFFF2F2F7);
    final borderColor = CupertinoColors.separator.resolveFrom(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: _isCollapsed ? _collapsedWidth : _expandedWidth,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          right: BorderSide(color: borderColor, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: widget.destinations.length,
                itemBuilder: (context, index) {
                  return _buildNavItem(context, index);
                },
              ),
            ),
            _buildCollapseToggle(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final labelColor = CupertinoColors.label.resolveFrom(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.square_grid_2x2_fill,
            color: CupertinoColors.activeBlue,
            size: 28,
          ),
          if (!_isCollapsed) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'PraticOS',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: labelColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index) {
    final destination = widget.destinations[index];
    final isSelected = index == widget.currentIndex;

    final selectedColor = CupertinoColors.activeBlue;
    final unselectedColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final selectedBg = CupertinoColors.activeBlue.withValues(alpha: 0.12);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: GestureDetector(
        onTap: () => widget.onDestinationSelected(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: _isCollapsed ? 12 : 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment:
                _isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(
                isSelected ? destination.activeIcon : destination.icon,
                color: isSelected ? selectedColor : unselectedColor,
                size: 22,
              ),
              if (!_isCollapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destination.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? selectedColor : unselectedColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapseToggle(BuildContext context) {
    final secondaryLabel = CupertinoColors.secondaryLabel.resolveFrom(context);

    return GestureDetector(
      onTap: () => setState(() => _isCollapsed = !_isCollapsed),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Icon(
          _isCollapsed
              ? CupertinoIcons.sidebar_right
              : CupertinoIcons.sidebar_left,
          color: secondaryLabel,
          size: 20,
        ),
      ),
    );
  }
}

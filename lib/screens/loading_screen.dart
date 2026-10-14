import 'package:flutter/cupertino.dart';
import 'package:praticos/extensions/context_extensions.dart';
import 'package:praticos/theme/app_colors.dart';
import 'package:praticos/theme/app_spacing.dart';

/// Shown while the app decides where to go (signed in? company?). App icon
/// and a spinner on the screen background; screen readers hear "Carregando".
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background.resolveFrom(context),
      child: Center(
        child: Semantics(
          label: context.l10n.loading,
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/images/icon.png',
                    width: 88,
                    height: 88,
                    cacheWidth: 264,
                    fit: BoxFit.cover,
                    // Keeps the layout stable when the image fails.
                    errorBuilder: (_, __, ___) =>
                        const SizedBox(width: 88, height: 88),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const CupertinoActivityIndicator(radius: 14),
            ],
          ),
        ),
      ),
    );
  }
}

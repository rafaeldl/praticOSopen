import 'package:flutter/cupertino.dart';

/// Gives every route the Cupertino body text style.
///
/// The app runs on `MaterialApp`, whose root text style is the red,
/// yellow-underlined error style. Material widgets hide it, but the
/// redesigned Cupertino screens have no `Material` ancestor, so loose
/// `Text` widgets showed that style.
class AppDefaultTextStyle extends StatelessWidget {
  const AppDefaultTextStyle({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: CupertinoTheme.of(context).textTheme.textStyle,
      child: child,
    );
  }
}

import 'package:flutter/cupertino.dart';

/// Small colored dot (8-10px) that carries the color of a status. The status
/// text always goes next to it, in a neutral color.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.size = 8});

  /// Dynamic or plain color; dynamic ones are resolved from the context.
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final resolved = CupertinoDynamicColor.resolve(color, context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: resolved, shape: BoxShape.circle),
    );
  }
}

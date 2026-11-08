import 'package:flutter/cupertino.dart';

import 'app_colors.dart';

/// Cupertino theme of the app (Campo theme): brand blue for system controls,
/// navy text (titles of the native navigation bar included) and the system
/// background of the theme instead of iOS's pure black in dark mode.
CupertinoThemeData appCupertinoTheme(Brightness brightness) {
  final base = CupertinoTextThemeData(primaryColor: AppColors.accent);
  TextStyle navy(TextStyle style) => style.copyWith(color: AppColors.text);
  return CupertinoThemeData(
    brightness: brightness,
    primaryColor: AppColors.accent,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: CupertinoTextThemeData(
      primaryColor: AppColors.accent,
      textStyle: navy(base.textStyle),
      navTitleTextStyle: navy(base.navTitleTextStyle),
      navLargeTitleTextStyle: navy(base.navLargeTitleTextStyle),
      pickerTextStyle: navy(base.pickerTextStyle),
      dateTimePickerTextStyle: navy(base.dateTimePickerTextStyle),
    ),
  );
}

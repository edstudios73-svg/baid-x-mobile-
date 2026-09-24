import 'package:flutter/widgets.dart';

abstract final class Responsive {
  static const compact = 600.0;

  static bool isCompact(BuildContext context) {
    return MediaQuery.sizeOf(context).width < compact;
  }

  static double pagePadding(BuildContext context) {
    return isCompact(context) ? 20 : 32;
  }
}

import 'package:flutter/material.dart';

class AccessibilityHelper {
  static Widget applySemanticLabel(Widget child, String label) {
    return Semantics(
      label: label,
      child: child,
    );
  }
  
  static double getScaledPadding(BuildContext context, double base) {
    return MediaQuery.textScalerOf(context).scale(base);
  }
}

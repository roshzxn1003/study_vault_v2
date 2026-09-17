import 'package:flutter/material.dart';
import 'package:study_vault/core/design/design_system.dart';

/// Minimal academic divider with centered label, backed by AppDivider.
class AuthDivider extends StatelessWidget {
  final String label;

  const AuthDivider({
    super.key,
    this.label = 'or',
  });

  @override
  Widget build(BuildContext context) {
    return AppDivider(
      label: label,
      verticalPadding: AppSpacing.lg,
    );
  }
}


import 'package:flutter/material.dart';
import '../tokens/tokens.dart';
import 'app_button.dart';

/// Clean academic dialog modal for confirmations and contextual actions.
class AppModal extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? content;
  final String? confirmText;
  final VoidCallback? onConfirm;
  final String cancelText;
  final VoidCallback? onCancel;
  final bool isDestructive;
  final bool isConfirmLoading;
  final IconData? icon;

  const AppModal({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.confirmText = 'Confirm',
    this.onConfirm,
    this.cancelText = 'Cancel',
    this.onCancel,
    this.isDestructive = false,
    this.isConfirmLoading = false,
    this.icon,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? message,
    Widget? content,
    String? confirmText,
    VoidCallback? onConfirm,
    String cancelText = 'Cancel',
    VoidCallback? onCancel,
    bool isDestructive = false,
    IconData? icon,
  }) {
    return showDialog<T>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => AppModal(
        title: title,
        message: message,
        content: content,
        confirmText: confirmText,
        onConfirm: onConfirm,
        cancelText: cancelText,
        onCancel: onCancel ?? () => Navigator.of(ctx).pop(),
        isDestructive: isDestructive,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.modal,
        side: AppBorders.standard,
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppDimensions.dialogMaxWidth),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDestructive
                        ? AppColors.destructiveSubtle
                        : AppColors.surfaceSecondary,
                    borderRadius: AppRadius.brMd,
                    border: Border.all(
                      color: isDestructive
                          ? AppColors.destructive.withValues(alpha: 0.3)
                          : AppColors.border,
                      width: AppBorders.subtleWidth,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: AppIcons.md,
                    color: isDestructive
                        ? AppColors.destructiveLight
                        : AppColors.primaryLight,
                  ),
                ),
                AppSpacing.v16,
              ],
              Text(
                title,
                style: AppTypography.title,
              ),
              if (message != null) ...[
                AppSpacing.v8,
                Text(
                  message!,
                  style: AppTypography.bodySmall,
                ),
              ],
              if (content != null) ...[
                AppSpacing.v16,
                content!,
              ],
              AppSpacing.v24,
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton.tertiary(
                    text: cancelText,
                    onPressed: onCancel ?? () => Navigator.of(context).pop(),
                    size: AppButtonSize.md,
                  ),
                  if (confirmText != null && onConfirm != null) ...[
                    AppSpacing.h12,
                    isDestructive
                        ? AppButton.destructive(
                            text: confirmText!,
                            onPressed: onConfirm,
                            size: AppButtonSize.md,
                            isLoading: isConfirmLoading,
                          )
                        : AppButton.primary(
                            text: confirmText!,
                            onPressed: onConfirm,
                            size: AppButtonSize.md,
                            isLoading: isConfirmLoading,
                          ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

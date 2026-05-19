import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

enum AppButtonVariant { primary, secondary, outlined, text, danger }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool isFullWidth;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final double? height;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.isFullWidth = true,
    this.leadingIcon,
    this.trailingIcon,
    this.height,
  });

  const AppButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
    this.leadingIcon,
    this.trailingIcon,
    this.height,
  }) : variant = AppButtonVariant.outlined;

  const AppButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isFullWidth = false,
    this.leadingIcon,
    this.trailingIcon,
    this.height,
  }) : variant = AppButtonVariant.text;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
    this.leadingIcon,
    this.trailingIcon,
    this.height,
  }) : variant = AppButtonVariant.danger;

  @override
  Widget build(BuildContext context) {
    final child = _buildChild(context);

    return switch (variant) {
      AppButtonVariant.primary || AppButtonVariant.danger => ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: variant == AppButtonVariant.danger
              ? ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                  minimumSize: Size(
                    isFullWidth ? double.infinity : 0,
                    height ?? AppDimensions.buttonHeight,
                  ),
                )
              : ElevatedButton.styleFrom(
                  minimumSize: Size(
                    isFullWidth ? double.infinity : 0,
                    height ?? AppDimensions.buttonHeight,
                  ),
                ),
          child: child,
        ),
      AppButtonVariant.outlined => OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: Size(
              isFullWidth ? double.infinity : 0,
              height ?? AppDimensions.buttonHeight,
            ),
          ),
          child: child,
        ),
      AppButtonVariant.secondary => FilledButton.tonal(
          onPressed: isLoading ? null : onPressed,
          style: FilledButton.styleFrom(
            minimumSize: Size(
              isFullWidth ? double.infinity : 0,
              height ?? AppDimensions.buttonHeight,
            ),
          ),
          child: child,
        ),
      AppButtonVariant.text => TextButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        ),
    };
  }

  Widget _buildChild(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (leadingIcon == null && trailingIcon == null) {
      return Text(label);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leadingIcon != null) ...[
          Icon(leadingIcon, size: AppDimensions.iconSm),
          const SizedBox(width: AppDimensions.sm),
        ],
        Text(label),
        if (trailingIcon != null) ...[
          const SizedBox(width: AppDimensions.sm),
          Icon(trailingIcon, size: AppDimensions.iconSm),
        ],
      ],
    );
  }
}

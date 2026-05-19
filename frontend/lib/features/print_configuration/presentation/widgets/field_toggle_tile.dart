import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/models/print_field.dart';
import '../providers/print_config_provider.dart';

class FieldToggleTile extends ConsumerStatefulWidget {
  final PrintField field;

  const FieldToggleTile({super.key, required this.field});

  @override
  ConsumerState<FieldToggleTile> createState() => _FieldToggleTileState();
}

class _FieldToggleTileState extends ConsumerState<FieldToggleTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(
      printConfigProvider.select((s) => s.isFieldEnabled(widget.field.id)),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () =>
            ref.read(printConfigProvider.notifier).toggleField(widget.field.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.sm,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: enabled
                ? AppColors.primarySurface
                : _hovered
                    ? AppColors.surfaceVariant
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(
              color: enabled
                  ? AppColors.primary.withOpacity(0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: enabled ? AppColors.primary : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(
                    color: enabled
                        ? AppColors.primary
                        : AppColors.border,
                    width: 1.5,
                  ),
                ),
                child: enabled
                    ? const Icon(Icons.check_rounded,
                        size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: AppDimensions.sm),
              Icon(
                widget.field.icon,
                size: 14,
                color: enabled
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.field.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        enabled ? FontWeight.w600 : FontWeight.w400,
                    color: enabled
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

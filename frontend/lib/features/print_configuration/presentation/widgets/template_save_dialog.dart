import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/print_config_provider.dart';

class TemplateSaveDialog extends ConsumerStatefulWidget {
  const TemplateSaveDialog({super.key});

  @override
  ConsumerState<TemplateSaveDialog> createState() =>
      _TemplateSaveDialogState();
}

class _TemplateSaveDialogState
    extends ConsumerState<TemplateSaveDialog> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      ),
      backgroundColor: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    child: const Icon(Icons.bookmark_add_outlined,
                        size: 16, color: AppColors.primary),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  const Text(
                    'Save Template',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: AppColors.textSecondary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Save the current field selection as a reusable template.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              AppTextField(
                label: 'Template Name',
                hint: 'e.g. Paediatric Summary',
                controller: _ctrl,
                prefixIcon:
                    const Icon(Icons.label_outline_rounded),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter a template name'
                    : null,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: AppDimensions.md),
              Row(
                children: [
                  Expanded(
                    child: AppButton.outlined(
                      label: 'Cancel',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: AppButton(
                      label: 'Save Template',
                      leadingIcon: Icons.save_rounded,
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        ref
                            .read(printConfigProvider.notifier)
                            .saveTemplate(_ctrl.text.trim());
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '"${_ctrl.text.trim()}" saved successfully.'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusMd),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

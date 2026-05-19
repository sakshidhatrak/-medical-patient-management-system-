import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/entities/patient_entity.dart';

void showAddSymptomSheet(BuildContext context,
    {required PatientEntity patient}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddSymptomSheet(patient: patient),
  );
}

class AddSymptomSheet extends StatefulWidget {
  final PatientEntity patient;

  const AddSymptomSheet({super.key, required this.patient});

  @override
  State<AddSymptomSheet> createState() => _AddSymptomSheetState();
}

class _AddSymptomSheetState extends State<AddSymptomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _heartRateCtrl = TextEditingController();
  final _systolicCtrl = TextEditingController();
  final _diastolicCtrl = TextEditingController();
  String _heartRateType = 'Normal';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _heartRateCtrl.dispose();
    _systolicCtrl.dispose();
    _diastolicCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    // Simulate API save
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() => _isSubmitting = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Symptom recorded successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.only(bottom: bottomInset + 12),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.sidebarText.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppDimensions.md, 8, AppDimensions.md, AppDimensions.md),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Symptom',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.patient.fullName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.sidebarText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.sidebarItemHover,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const _DarkDivider(),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Column(
                children: [
                  // Heart Rate
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _DarkField(
                          label: 'Heart Rate',
                          hint: '72',
                          suffix: 'bpm',
                          controller: _heartRateCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Expanded(
                        flex: 3,
                        child: _DarkDropdown(
                          label: 'Heart Rate Type',
                          value: _heartRateType,
                          items: const [
                            'Normal',
                            'Bradycardia',
                            'Tachycardia',
                            'Arrhythmia',
                          ],
                          onChanged: (v) =>
                              setState(() => _heartRateType = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.md),
                  // Blood Pressure
                  Row(
                    children: [
                      Expanded(
                        child: _DarkField(
                          label: 'Systolic BP',
                          hint: '120',
                          suffix: 'mmHg',
                          controller: _systolicCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Expanded(
                        child: _DarkField(
                          label: 'Diastolic BP',
                          hint: '80',
                          suffix: 'mmHg',
                          controller: _diastolicCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.lg),
                  SizedBox(
                    width: double.infinity,
                    height: AppDimensions.buttonHeight,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.primary.withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppDimensions.radiusLg),
                        ),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Add Record',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkField extends StatelessWidget {
  final String label;
  final String hint;
  final String? suffix;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;

  const _DarkField({
    required this.label,
    required this.hint,
    this.suffix,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.sidebarText,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.sidebarText,
              fontSize: 14,
            ),
            suffixText: suffix,
            suffixStyle: const TextStyle(
              color: AppColors.sidebarText,
              fontSize: 12,
            ),
            filled: true,
            fillColor: AppColors.sidebarItemHover,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMd),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMd),
              borderSide: const BorderSide(
                  color: AppColors.sidebarText, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMd),
              borderSide: const BorderSide(
                  color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMd),
              borderSide:
                  const BorderSide(color: AppColors.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMd),
              borderSide:
                  const BorderSide(color: AppColors.error, width: 1.5),
            ),
            errorStyle:
                const TextStyle(color: AppColors.error, fontSize: 10),
          ),
        ),
      ],
    );
  }
}

class _DarkDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DarkDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.sidebarText,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          dropdownColor: AppColors.darkCard,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.sidebarText),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.sidebarItemHover,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMd),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMd),
              borderSide: const BorderSide(
                  color: AppColors.sidebarText, width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMd),
              borderSide: const BorderSide(
                  color: AppColors.primary, width: 1.5),
            ),
          ),
          items: items
              .map((i) => DropdownMenuItem(
                    value: i,
                    child: Text(i),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _DarkDivider extends StatelessWidget {
  const _DarkDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: AppColors.sidebarItemHover,
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/printable_field_wrapper.dart';
import 'form_section_card.dart';

class VitalsFormSection extends StatelessWidget {
  final TextEditingController weightCtrl;
  final TextEditingController bloodPressureCtrl;
  final TextEditingController temperatureCtrl;

  // ── Print selection (optional) ─────────────────────────────────────────────
  final Set<String> printSelected;
  final ValueChanged<String>? onPrintToggle;

  const VitalsFormSection({
    super.key,
    required this.weightCtrl,
    required this.bloodPressureCtrl,
    required this.temperatureCtrl,
    this.printSelected = const {},
    this.onPrintToggle,
  });

  bool _sel(String id) => printSelected.contains(id);
  void _tog(String id) => onPrintToggle?.call(id);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 640;

    final weight = _wrap(
      'weight',
      _VitalField(
        label: 'Weight',
        unit: 'kg',
        controller: weightCtrl,
        icon: Icons.monitor_weight_outlined,
        hint: '70',
        iconColor: AppColors.success,
        validator: _positiveDecimal,
      ),
    );

    final bp = _wrap(
      'bloodPressure',
      AppTextField(
        label: 'Blood Pressure',
        hint: '120/80',
        controller: bloodPressureCtrl,
        prefixIcon: const Icon(Icons.bloodtype_outlined),
        keyboardType: TextInputType.text,
        validator: _bpValidator,
      ),
    );

    final temp = _wrap(
      'temperature',
      _VitalField(
        label: 'Temperature',
        unit: '°C',
        controller: temperatureCtrl,
        icon: Icons.thermostat_outlined,
        hint: '37.0',
        iconColor: AppColors.bloodTypeB,
        validator: _tempValidator,
      ),
    );

    return FormSectionCard(
      title: 'Patient Vitals',
      icon: Icons.monitor_heart_outlined,
      iconColor: AppColors.error,
      children: [
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: weight),
              const SizedBox(width: AppDimensions.sm),
              Expanded(child: bp),
              const SizedBox(width: AppDimensions.sm),
              Expanded(child: temp),
            ],
          )
        else ...[
          weight,
          const SizedBox(height: AppDimensions.md),
          bp,
          const SizedBox(height: AppDimensions.md),
          temp,
        ],
      ],
    );
  }

  Widget _wrap(String id, Widget child) {
    if (onPrintToggle == null) return child;
    return PrintableFieldWrapper(
      fieldId: id,
      isSelected: _sel(id),
      onToggle: () => _tog(id),
      child: child,
    );
  }

  static String? _positiveDecimal(String? v) {
    if (v == null || v.isEmpty) return null;
    final n = double.tryParse(v);
    if (n == null || n <= 0) return 'Invalid value';
    return null;
  }

  static String? _bpValidator(String? v) {
    if (v == null || v.isEmpty) return null;
    final parts = v.split('/');
    if (parts.length != 2) return 'Use 120/80 format';
    if (int.tryParse(parts[0]) == null || int.tryParse(parts[1]) == null) {
      return 'Invalid';
    }
    return null;
  }

  static String? _tempValidator(String? v) {
    if (v == null || v.isEmpty) return null;
    final n = double.tryParse(v);
    if (n == null || n < 30 || n > 45) return '30–45 °C';
    return null;
  }
}

class _VitalField extends StatelessWidget {
  final String label;
  final String unit;
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final Color iconColor;
  final FormFieldValidator<String>? validator;

  const _VitalField({
    required this.label,
    required this.unit,
    required this.controller,
    required this.icon,
    required this.hint,
    required this.iconColor,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: label,
      hint: hint,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      prefixIcon: Icon(icon, color: iconColor),
      suffixIcon: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          unit,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      validator: validator,
    );
  }
}

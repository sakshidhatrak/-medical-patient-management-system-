import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/printable_field_wrapper.dart';
import '../../domain/entities/treatment_entity.dart';
import 'form_section_card.dart';

class TreatmentFormSection extends StatelessWidget {
  final TextEditingController chiefComplaintCtrl;
  final TextEditingController diagnosisCtrl;
  final TextEditingController treatmentPlanCtrl;
  final TextEditingController medicationsCtrl;
  final TextEditingController existingConditionsCtrl;
  final TextEditingController notesCtrl;
  final VisitType visitType;
  final ValueChanged<VisitType> onVisitTypeChanged;

  // ── Print selection (optional) ─────────────────────────────────────────────
  final Set<String> printSelected;
  final ValueChanged<String>? onPrintToggle;

  const TreatmentFormSection({
    super.key,
    required this.chiefComplaintCtrl,
    required this.diagnosisCtrl,
    required this.treatmentPlanCtrl,
    required this.medicationsCtrl,
    required this.existingConditionsCtrl,
    required this.notesCtrl,
    required this.visitType,
    required this.onVisitTypeChanged,
    this.printSelected = const {},
    this.onPrintToggle,
  });

  bool _sel(String id) => printSelected.contains(id);
  void _tog(String id) => onPrintToggle?.call(id);

  Widget _wrap(String id, Widget child) {
    if (onPrintToggle == null) return child;
    return PrintableFieldWrapper(
      fieldId: id,
      isSelected: _sel(id),
      onToggle: () => _tog(id),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FormSectionCard(
      title: 'Treatment Information',
      icon: Icons.medical_services_outlined,
      iconColor: AppColors.info,
      children: [
        _wrap(
          'chiefComplaint',
          AppTextField(
            label: 'Chief Complaint',
            hint: 'Primary reason for the visit…',
            controller: chiefComplaintCtrl,
            prefixIcon: const Icon(Icons.assignment_outlined),
            maxLines: 3,
            textInputAction: TextInputAction.newline,
          ),
        ),
        _wrap(
          'diagnosis',
          AppTextField(
            label: 'Diagnosis',
            hint: 'Clinical diagnosis…',
            controller: diagnosisCtrl,
            prefixIcon: const Icon(Icons.local_hospital_outlined),
          ),
        ),
        _wrap(
          'treatmentPlan',
          AppTextField(
            label: 'Treatment Plan',
            hint: 'Describe the treatment plan…',
            controller: treatmentPlanCtrl,
            prefixIcon: const Icon(Icons.playlist_add_check_rounded),
            maxLines: 3,
            textInputAction: TextInputAction.newline,
          ),
        ),
        _wrap(
          'medications',
          AppTextField(
            label: 'Medications Prescribed',
            hint: 'Separate with commas — e.g. Paracetamol 500mg, Amoxicillin',
            controller: medicationsCtrl,
            prefixIcon: const Icon(Icons.medication_outlined),
          ),
        ),
        _wrap(
          'existingConditions',
          AppTextField(
            label: 'Existing Conditions',
            hint: 'Separate with commas — e.g. Diabetes, Hypertension',
            controller: existingConditionsCtrl,
            prefixIcon: const Icon(Icons.history_edu_outlined),
          ),
        ),

        // Visit type chips
        const FieldGroupLabel('Visit Type'),
        Wrap(
          spacing: 8,
          children: VisitType.values.map((t) {
            final selected = visitType == t;
            return ChoiceChip(
              label: Text(t.label),
              selected: selected,
              onSelected: (_) => onVisitTypeChanged(t),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: selected ? AppColors.onPrimary : AppColors.textSecondary,
              ),
              backgroundColor: AppColors.surfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: selected ? AppColors.primary : AppColors.border,
                ),
              ),
            );
          }).toList(),
        ),

        _wrap(
          'notes',
          AppTextField(
            label: 'Notes',
            hint: 'Additional clinical notes…',
            controller: notesCtrl,
            prefixIcon: const Icon(Icons.notes_rounded),
            maxLines: 3,
            textInputAction: TextInputAction.newline,
          ),
        ),
      ],
    );
  }
}

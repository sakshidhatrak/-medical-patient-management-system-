import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_text_field.dart';
import 'form_section_card.dart';

const _kRelationships = [
  'Spouse',
  'Parent',
  'Child',
  'Sibling',
  'Friend',
  'Guardian',
  'Other',
];

class EmergencyFormSection extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController insuranceProviderCtrl;
  final TextEditingController insuranceNumberCtrl;
  final String? relationship;
  final ValueChanged<String?> onRelationshipChanged;

  const EmergencyFormSection({
    super.key,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.insuranceProviderCtrl,
    required this.insuranceNumberCtrl,
    required this.relationship,
    required this.onRelationshipChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FormSectionCard(
      title: 'Emergency & Insurance',
      icon: Icons.emergency_outlined,
      iconColor: AppColors.error,
      children: [
        const FieldGroupLabel('Emergency Contact'),
        AppTextField(
          label: 'Contact Name',
          hint: 'Full name',
          controller: nameCtrl,
          prefixIcon: const Icon(Icons.person_outline),
        ),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: AppTextField(
                label: 'Contact Number',
                hint: '+1 555-0000',
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: relationship,
                onChanged: onRelationshipChanged,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Relationship',
                  prefixIcon: Icon(Icons.people_outline),
                ),
                items: _kRelationships
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.xs),
        const FieldGroupLabel('Insurance'),
        AppTextField(
          label: 'Insurance Provider',
          hint: 'e.g. Blue Cross Blue Shield',
          controller: insuranceProviderCtrl,
          prefixIcon: const Icon(Icons.health_and_safety_outlined),
        ),
        AppTextField(
          label: 'Insurance / Policy Number',
          hint: 'Policy number',
          controller: insuranceNumberCtrl,
          prefixIcon: const Icon(Icons.badge_outlined),
        ),
      ],
    );
  }
}

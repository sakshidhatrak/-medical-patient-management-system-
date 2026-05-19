import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../domain/entities/patient_entity.dart';

class PatientCard extends StatelessWidget {
  final PatientEntity patient;
  final bool isPending;
  final VoidCallback? onTap;

  const PatientCard({
    super.key,
    required this.patient,
    this.isPending = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _Avatar(patient: patient),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _InfoPill(
                        label: '${patient.age}y',
                        icon: Icons.cake_outlined,
                      ),
                      const SizedBox(width: 6),
                      _InfoPill(
                        label: _genderLabel(patient.gender),
                        icon: Icons.person_outline,
                      ),
                      if (patient.bloodType != null) ...[
                        const SizedBox(width: 6),
                        _BloodTypeChip(type: patient.bloodType!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        patient.phone,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (patient.allergies.isNotEmpty)
                  Tooltip(
                    message: 'Allergies: ${patient.allergies.join(', ')}',
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.errorSurface,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      child: const Icon(Icons.warning_amber_rounded,
                          size: 14, color: AppColors.error),
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: const Icon(Icons.visibility_outlined,
                      size: 16, color: AppColors.primary),
                ),
                const SizedBox(height: 6),
                Tooltip(
                  message: isPending ? 'Pending sync' : 'Synced',
                  child: Icon(
                    isPending
                        ? Icons.pending_outlined
                        : Icons.cloud_done_outlined,
                    size: 14,
                    color: isPending
                        ? Colors.orange
                        : AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _genderLabel(Gender g) => switch (g) {
        Gender.male => 'Male',
        Gender.female => 'Female',
        Gender.other => 'Other',
        Gender.preferNotToSay => '—',
      };
}

class _Avatar extends StatelessWidget {
  final PatientEntity patient;

  const _Avatar({required this.patient});

  static const _palette = [
    AppColors.primary,
    AppColors.info,
    AppColors.success,
    Color(0xFF9C27B0),
    Color(0xFF009688),
    Color(0xFFF44336),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _palette[patient.id.hashCode.abs() % _palette.length];
    return CircleAvatar(
      radius: 26,
      backgroundColor: color.withOpacity(0.12),
      child: Text(
        patient.initials,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final IconData icon;

  const _InfoPill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: AppColors.textSecondary),
        const SizedBox(width: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _BloodTypeChip extends StatelessWidget {
  final String type;

  const _BloodTypeChip({required this.type});

  Color _color() {
    if (type.startsWith('A')) return AppColors.bloodTypeA;
    if (type.startsWith('B')) return AppColors.bloodTypeB;
    if (type.startsWith('O')) return AppColors.bloodTypeO;
    return AppColors.bloodTypeAB;
  }

  @override
  Widget build(BuildContext context) {
    final c = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 11,
          color: c,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

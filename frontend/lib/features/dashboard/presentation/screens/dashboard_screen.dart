import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_nav_drawer.dart';
import '../../../patients/domain/entities/patient_entity.dart';
import '../../../patients/presentation/providers/patient_provider.dart';
import '../widgets/stat_card_widget.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsState = ref.watch(patientsProvider);
    final today = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: AppNavDrawer(
        currentRoute: RouteNames.dashboard,
        onSelect: (route) => context.go(route),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            _DashboardAppBar(today: today),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.md),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Stats row
                  _StatsSection(),
                  const SizedBox(height: AppDimensions.lg),
                  // Section header + New Patient button
                  _SectionHeader(
                    title: 'Recent Patients',
                    onNewPatient: () => context.go(RouteNames.patientCreate),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  // Search bar
                  _SearchBar(
                    onTap: () => context.go(RouteNames.patients),
                  ),
                  const SizedBox(height: AppDimensions.md),
                ]),
              ),
            ),
            // Patient list
            if (patientsState.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.md),
                sliver: SliverList.separated(
                  itemCount:
                      patientsState.patients.take(8).length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppDimensions.sm),
                  itemBuilder: (context, i) {
                    final patient =
                        patientsState.patients[i];
                    return _DashboardPatientTile(
                      patient: patient,
                      onTap: () => context.go(
                          '${RouteNames.patients}/${patient.id}'),
                    );
                  },
                ),
              ),
            const SliverPadding(
                padding: EdgeInsets.only(bottom: AppDimensions.xl)),
          ],
        ),
      ),
    );
  }
}

class _DashboardAppBar extends StatelessWidget {
  final String today;

  const _DashboardAppBar({required this.today});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: AppColors.background,
      floating: true,
      pinned: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: AppDimensions.md,
      title: Row(
        children: [
          Builder(
            builder: (context) => GestureDetector(
              onTap: () => Scaffold.of(context).openDrawer(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.menu_rounded,
                    color: AppColors.textPrimary, size: 20),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Good Morning, Doctor 👋',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  today,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // Notification bell
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.notifications_none_rounded,
                    color: AppColors.textPrimary, size: 20),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatCardWidget(
                value: '26',
                label: 'Upcoming Appointments',
                icon: Icons.calendar_today_rounded,
                accentColor: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: StatCardWidget(
                value: '38',
                label: 'Pending Reviews',
                icon: Icons.pending_actions_rounded,
                accentColor: AppColors.warning,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.sm),
        Row(
          children: [
            Expanded(
              child: StatCardWidget(
                value: '02',
                label: 'Completed Today',
                icon: Icons.check_circle_outline_rounded,
                accentColor: AppColors.success,
              ),
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: StatCardWidget(
                value: '142',
                label: 'Total Patients',
                icon: Icons.people_alt_rounded,
                accentColor: AppColors.info,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onNewPatient;

  const _SectionHeader(
      {required this.title, required this.onNewPatient});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        FilledButton.icon(
          onPressed: onNewPatient,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMd),
            ),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('New Patient'),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded,
                color: AppColors.textSecondary, size: 20),
            const SizedBox(width: AppDimensions.sm),
            const Expanded(
              child: Text(
                'Search patients, records...',
                style: TextStyle(
                  color: AppColors.textDisabled,
                  fontSize: 14,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.sm, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: const Text(
                '⌘ K',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardPatientTile extends StatelessWidget {
  final PatientEntity patient;
  final VoidCallback onTap;

  const _DashboardPatientTile(
      {required this.patient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              BorderRadius.circular(AppDimensions.radiusXl),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _PatientAvatar(patient: patient),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _InfoTag(
                          label:
                              '${patient.age}y • ${_genderShort(patient.gender)}'),
                      if (patient.bloodType != null) ...[
                        const SizedBox(width: 6),
                        _BloodTypeTag(type: patient.bloodType!),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(patient.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.successSurface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _genderShort(Gender g) => switch (g) {
        Gender.male => 'Male',
        Gender.female => 'Female',
        _ => 'Other',
      };

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(dt);
  }
}

class _PatientAvatar extends StatelessWidget {
  final PatientEntity patient;

  const _PatientAvatar({required this.patient});

  static const _palette = [
    AppColors.primary,
    AppColors.info,
    AppColors.success,
    Color(0xFF9C27B0),
    Color(0xFF009688),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _palette[patient.id.hashCode.abs() % _palette.length];
    return CircleAvatar(
      radius: 22,
      backgroundColor: color.withOpacity(0.15),
      child: Text(
        patient.initials,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  final String label;

  const _InfoTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _BloodTypeTag extends StatelessWidget {
  final String type;

  const _BloodTypeTag({required this.type});

  Color _color() {
    if (type.startsWith('A')) return AppColors.bloodTypeA;
    if (type.startsWith('B')) return AppColors.bloodTypeB;
    if (type.startsWith('O')) return AppColors.bloodTypeO;
    return AppColors.bloodTypeAB;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color().withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type,
        style: TextStyle(
          fontSize: 11,
          color: _color(),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

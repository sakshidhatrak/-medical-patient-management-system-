import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../domain/entities/patient_entity.dart';
import '../providers/patient_provider.dart';

class PatientTimelineScreen extends ConsumerWidget {
  final String patientId;

  const PatientTimelineScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(patientDetailProvider(patientId));
    return async.when(
      loading: () => const Scaffold(
          backgroundColor: AppColors.background, body: AppLoader()),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Timeline')),
        body: Center(child: Text(e.toString())),
      ),
      data: (p) => _TimelineView(patient: p),
    );
  }
}

// Dummy timeline data for UI demonstration
class _TimelineEvent {
  final DateTime date;
  final String type;
  final String title;
  final String doctor;
  final String description;
  final Color color;
  final IconData icon;

  const _TimelineEvent({
    required this.date,
    required this.type,
    required this.title,
    required this.doctor,
    required this.description,
    required this.color,
    required this.icon,
  });
}

List<_TimelineEvent> _mockEvents(PatientEntity p) => [
      _TimelineEvent(
        date: DateTime.now().subtract(const Duration(days: 2)),
        type: 'Appointment',
        title: 'Routine Checkup',
        doctor: 'Dr. Sarah Chen',
        description: 'Blood pressure checked. Patient reports mild headaches.',
        color: AppColors.primary,
        icon: Icons.calendar_today_rounded,
      ),
      _TimelineEvent(
        date: DateTime.now().subtract(const Duration(days: 7)),
        type: 'Lab Result',
        title: 'Complete Blood Count',
        doctor: 'Lab — Dr. James Moore',
        description: 'WBC: 7.2 K/µL, RBC: 4.8 M/µL, Hgb: 14.1 g/dL. Within normal range.',
        color: AppColors.info,
        icon: Icons.science_outlined,
      ),
      _TimelineEvent(
        date: DateTime.now().subtract(const Duration(days: 14)),
        type: 'Prescription',
        title: 'Medication Updated',
        doctor: 'Dr. Sarah Chen',
        description: 'Lisinopril 10mg daily prescribed for blood pressure management.',
        color: AppColors.success,
        icon: Icons.medication_outlined,
      ),
      _TimelineEvent(
        date: DateTime.now().subtract(const Duration(days: 30)),
        type: 'Symptom',
        title: 'Elevated Blood Pressure',
        doctor: 'Dr. Alex Kim',
        description:
            'Patient reported HR: 88 bpm, BP: 145/92 mmHg. Advised lifestyle changes.',
        color: AppColors.warning,
        icon: Icons.monitor_heart_outlined,
      ),
      _TimelineEvent(
        date: DateTime.now().subtract(const Duration(days: 45)),
        type: 'Appointment',
        title: 'Cardiology Consultation',
        doctor: 'Dr. Sarah Chen',
        description: 'Echocardiogram ordered. Patient shows mild hypertension.',
        color: AppColors.primary,
        icon: Icons.calendar_today_rounded,
      ),
    ];

const _filters = ['All', 'Last Month', 'Week'];

class _TimelineView extends StatefulWidget {
  final PatientEntity patient;

  const _TimelineView({required this.patient});

  @override
  State<_TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<_TimelineView> {
  int _filterIndex = 0;

  List<_TimelineEvent> get _filteredEvents {
    final events = _mockEvents(widget.patient);
    final now = DateTime.now();
    return switch (_filterIndex) {
      1 => events.where((e) => now.difference(e.date).inDays <= 30).toList(),
      2 => events.where((e) => now.difference(e.date).inDays <= 7).toList(),
      _ => events,
    };
  }

  @override
  Widget build(BuildContext context) {
    final events = _filteredEvents;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.sidebarBg,
            pinned: true,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Patient Timeline',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  widget.patient.fullName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.sidebarText,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.tune_rounded, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: _FilterChips(
                selected: _filterIndex,
                onSelect: (i) => setState(() => _filterIndex = i),
              ),
            ),
          ),
          if (events.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'No events in this period',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.md),
              sliver: SliverList.builder(
                itemCount: events.length,
                itemBuilder: (context, i) => _TimelineItem(
                  event: events[i],
                  isLast: i == events.length - 1,
                ),
              ),
            ),
          const SliverPadding(
              padding: EdgeInsets.only(bottom: AppDimensions.xl)),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;

  const _FilterChips({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_filters.length, (i) {
        final isSelected = i == selected;
        return Padding(
          padding: EdgeInsets.only(right: i < _filters.length - 1 ? 8 : 0),
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.md, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusRound),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                _filters[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final _TimelineEvent event;
  final bool isLast;

  const _TimelineItem({required this.event, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + dot
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: event.color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(event.icon, color: event.color, size: 18),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.only(top: 4, bottom: 4),
                    color: AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppDimensions.md),
          // Content
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.only(bottom: AppDimensions.md),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusXl),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: event.color.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusSm),
                          ),
                          child: Text(
                            event.type,
                            style: TextStyle(
                              fontSize: 11,
                              color: event.color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          DateFormat('MMM d, yyyy').format(event.date),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          event.doctor,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

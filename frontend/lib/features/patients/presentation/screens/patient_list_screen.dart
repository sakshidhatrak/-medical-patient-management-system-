import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:medical_patient_management/core/theme/app_colors.dart';
import 'package:medical_patient_management/core/theme/theme_provider.dart';
import 'package:medical_patient_management/core/widgets/sync_status_badge.dart';
import 'package:medical_patient_management/features/auth/domain/entities/user_entity.dart';
import 'package:medical_patient_management/features/auth/presentation/providers/auth_provider.dart';
import 'package:medical_patient_management/features/patients/domain/entities/patient_entity.dart';
import 'package:medical_patient_management/features/patients/presentation/providers/patient_provider.dart';
import 'package:medical_patient_management/features/print_configuration/presentation/providers/print_config_provider.dart';
import 'package:medical_patient_management/features/visits/presentation/providers/visit_provider.dart';

// ── palette ──────────────────────────────────────────────────────────────────
const _kHeaderLight = Color(0xFF3D3D8F);
const _kHeaderDark  = Color(0xFF6262B0);
const _kBodyLight   = Color(0xFFF0EEF8);
const _kBodyDark    = Color(0xFF171629);
const _kCardLight   = Colors.white;
const _kCardDark    = Color(0xFF252545);
const _kSearchLight = Colors.white;
const _kSearchDark  = Color(0xFF1E1C35);
const _kFabLight    = Color(0xFF2B2B6E);
const _kFabDark     = Color(0xFF5B5ECC);
const _kNavyText    = Color(0xFFEEECFF);
const _kSlate       = Color(0xFFCCCAE8);
const _kDocBtnLight = Color(0xFFE8E8F8);
const _kDocBtnDark  = Color(0xFF3A3865);

const _avatarPalette = [
  Color(0xFF5B5ECC),
  Color(0xFF8B6914),
  Color(0xFF9B4A38),
  Color(0xFF7B52AB),
  Color(0xFF2E7D32),
  Color(0xFF0277BD),
  Color(0xFFAD1457),
  Color(0xFF00695C),
  Color(0xFF6D4C41),
  Color(0xFF558B2F),
];

Color _avatarColor(String initials) {
  final code = initials.codeUnits.fold(0, (a, b) => a + b);
  return _avatarPalette[code % _avatarPalette.length];
}

enum _FilterTab { all, today, followUp }

// ── screen ───────────────────────────────────────────────────────────────────
class PatientListScreen extends ConsumerStatefulWidget {
  const PatientListScreen({super.key});

  @override
  ConsumerState<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends ConsumerState<PatientListScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  _FilterTab _activeFilter = _FilterTab.all;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(patientsProvider.notifier).loadMore();
    }
  }

  Future<void> _addVisit(String patientId) async {
    final visit = await ref
        .read(visitsProvider(patientId).notifier)
        .createVisit(patientId: patientId);
    if (visit != null && mounted) {
      // ignore: unawaited_futures
      context.push('/patients/$patientId/visits/${visit.id}');
    }
  }

  List<PatientEntity> _applyFilter(List<PatientEntity> all) {
    if (_activeFilter == _FilterTab.today) {
      final today = DateTime.now();
      return all.where((p) {
        final c = p.createdAt;
        return c.year == today.year &&
            c.month == today.month &&
            c.day == today.day;
      }).toList();
    }
    return all;
  }

  void _toggleTheme() {
    final current = ref.read(themeModeProvider);
    ref.read(themeModeProvider.notifier).state =
        current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(patientsProvider);
    final canWrite = ref.watch(canWriteProvider);
    final user     = ref.watch(currentUserProvider);
    final isDark   = ref.watch(themeModeProvider) == ThemeMode.dark;

    final headerBg  = isDark ? _kHeaderDark  : _kHeaderLight;
    final bodyBg    = isDark ? _kBodyDark    : _kBodyLight;
    final cardBg    = isDark ? _kCardDark    : _kCardLight;
    final searchBg  = isDark ? _kSearchDark  : _kSearchLight;
    final fabBg     = isDark ? _kFabDark     : _kFabLight;
    final docBtnBg  = isDark ? _kDocBtnDark  : _kDocBtnLight;

    final filtered = _applyFilter(state.patients);

    return Scaffold(
      backgroundColor: bodyBg,
      body: Column(
        children: [
          // ── header ──────────────────────────────────────────────────────
          _Header(
            user: user,
            isDark: isDark,
            headerBg: headerBg,
            searchBg: searchBg,
            patientCount: state.patients.length,
            activeFilter: _activeFilter,
            searchCtrl: _searchCtrl,
            onToggleTheme: _toggleTheme,
            onLogout: () async {
              await ref.read(authProvider.notifier).logout();
            },
            onSearch: (v) => ref.read(patientsProvider.notifier).search(v),
            onFilterChanged: (f) => setState(() => _activeFilter = f),
          ),
          // ── list ─────────────────────────────────────────────────────────
          Expanded(
            child: state.isLoading && state.patients.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? _EmptyState(
                        isDark: isDark,
                        hasSearch: state.search?.isNotEmpty == true ||
                            _activeFilter != _FilterTab.all,
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                        itemCount:
                            filtered.length + (state.hasMore ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i == filtered.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                  child: CircularProgressIndicator()),
                            );
                          }
                          final p = filtered[i];
                          return _PatientCard(
                            patient: p,
                            canWrite: canWrite,
                            isDark: isDark,
                            cardBg: cardBg,
                            docBtnBg: docBtnBg,
                            onTap: () => context.push('/patients/${p.id}'),
                            onAddVisit: () => _addVisit(p.id),
                            onPrint: () {
                              ref
                                  .read(activePatientDataProvider.notifier)
                                  .state = _patientDataMap(p);
                              context.go('/print-config');
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: canWrite
          ? _NewPatientFab(fabBg: fabBg,
              onTap: () => context.push('/patients/register'))
          : null,
    );
  }
}

// ── header widget ─────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final UserEntity? user;
  final bool isDark;
  final Color headerBg;
  final Color searchBg;
  final int patientCount;
  final _FilterTab activeFilter;
  final TextEditingController searchCtrl;
  final VoidCallback onToggleTheme;
  final VoidCallback onLogout;
  final ValueChanged<String> onSearch;
  final ValueChanged<_FilterTab> onFilterChanged;

  const _Header({
    required this.user,
    required this.isDark,
    required this.headerBg,
    required this.searchBg,
    required this.patientCount,
    required this.activeFilter,
    required this.searchCtrl,
    required this.onToggleTheme,
    required this.onLogout,
    required this.onSearch,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final initials = user != null
        ? '${user!.firstName[0]}${user!.lastName.isNotEmpty ? user!.lastName[0] : ''}'
            .toUpperCase()
        : 'U';
    final name = user?.fullName ?? 'User';
    final role = user?.roleDisplayName ?? '';

    return Container(
      decoration: BoxDecoration(
        color: headerBg,
        borderRadius: const BorderRadius.only(
          bottomLeft:  Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // top row: avatar + name + theme toggle + logout
              Row(
                children: [
                  _CircleBtn(
                    onTap: () => Navigator.maybePop(context),
                    child: const Icon(Icons.chevron_left,
                        color: _kNavyText, size: 20),
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: headerBg.withValues(alpha: 0.6),
                    child: Text(initials,
                        style: const TextStyle(
                            color: _kNavyText,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                color: _kNavyText,
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                        Text(role,
                            style: const TextStyle(
                                color: _kSlate, fontSize: 12)),
                      ],
                    ),
                  ),
                  _CircleBtn(
                    onTap: onToggleTheme,
                    child: Icon(
                      isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
                      color: _kNavyText,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CircleBtn(
                    onTap: onLogout,
                    child: const Icon(Icons.logout,
                        color: _kNavyText, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // patients title + count
              Row(
                children: [
                  const Text('Patients',
                      style: TextStyle(
                          color: _kNavyText,
                          fontSize: 26,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kNavyText.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('$patientCount',
                        style: const TextStyle(
                            color: _kNavyText,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // search bar
              TextField(
                controller: searchCtrl,
                style: TextStyle(
                    color: isDark ? _kNavyText : const Color(0xFF333355),
                    fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by name, ID or phone',
                  hintStyle: TextStyle(
                      color: isDark
                          ? _kSlate.withValues(alpha: 0.6)
                          : Colors.grey[500],
                      fontSize: 14),
                  prefixIcon: Icon(Icons.search,
                      size: 20,
                      color: isDark ? _kSlate : Colors.grey[500]),
                  suffixIcon: searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear,
                              size: 18,
                              color: isDark ? _kSlate : Colors.grey),
                          onPressed: () {
                            searchCtrl.clear();
                            onSearch('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: searchBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
                onChanged: onSearch,
              ),
              const SizedBox(height: 12),
              // filter pills
              Row(
                children: _FilterTab.values.map((tab) {
                  final selected = tab == activeFilter;
                  final label = switch (tab) {
                    _FilterTab.all      => 'All',
                    _FilterTab.today    => 'Today',
                    _FilterTab.followUp => 'Follow-up',
                  };
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => onFilterChanged(tab),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? _kNavyText
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? _kNavyText
                                : _kNavyText.withValues(alpha: 0.45),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: selected
                                ? headerBg
                                : _kNavyText,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── patient card ──────────────────────────────────────────────────────────────
class _PatientCard extends StatelessWidget {
  final PatientEntity patient;
  final bool canWrite;
  final bool isDark;
  final Color cardBg;
  final Color docBtnBg;
  final VoidCallback onTap;
  final VoidCallback onAddVisit;
  final VoidCallback onPrint;

  const _PatientCard({
    required this.patient,
    required this.canWrite,
    required this.isDark,
    required this.cardBg,
    required this.docBtnBg,
    required this.onTap,
    required this.onAddVisit,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final avatarColor = _avatarColor(patient.initials);
    final textPrimary = isDark ? _kNavyText : const Color(0xFF1A1A40);
    final textSub     = isDark ? _kSlate    : const Color(0xFF7070A0);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: avatarColor,
                  child: Text(
                    patient.initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              patient.fullName,
                              style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15),
                            ),
                          ),
                          SyncStatusBadge(syncStatus: patient.syncStatus),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (patient.ageSex.isNotEmpty) patient.ageSex,
                          patient.prn,
                        ].join(' · '),
                        style: TextStyle(color: textSub, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // doc / add-visit icon
                if (canWrite)
                  _DocBtn(
                    bg: docBtnBg,
                    isDark: isDark,
                    icon: Icons.note_add_outlined,
                    onTap: onAddVisit,
                  ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right,
                    color: isDark
                        ? _kSlate.withValues(alpha: 0.5)
                        : Colors.grey[400],
                    size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DocBtn extends StatelessWidget {
  final Color bg;
  final bool isDark;
  final IconData icon;
  final VoidCallback onTap;

  const _DocBtn({
    required this.bg,
    required this.isDark,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            size: 18,
            color: isDark
                ? _kSlate
                : AppColors.primary),
      ),
    );
  }
}

// ── circular icon button ───────────────────────────────────────────────────────
class _CircleBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _CircleBtn({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(child: child),
      ),
    );
  }
}

// ── FAB ───────────────────────────────────────────────────────────────────────
class _NewPatientFab extends StatelessWidget {
  final Color fabBg;
  final VoidCallback onTap;
  const _NewPatientFab({required this.fabBg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          color: fabBg,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: fabBg.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('New Patient',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

// ── empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  final bool isDark;
  const _EmptyState({required this.hasSearch, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = isDark ? _kSlate.withValues(alpha: 0.4) : Colors.grey[400]!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasSearch ? Icons.search_off : Icons.people_outline,
            size: 64,
            color: color,
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch ? 'No patients found' : 'No patients yet',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? _kSlate : Colors.grey[600]),
          ),
          if (!hasSearch) ...[
            const SizedBox(height: 8),
            Text('Tap + to register a new patient',
                style: TextStyle(
                    color: isDark
                        ? _kSlate.withValues(alpha: 0.5)
                        : Colors.grey[400])),
          ],
        ],
      ),
    );
  }
}

// ── helpers ───────────────────────────────────────────────────────────────────
Map<String, String> _patientDataMap(PatientEntity patient) {
  Map<String, String> notes = {};
  if (patient.notes != null && patient.notes!.isNotEmpty) {
    try {
      notes = (jsonDecode(patient.notes!) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {}
  }
  String n(String key) => notes[key]?.isNotEmpty == true ? notes[key]! : '—';
  final dob = patient.dateOfBirth != null
      ? DateFormat('dd MMMM yyyy').format(patient.dateOfBirth!)
      : '—';
  final gender = patient.sex != null && patient.sex!.isNotEmpty
      ? '${patient.sex![0].toUpperCase()}${patient.sex!.substring(1)}'
      : '—';
  return {
    'firstName':        patient.firstName,
    'lastName':         patient.lastName.isEmpty ? '—' : patient.lastName,
    'dob':              dob,
    'gender':           gender,
    'phone':            patient.phone ?? '—',
    'email':            n('email'),
    'address':          patient.address ?? '—',
    'bloodType':        n('bloodGroup'),
    'weight':           n('weight'),
    'bloodPressure':    n('bloodPressure'),
    'temperature':      n('temperature'),
    'chiefComplaint':   n('chiefComplaint'),
    'diagnosis':        n('diagnosis'),
    'treatmentPlan':    n('treatmentPlan'),
    'medications':      n('medications'),
    'notes':            n('treatmentNotes'),
    'doctorAssigned':   n('doctorAssigned'),
    'visitType':        n('visitType'),
    'prescription':     n('prescriptionFile'),
    'labReport':        n('labReportFile'),
    'xray':             n('xrayFile'),
    'mriCt':            n('mriFile'),
  };
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:medical_patient_management/features/auth/domain/entities/user_entity.dart';
import 'package:medical_patient_management/features/auth/presentation/providers/auth_provider.dart';
import 'package:medical_patient_management/features/patients/domain/entities/patient_entity.dart';
import 'package:medical_patient_management/features/patients/presentation/providers/patient_provider.dart';
import 'package:medical_patient_management/features/print_configuration/presentation/providers/print_config_provider.dart';
import 'package:medical_patient_management/features/visits/presentation/providers/visit_provider.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../../core/theme/theme_provider.dart';

// ── Brand palette ─────────────────────────────────────────────────────────────

const _kMaroon = Color(0xFF7B1F2E);
const _kBlue   = Color(0xFF3C5A9A);
const _kNavy   = Color(0xFF1A2D5A);
const _kSub    = Color(0xFF8090AA);

// Dark mode
const _kDarkBg     = Color(0xFF0D0D2B);
const _kDarkCard   = Color(0xFF1A1A3A);
const _kDarkHeader = Color(0xFF12123A);
const _kDarkField  = Color(0xFF1E1E40);

// Light mode
const _kLightBg = Color(0xFFF0F4FF);

const _avatarPalette = [
  Color(0xFF9B4A38),
  Color(0xFF8B6914),
  Color(0xFF455A64),
  Color(0xFF3C5A9A),
  Color(0xFF7B52AB),
  Color(0xFF2E7D32),
  Color(0xFFAD1457),
  Color(0xFF00695C),
  Color(0xFF6D4C41),
  Color(0xFF558B2F),
];

Color _avatarColor(String initials) {
  final code = initials.codeUnits.fold(0, (a, b) => a + b);
  return _avatarPalette[code % _avatarPalette.length];
}

String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24)   return '${diff.inHours}h ago';
  if (diff.inDays < 30)    return '${diff.inDays}d ago';
  return DateFormat('dd MMM').format(dt);
}

// ── Screen ────────────────────────────────────────────────────────────────────

class PatientListScreen extends ConsumerStatefulWidget {
  const PatientListScreen({super.key});

  @override
  ConsumerState<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends ConsumerState<PatientListScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(() => setState(() {}));
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

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(patientsProvider);
    final canWrite = ref.watch(canWriteProvider);
    final user     = ref.watch(currentUserProvider);
    final isDark   = Theme.of(context).brightness == Brightness.dark;

    final bg       = isDark ? _kDarkBg     : _kLightBg;
    final headerBg = isDark ? _kDarkHeader : Colors.white;
    final cardBg   = isDark ? _kDarkCard   : Colors.white;
    final textMain = isDark ? Colors.white  : _kNavy;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          _ClinicHeader(
            user: user,
            isDark: isDark,
            headerBg: headerBg,
            textMain: textMain,
            onLogout: () async {
              final pending = await ref.read(offlineQueueProvider).pending();
              if (pending.isNotEmpty && context.mounted) {
                final proceed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => _PendingSyncDialog(pendingCount: pending.length),
                );
                if (proceed != true) return;
              }
              ref.read(authProvider.notifier).logout();
            },
          ),
          // ── Patients title + count + search ────────────────────────────────
          Container(
            color: headerBg,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_alt_rounded,
                        color: _kBlue, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Patients',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${state.patients.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  style: TextStyle(fontSize: 14, color: textMain),
                  decoration: InputDecoration(
                    hintText: 'Search by name, ID or phone',
                    hintStyle:
                        const TextStyle(color: _kSub, fontSize: 13),
                    prefixIcon:
                        const Icon(Icons.search, color: _kSub, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                size: 18, color: _kSub),
                            onPressed: () {
                              _searchCtrl.clear();
                              ref
                                  .read(patientsProvider.notifier)
                                  .search('');
                            },
                          )
                        : Icon(Icons.tune_rounded,
                            size: 20,
                            color: isDark ? _kSub : _kNavy),
                    filled: true,
                    fillColor:
                        isDark ? _kDarkField : const Color(0xFFF5F7FF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.15),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          const BorderSide(color: _kBlue, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  onChanged: (v) =>
                      ref.read(patientsProvider.notifier).search(v),
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
          // ── Patient list ───────────────────────────────────────────────────
          Expanded(
            child: state.isLoading && state.patients.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.patients.isEmpty
                    ? _EmptyState(
                        hasSearch: state.search?.isNotEmpty == true,
                        isDark: isDark,
                        textMain: textMain,
                      )
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.read(patientsProvider.notifier).refresh(),
                        child: ListView.builder(
                          controller: _scrollCtrl,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                              16, 12, 16, 120),
                          itemCount: state.patients.length +
                              (state.hasMore ? 1 : 0),
                          itemBuilder: (ctx, i) {
                            if (i == state.patients.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                    child: CircularProgressIndicator()),
                              );
                            }
                            final p = state.patients[i];
                            return _PatientCard(
                              patient: p,
                              isDark: isDark,
                              cardBg: cardBg,
                              textMain: textMain,
                              onTap: () =>
                                  context.push('/patients/${p.id}'),
                              onAddVisit: () => _addVisit(p.id),
                              onPrint: () {
                                ref
                                    .read(activePatientDataProvider
                                        .notifier)
                                    .state = _patientDataMap(p);
                                context.go('/print-config');
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      // ── Bottom navigation bar ──────────────────────────────────────────────
      bottomNavigationBar: _BottomNavBar(
        isDark: isDark,
        selectedIndex: 1, // Patients tab always selected on this screen
        onTap: (index) {
          if (index == 2 && canWrite) {
            context.push('/patients/register');
          }
          // Dashboard, Reports, Profile: not yet implemented
        },
      ),
    );
  }
}

// ── Clinic + user header ───────────────────────────────────────────────────────

class _ClinicHeader extends StatelessWidget {
  final UserEntity? user;
  final VoidCallback onLogout;
  final bool isDark;
  final Color headerBg;
  final Color textMain;

  const _ClinicHeader({
    required this.user,
    required this.onLogout,
    required this.isDark,
    required this.headerBg,
    required this.textMain,
  });

  @override
  Widget build(BuildContext context) {
    final initials = user != null
        ? '${user!.firstName[0]}${user!.lastName.isNotEmpty ? user!.lastName[0] : ''}'
            .toUpperCase()
        : 'AU';
    final name = user?.fullName ?? 'Admin User';
    final role = user?.roleDisplayName ?? 'Admin';

    return Container(
      color: headerBg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Row 1: logo + clinic name + tagline ──────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Clinic logo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      width: 46,
                      height: 46,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          color: _kMaroon,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.local_hospital_rounded,
                            color: Colors.white, size: 26),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Clinic name + tagline (full remaining width)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'The Brain & Spine Clinic',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: _kMaroon,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          'Excellence. Ethics. Efficiency.',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontStyle: FontStyle.italic,
                            color: _kMaroon,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // ── Row 2: toggle + avatar + logout (right-aligned) ──────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ThemeTogglePill(isDark: isDark),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: _kBlue,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onLogout,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isDark
                            ? _kDarkField
                            : const Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        Icons.logout_rounded,
                        size: 16,
                        color: isDark ? Colors.white70 : _kNavy,
                      ),
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

// ── Sun / moon toggle pill ─────────────────────────────────────────────────────

class _ThemeTogglePill extends ConsumerWidget {
  final bool isDark;
  const _ThemeTogglePill({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(themeModeProvider.notifier).toggle(),
      child: Container(
        height: 30,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isDark ? _kDarkField : const Color(0xFFE8EEF8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.grey.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sun (light mode indicator)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: !isDark ? _kBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.wb_sunny_rounded,
                size: 14,
                color: !isDark ? Colors.white : _kSub,
              ),
            ),
            // Moon (dark mode indicator)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: isDark ? _kBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.nightlight_round,
                size: 14,
                color: isDark ? Colors.white : _kSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Patient card ──────────────────────────────────────────────────────────────

class _PatientCard extends StatelessWidget {
  final PatientEntity patient;
  final bool isDark;
  final Color cardBg;
  final Color textMain;
  final VoidCallback onTap;
  final VoidCallback onAddVisit;
  final VoidCallback onPrint;

  const _PatientCard({
    required this.patient,
    required this.isDark,
    required this.cardBg,
    required this.textMain,
    required this.onTap,
    required this.onAddVisit,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final ageSex = patient.ageSex;
    final phone  = patient.phone ?? '';
    final sub = [
      if (ageSex.isNotEmpty) ageSex,
      if (phone.isNotEmpty) phone,
    ].join('  •  ');
    final subtitle = sub.isNotEmpty ? sub : patient.prn;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.08))
            : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
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
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _avatarColor(patient.initials),
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
                                color: textMain,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _timeAgo(patient.createdAt),
                            style: const TextStyle(
                                fontSize: 12, color: _kSub),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: _kSub),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _kBlue.withValues(alpha: 0.5),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bottom navigation bar ─────────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final bool isDark;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _BottomNavBar({
    required this.isDark,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final navBg           = isDark ? _kDarkHeader : Colors.white;
    final selectedColor   = _kBlue;
    final unselectedColor = isDark
        ? const Color(0xFF5A6080)
        : const Color(0xFFADB8CC);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.grey.withValues(alpha: 0.15);

    return Container(
      decoration: BoxDecoration(
        color: navBg,
        border: Border(top: BorderSide(color: borderColor, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavTab(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Dashboard',
                isSelected: selectedIndex == 0,
                selectedColor: selectedColor,
                unselectedColor: unselectedColor,
                onTap: () => onTap(0),
              ),
              _NavTab(
                icon: Icons.people_outlined,
                activeIcon: Icons.people_rounded,
                label: 'Patients',
                isSelected: selectedIndex == 1,
                selectedColor: selectedColor,
                unselectedColor: unselectedColor,
                onTap: () => onTap(1),
              ),
              // Centre elevated "New Patient" button
              Expanded(
                child: GestureDetector(
                  onTap: () => onTap(2),
                  child: Center(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _kBlue,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _kBlue.withValues(alpha: 0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add,
                          color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
              _NavTab(
                icon: Icons.bar_chart_outlined,
                activeIcon: Icons.bar_chart_rounded,
                label: 'Reports',
                isSelected: selectedIndex == 3,
                selectedColor: selectedColor,
                unselectedColor: unselectedColor,
                onTap: () => onTap(3),
              ),
              _NavTab(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                isSelected: selectedIndex == 4,
                selectedColor: selectedColor,
                unselectedColor: unselectedColor,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? selectedColor : unselectedColor,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? selectedColor : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  final bool isDark;
  final Color textMain;

  const _EmptyState({
    required this.hasSearch,
    required this.isDark,
    required this.textMain,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasSearch ? Icons.search_off : Icons.people_outline,
            size: 64,
            color: _kSub.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch ? 'No patients found' : 'No patients yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textMain.withValues(alpha: 0.6),
            ),
          ),
          if (!hasSearch) ...[
            const SizedBox(height: 8),
            const Text(
              'Tap + to register a new patient',
              style: TextStyle(color: _kSub),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Map<String, String> _patientDataMap(PatientEntity patient) {
  final dob = patient.dateOfBirth != null
      ? DateFormat('dd MMMM yyyy').format(patient.dateOfBirth!)
      : '—';
  final gender = patient.sex != null && patient.sex!.isNotEmpty
      ? '${patient.sex![0].toUpperCase()}${patient.sex!.substring(1)}'
      : '—';
  return {
    'firstName':       patient.firstName,
    'lastName':        patient.lastName.isEmpty ? '—' : patient.lastName,
    'date':            DateFormat('dd-MM-yyyy').format(DateTime.now()),
    'dob':             dob,
    'gender':          gender,
    'phone':           patient.phone ?? '—',
    'altPhone':        patient.altPhone ?? '—',
    'email':           patient.email ?? '—',
    'address':         patient.address ?? '—',
    'idProofType':     patient.idProofType ?? '—',
    'idProofNumber':   patient.idProofNumber ?? '—',
    'weight':          patient.weight ?? '—',
    'bloodPressure':   patient.bloodPressure ?? '—',
    'temperature':     patient.temperature ?? '—',
    'allergies':       patient.allergies ?? '—',
    'medicalHistory':  patient.medicalHistory ?? '—',
    'previousHistory': patient.previousHistory ?? '—',
  };
}

// ── Logout confirmation dialog ─────────────────────────────────────────────
class _PendingSyncDialog extends StatelessWidget {
  final int pendingCount;
  const _PendingSyncDialog({required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1A1A3A) : Colors.white;
    final textPrimary = isDark ? const Color(0xFFEEECFF) : const Color(0xFF1A1A3A);
    final textSub = isDark ? const Color(0xFFB8B5DC) : const Color(0xFF6E6A63);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cloud icon with red count badge
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.cloud_off_rounded,
                      size: 32, color: Color(0xFFD32F2F)),
                ),
                Positioned(
                  top: -4, right: -4,
                  child: Container(
                    width: 24, height: 24,
                    decoration: const BoxDecoration(
                        color: Color(0xFFD32F2F), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(
                      pendingCount > 99 ? '99+' : '$pendingCount',
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Unsaved Data',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: textPrimary)),
            const SizedBox(height: 8),
            Text(
              '$pendingCount record${pendingCount == 1 ? '' : 's'} not yet synced to server.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: textSub),
            ),
            const SizedBox(height: 12),
            // Warning box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD32F2F).withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: Color(0xFFD32F2F)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Logging out now may cause data loss if this device is the only copy.',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFD32F2F),
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Buttons
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: isDark
                            ? const Color(0xFF3D3A62)
                            : const Color(0xFFE0DDD7)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: Text('Cancel',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: textPrimary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('Logout',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

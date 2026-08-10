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

// ── Palette (Image #15 design) ────────────────────────────────────────────────

const _kBg     = Color(0xFFF0F4FF);
const _kNavy   = Color(0xFF1A2D5A);
const _kMaroon = Color(0xFF7B1F2E);
const _kBlue   = Color(0xFF3C5A9A);
const _kSub    = Color(0xFF8090AA);
const _kBadge  = Color(0xFF3C5A9A);

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

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // ── Clinic + user header ──────────────────────────────────────
          _ClinicHeader(
            user: user,
            onLogout: () async {
              final pending = await ref.read(offlineQueueProvider).pending();
              if (pending.isNotEmpty && context.mounted) {
                final proceed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Pending Sync'),
                    content: Text(
                      '${pending.length} record(s) have not been synced to the server yet.\n\n'
                      'Logging out now may cause data loss if this device is the only copy.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Logout Anyway',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (proceed != true) return;
              }
              ref.read(authProvider.notifier).logout();
            },
          ),
          // ── Patients title + search ───────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_alt_rounded,
                        color: _kNavy, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Patients',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _kNavy,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kBadge,
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
                  style: const TextStyle(fontSize: 14, color: _kNavy),
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
                        : const Icon(Icons.tune_rounded,
                            size: 20, color: _kNavy),
                    filled: true,
                    fillColor: const Color(0xFFF5F7FF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.15)),
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
          // ── Patient list ──────────────────────────────────────────────
          Expanded(
            child: state.isLoading && state.patients.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.patients.isEmpty
                    ? _EmptyState(
                        hasSearch: state.search?.isNotEmpty == true,
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
      floatingActionButton: canWrite
          ? _NewPatientFab(
              onTap: () => context.push('/patients/register'))
          : null,
    );
  }
}

// ── Clinic + user header ──────────────────────────────────────────────────────

class _ClinicHeader extends StatelessWidget {
  final UserEntity? user;
  final VoidCallback onLogout;
  const _ClinicHeader({required this.user, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final initials = user != null
        ? '${user!.firstName[0]}${user!.lastName.isNotEmpty ? user!.lastName[0] : ''}'
            .toUpperCase()
        : 'AU';
    final name = user?.fullName ?? 'Admin User';
    final role = user?.roleDisplayName ?? 'Admin';

    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              // Clinic logo
              SizedBox(
                width: 52,
                height: 64,
                child: Image.asset(
                  'assets/images/app_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.local_hospital,
                      size: 36,
                      color: _kMaroon),
                ),
              ),
              const SizedBox(width: 8),
              // Clinic name + tagline
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'The Brain &\nSpine Clinic',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: _kMaroon,
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Excellence. Ethics. Efficiency.',
                      style: TextStyle(
                        fontSize: 9,
                        fontStyle: FontStyle.italic,
                        color: _kMaroon,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // User avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: _kBlue,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // User name + role
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kNavy,
                    ),
                  ),
                  Text(
                    role,
                    style: const TextStyle(fontSize: 11, color: _kSub),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              // Logout button
              GestureDetector(
                onTap: onLogout,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.logout_rounded,
                      size: 18, color: _kNavy),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Patient card ──────────────────────────────────────────────────────────────

class _PatientCard extends StatelessWidget {
  final PatientEntity patient;
  final VoidCallback onTap;
  final VoidCallback onAddVisit;
  final VoidCallback onPrint;

  const _PatientCard({
    required this.patient,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
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
                              style: const TextStyle(
                                color: _kNavy,
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

// ── FAB ───────────────────────────────────────────────────────────────────────

class _NewPatientFab extends StatelessWidget {
  final VoidCallback onTap;
  const _NewPatientFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          color: _kBlue,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: _kBlue.withValues(alpha: 0.4),
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
            Text(
              'New Patient',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
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
  const _EmptyState({required this.hasSearch});

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
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _kSub,
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

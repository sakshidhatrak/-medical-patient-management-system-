import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../patients/domain/entities/patient_entity.dart';
import '../../../patients/presentation/providers/patient_provider.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kPrimary  = Color(0xFF4B55CC);
const _kPrimSurf = Color(0xFFE8EBF8);
const _kPrimText = Color(0xFF3D47B4);
const _kBg       = Color(0xFFF8F6F2);
const _kBorder   = Color(0xFFE0DDD7);
const _kNavy     = Color(0xFF302D28);
const _kSlate    = Color(0xFF6E6A63);
const _kMuted    = Color(0xFF979088);
const _kRed      = Color(0xFFEF4444);

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

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
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(patientsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(patientsProvider);
    final vp    = MediaQuery.of(context).viewPadding;

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(children: [
        // ── Sticky primary header ──────────────────────────────────
        _PrimaryHeader(
          topPadding: vp.top,
          searchCtrl: _searchCtrl,
          patientCount: state.patients.length,
          isLoading: state.isLoading && state.patients.isNotEmpty,
          onChanged: (v) {
            setState(() {});
            ref.read(patientsProvider.notifier).search(v);
          },
          onClear: () {
            _searchCtrl.clear();
            ref.read(patientsProvider.notifier).search('');
            setState(() {});
          },
          onRefresh: () => ref.read(patientsProvider.notifier).refresh(),
        ),

        // ── Patient list ─────────────────────────────────────────
        Expanded(
          child: _PatientListSection(
            state: state,
            scrollCtrl: _scrollCtrl,
            onTap: (p) => context.push('/patients/${p.id}'),
            onRegister: () => context.push('/patients/register'),
            onRetry: () => ref.read(patientsProvider.notifier).refresh(),
          ),
        ),
      ]),

      // ── FAB ───────────────────────────────────────────────────
      floatingActionButton: _NewPatientFab(
        onPressed: () => context.push('/patients/register'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Primary header with search
// ─────────────────────────────────────────────────────────────────────────────
class _PrimaryHeader extends ConsumerWidget {
  final double topPadding;
  final TextEditingController searchCtrl;
  final int patientCount;
  final bool isLoading;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onRefresh;

  const _PrimaryHeader({
    required this.topPadding,
    required this.searchCtrl,
    required this.patientCount,
    required this.isLoading,
    required this.onChanged,
    required this.onClear,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user      = authState is AuthAuthenticated ? authState.user : null;
    final fullName  = user?.fullName ?? 'Doctor';
    final roleLabel = user?.roleDisplayName ?? 'Doctor';
    final initials  = fullName
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0])
        .join()
        .toUpperCase();

    return Container(
      decoration: const BoxDecoration(
        color: _kPrimary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, topPadding + 16, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // User row
        Row(children: [
          // Avatar
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(initials,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(fullName,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white)),
              Text(roleLabel,
                  style: TextStyle(
                      fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
            ]),
          ),
          // Logout
          GestureDetector(
            onTap: () => ref.read(authProvider.notifier).logout(),
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: Colors.white, size: 16),
            ),
          ),
        ]),

        const SizedBox(height: 12),

        // Patients title + count
        Row(children: [
          const Text('Patients',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$patientCount',
                style: const TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ]),

        const SizedBox(height: 10),

        // Search bar
        Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: searchCtrl,
            style: const TextStyle(fontSize: 13.5, color: _kNavy),
            decoration: InputDecoration(
              hintText: 'Search by name, ID or phone',
              hintStyle: const TextStyle(color: _kMuted, fontSize: 13.5),
              prefixIcon: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary)))
                  : const Icon(Icons.search_rounded, color: _kMuted, size: 18),
              prefixIconConstraints: const BoxConstraints(minWidth: 44),
              suffixIcon: searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 16, color: _kMuted),
                      onPressed: onClear)
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: onChanged,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Patient list
// ─────────────────────────────────────────────────────────────────────────────
class _PatientListSection extends StatelessWidget {
  final PatientsState state;
  final ScrollController scrollCtrl;
  final void Function(PatientEntity) onTap;
  final VoidCallback onRegister;
  final VoidCallback onRetry;

  const _PatientListSection({
    required this.state,
    required this.scrollCtrl,
    required this.onTap,
    required this.onRegister,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (state.error != null && state.patients.isEmpty) {
      return _ErrorState(message: state.error!, onRetry: onRetry);
    }
    if (state.isLoading && state.patients.isEmpty) {
      return const Center(
          child: Padding(
            padding: EdgeInsets.all(60),
            child: CircularProgressIndicator(color: _kPrimary),
          ));
    }
    if (state.patients.isEmpty) {
      return _EmptyState(hasSearch: state.search?.isNotEmpty == true, onRegister: onRegister);
    }

    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
      itemCount: state.patients.length + (state.isLoading ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == state.patients.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2)),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _PatientCard(
            patient: state.patients[i],
            onTap: () => onTap(state.patients[i]),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Patient card
// ─────────────────────────────────────────────────────────────────────────────
class _PatientCard extends StatelessWidget {
  final PatientEntity patient;
  final VoidCallback onTap;

  const _PatientCard({required this.patient, required this.onTap});

  static const _avatarColors = [
    Color(0xFF4B55CC),
    Color(0xFF7A6040),
    Color(0xFF8A4430),
    Color(0xFF52537A),
  ];

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return DateFormat('d MMM').format(t);
  }

  @override
  Widget build(BuildContext context) {
    final color = _avatarColors[patient.id.hashCode.abs() % _avatarColors.length];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _kBorder),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: color,
            child: Text(patient.initials,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          const SizedBox(width: 12),

          // Name + meta
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(patient.fullName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: _kNavy)),
              const SizedBox(height: 3),
              Text(
                '${patient.ageSex}${patient.ageSex.isNotEmpty ? ' · ' : ''}${patient.prn}',
                style: const TextStyle(fontSize: 11.5, color: _kMuted),
              ),
            ]),
          ),

          // Time + chevron
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min,
              children: [
            Text(_timeAgo(patient.createdAt),
                style: const TextStyle(fontSize: 10.5, color: _kMuted)),
            const SizedBox(height: 4),
            const Icon(Icons.chevron_right_rounded, size: 18, color: _kMuted),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAB
// ─────────────────────────────────────────────────────────────────────────────
class _NewPatientFab extends StatelessWidget {
  final VoidCallback onPressed;
  const _NewPatientFab({required this.onPressed});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onPressed,
    child: Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: _kPrimary,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
              color: _kPrimary.withValues(alpha: 0.4),
              blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.add_rounded, color: Colors.white, size: 20),
        SizedBox(width: 8),
        Text('New Patient',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onRegister;
  const _EmptyState({required this.hasSearch, required this.onRegister});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(48),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color: _kPrimSurf,
          shape: BoxShape.circle,
        ),
        child: Icon(
          hasSearch ? Icons.search_off_rounded : Icons.people_outline_rounded,
          size: 36, color: _kPrimary,
        ),
      ),
      const SizedBox(height: 18),
      Text(hasSearch ? 'No patients found' : 'No patients yet',
          style: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 16, color: _kNavy)),
      const SizedBox(height: 7),
      Text(
        hasSearch
            ? 'Try different search terms'
            : 'Register your first patient to get started',
        textAlign: TextAlign.center,
        style: const TextStyle(color: _kMuted, fontSize: 13),
      ),
      if (!hasSearch) ...[
        const SizedBox(height: 24),
        GestureDetector(
          onTap: onRegister,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            decoration: BoxDecoration(
              color: _kPrimary,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.person_add_rounded, color: Colors.white, size: 17),
              SizedBox(width: 8),
              Text('Register Patient',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            ]),
          ),
        ),
      ],
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(48),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 72, height: 72,
        decoration: const BoxDecoration(
          color: Color(0xFFF0E4DE),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.cloud_off_rounded, size: 36, color: Color(0xFF8A4430)),
      ),
      const SizedBox(height: 18),
      const Text('Could not load patients',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _kNavy)),
      const SizedBox(height: 7),
      Text(
        message.contains('timed out')
            ? 'Connection timed out. Check your network.'
            : message.contains('JWT') || message.contains('auth')
                ? 'Session expired. Please log in again.'
                : 'An error occurred loading patient data.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: _kMuted, fontSize: 13),
      ),
      const SizedBox(height: 24),
      GestureDetector(
        onTap: onRetry,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          decoration: BoxDecoration(
            color: _kPrimary,
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.refresh_rounded, color: Colors.white, size: 17),
            SizedBox(width: 8),
            Text('Try Again',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
        ),
      ),
    ]),
  );
}

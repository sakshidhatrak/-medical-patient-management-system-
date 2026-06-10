// ─────────────────────────────────────────────────────────────────────────────
// dashboard_screen.dart  –  MediManage Premium Dashboard (Linear × Stripe)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../patients/domain/entities/patient_entity.dart';
import '../../../patients/presentation/providers/patient_provider.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kP1    = Color(0xFF7C3AED);
const _kP2    = Color(0xFF3B82F6);
const _kRed   = Color(0xFFEF4444);
const _kGreen = Color(0xFF10B981);
const _kBg    = Color(0xFFF8FAFC);
const _kCard  = Colors.white;
const _kNavy  = Color(0xFF0F172A);
const _kSlate = Color(0xFF475569);
const _kMuted = Color(0xFF94A3B8);
const _kBorder= Color(0xFFE2E8F0);

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
    final now   = DateTime.now();
    final greeting = now.hour < 12 ? 'Good Morning'
        : now.hour < 17 ? 'Good Afternoon' : 'Good Evening';
    final todayCount = state.patients.where((p) =>
        p.createdAt.year  == now.year &&
        p.createdAt.month == now.month &&
        p.createdAt.day   == now.day).length;

    return Scaffold(
      backgroundColor: _kBg,
      floatingActionButton: _GradientFab(
        onPressed: () => context.push('/patients/register'),
      ),
      body: Column(children: [
        _PremiumHeader(greeting: greeting, now: now),
        Expanded(
          child: ListView(
            controller: _scrollCtrl,
            padding: EdgeInsets.zero,
            children: [
              // ── Stats cards ──────────────────────────────────────
              _StatsRow(
                total:  state.isLoading && state.patients.isEmpty ? null : state.patients.length,
                today:  todayCount,
              ),

              // ── Quick Actions ────────────────────────────────────
              _QuickActionsSection(onRegister: () => context.push('/patients/register')),

              // ── Search + list header ─────────────────────────────
              _SearchSection(
                controller: _searchCtrl,
                onChanged: (v) {
                  setState(() {});
                  ref.read(patientsProvider.notifier).search(v);
                },
                onClear: () {
                  _searchCtrl.clear();
                  ref.read(patientsProvider.notifier).search('');
                  setState(() {});
                },
                state: state,
                onRefresh: () => ref.read(patientsProvider.notifier).refresh(),
              ),

              // ── Patient list ─────────────────────────────────────
              _PatientListSection(
                state: state,
                onTap: (p) => context.push('/patients/${p.id}'),
                onRegister: () => context.push('/patients/register'),
                onRetry: () => ref.read(patientsProvider.notifier).refresh(),
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium gradient header
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumHeader extends StatelessWidget {
  final String greeting;
  final DateTime now;
  const _PremiumHeader({required this.greeting, required this.now});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6D28D9), Color(0xFF3B82F6)],
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20, right: 16, bottom: 20,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Logo badge
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('$greeting!',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800,
                        fontSize: 17, letterSpacing: -0.3)),
              ]),
              const SizedBox(height: 2),
              Text(
                'Dr. Harshal S. Chaudhari  ·  Neurosurgery',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
              ),
            ]),
          ),

          // Date badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const CircleAvatar(radius: 4, backgroundColor: Color(0xFF34D399)),
              const SizedBox(width: 6),
              Text(
                DateFormat('d MMM, EEE').format(now),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ]),
          ),

          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.person_add_outlined, color: Colors.white, size: 20),
            tooltip: 'Register Patient',
            onPressed: () => context.push('/patients/register'),
            padding: const EdgeInsets.all(8),
          ),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats row
// ─────────────────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int? total;
  final int today;
  const _StatsRow({this.total, required this.today});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Row(children: [
      Expanded(child: _StatCard(
        label: 'Total Patients',
        value: total == null ? '…' : '$total',
        icon: Icons.people_rounded,
        color1: _kP1,
        color2: _kP2,
      )),
      const SizedBox(width: 12),
      Expanded(child: _StatCard(
        label: 'Registered Today',
        value: '$today',
        icon: Icons.today_rounded,
        color1: const Color(0xFF059669),
        color2: _kGreen,
      )),
      const SizedBox(width: 12),
      Expanded(child: _StatCard(
        label: 'Active Visits',
        value: '—',
        icon: Icons.medical_services_rounded,
        color1: const Color(0xFFF59E0B),
        color2: const Color(0xFFFBBF24),
      )),
    ]),
  );
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color1, color2;
  const _StatCard({
    required this.label, required this.value,
    required this.icon, required this.color1, required this.color2,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _kBorder),
      boxShadow: [
        BoxShadow(color: color1.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color1, color2]),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
      const SizedBox(height: 10),
      Text(value, style: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w800, color: _kNavy, letterSpacing: -0.5)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10, color: _kMuted, fontWeight: FontWeight.w500),
          maxLines: 1, overflow: TextOverflow.ellipsis),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Actions
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActionsSection extends StatelessWidget {
  final VoidCallback onRegister;
  const _QuickActionsSection({required this.onRegister});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Quick Actions',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kSlate)),
      const SizedBox(height: 10),
      Row(children: [
        _QAction(
          icon: Icons.person_add_rounded,
          label: 'Register Patient',
          color: _kP1,
          onTap: () => context.push('/patients/register'),
        ),
        const SizedBox(width: 10),
        _QAction(
          icon: Icons.medical_services_rounded,
          label: 'New Visit',
          color: _kP2,
          onTap: () => context.push('/patients'),
        ),
        const SizedBox(width: 10),
        _QAction(
          icon: Icons.local_hospital_rounded,
          label: 'New Surgery',
          color: _kRed,
          onTap: () => context.push('/patients'),
        ),
        const SizedBox(width: 10),
        _QAction(
          icon: Icons.search_rounded,
          label: 'Find Patient',
          color: _kGreen,
          onTap: () => context.push('/patients'),
        ),
      ]),
    ]),
  );
}

class _QAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center, maxLines: 2),
        ]),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Search + list header
// ─────────────────────────────────────────────────────────────────────────────
class _SearchSection extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final PatientsState state;
  final VoidCallback onRefresh;

  const _SearchSection({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.state,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Search bar
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Search by name, PRN or phone…',
            hintStyle: const TextStyle(color: _kMuted, fontSize: 14),
            prefixIcon: const Icon(Icons.search_rounded, color: _kMuted, size: 20),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(icon: const Icon(Icons.close, size: 17, color: _kMuted), onPressed: onClear)
                : null,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _kP1, width: 1.5),
            ),
          ),
          onChanged: onChanged,
        ),
      ),

      const SizedBox(height: 14),

      // List header
      Row(children: [
        Text(
          state.isLoading && state.patients.isEmpty
              ? 'Loading patients…'
              : state.search?.isNotEmpty == true
                  ? '${state.patients.length} result${state.patients.length == 1 ? '' : 's'}'
                  : 'All Patients  ·  ${state.patients.length}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kSlate),
        ),
        const Spacer(),
        if (state.isLoading)
          const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kP1)),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, size: 18, color: _kMuted),
          tooltip: 'Refresh',
          onPressed: onRefresh,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(),
        ),
      ]),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Patient list
// ─────────────────────────────────────────────────────────────────────────────
class _PatientListSection extends StatelessWidget {
  final PatientsState state;
  final void Function(PatientEntity) onTap;
  final VoidCallback onRegister;
  final VoidCallback onRetry;
  const _PatientListSection({
    required this.state, required this.onTap,
    required this.onRegister, required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (state.error != null && state.patients.isEmpty) {
      return _ErrorState(message: state.error!, onRetry: onRetry);
    }
    if (state.isLoading && state.patients.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(60),
        child: Center(child: CircularProgressIndicator(color: _kP1)),
      );
    }
    if (state.patients.isEmpty) {
      return _EmptyState(hasSearch: state.search?.isNotEmpty == true, onRegister: onRegister);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(children: [
        ...state.patients.map((p) => _PatientTile(patient: p, onTap: () => onTap(p))),
        if (state.hasMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(color: _kP1, strokeWidth: 2)),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Patient tile
// ─────────────────────────────────────────────────────────────────────────────
class _PatientTile extends StatelessWidget {
  final PatientEntity patient;
  final VoidCallback onTap;
  const _PatientTile({required this.patient, required this.onTap});

  static const _gradients = [
    [Color(0xFF7C3AED), Color(0xFF6D28D9)],
    [Color(0xFF2563EB), Color(0xFF3B82F6)],
    [Color(0xFF059669), Color(0xFF10B981)],
    [Color(0xFFDC2626), Color(0xFFEF4444)],
    [Color(0xFFD97706), Color(0xFFF59E0B)],
    [Color(0xFF0891B2), Color(0xFF06B6D4)],
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
    final grad = _gradients[patient.id.hashCode.abs() % _gradients.length];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
            ),
            child: Row(children: [
              // Gradient avatar
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: grad, begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  patient.initials,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              const SizedBox(width: 13),

              // Name + tags
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(patient.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _kNavy)),
                  const SizedBox(height: 5),
                  Wrap(spacing: 5, children: [
                    if (patient.ageSex.isNotEmpty)
                      _Chip(patient.ageSex, grad[0]),
                    _Chip('PRN: ${patient.prn}', _kMuted),
                    if (patient.phone?.isNotEmpty == true)
                      _Chip(patient.phone!, _kMuted, icon: Icons.phone_outlined),
                  ]),
                ]),
              ),

              // Time + chevron
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_timeAgo(patient.createdAt),
                    style: const TextStyle(fontSize: 11, color: _kMuted, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: _kBorder,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.chevron_right_rounded, size: 16, color: _kMuted),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const _Chip(this.text, this.color, {this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[
        Icon(icon, size: 9, color: color),
        const SizedBox(width: 3),
      ],
      Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Gradient FAB
// ─────────────────────────────────────────────────────────────────────────────
class _GradientFab extends StatelessWidget {
  final VoidCallback onPressed;
  const _GradientFab({required this.onPressed});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onPressed,
    child: Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_kP1, _kP2]),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(color: _kP1.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
        SizedBox(width: 8),
        Text('New Patient',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
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
        width: 80, height: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_kP1.withValues(alpha: 0.1), _kP2.withValues(alpha: 0.1)],
          ),
          shape: BoxShape.circle,
        ),
        child: Icon(
          hasSearch ? Icons.search_off_rounded : Icons.people_outline_rounded,
          size: 40, color: _kP1.withValues(alpha: 0.5),
        ),
      ),
      const SizedBox(height: 20),
      Text(hasSearch ? 'No patients found' : 'No patients yet',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: _kNavy)),
      const SizedBox(height: 8),
      Text(
        hasSearch ? 'Try different search terms' : 'Register your first patient to get started',
        textAlign: TextAlign.center,
        style: const TextStyle(color: _kMuted, fontSize: 13),
      ),
      if (!hasSearch) ...[
        const SizedBox(height: 24),
        GestureDetector(
          onTap: onRegister,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kP1, _kP2]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: _kP1.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Register Patient',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
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
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: _kRed.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.cloud_off_rounded, size: 40, color: _kRed.withValues(alpha: 0.7)),
      ),
      const SizedBox(height: 20),
      const Text('Could not load patients',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: _kNavy)),
      const SizedBox(height: 8),
      Text(
        message.contains('timed out') ? 'Connection timed out. Check your network.'
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kP1, _kP2]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Try Again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    ]),
  );
}

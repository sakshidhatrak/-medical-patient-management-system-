import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../patients/domain/entities/patient_entity.dart';
import '../../../patients/presentation/providers/patient_provider.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kP1    = Color(0xFF4F46E5);
const _kP2    = Color(0xFF3B82F6);
const _kRed   = Color(0xFFEF4444);
const _kBg    = Color(0xFFF8FAFC);
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

    return Scaffold(
      backgroundColor: _kBg,
      floatingActionButton: _GradientFab(
        onPressed: () => context.push('/patients/register'),
      ),
      body: Column(children: [
        _DashboardTopBar(),
        Expanded(
          child: ListView(
            controller: _scrollCtrl,
            padding: EdgeInsets.zero,
            children: [
              _QuickActionsSection(onRegister: () => context.push('/patients/register')),
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
// Top bar
// ─────────────────────────────────────────────────────────────────────────────
class _DashboardTopBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final firstName = user?.fullName.split(' ').first ?? 'Doctor';
    final fullName  = user?.fullName ?? 'Doctor';
    final roleLabel = user?.roleDisplayName ?? 'Administrator';
    final initials  = fullName
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0])
        .join()
        .toUpperCase();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 14,
        left: 24, right: 20, bottom: 16,
      ),
      child: Row(children: [
        // Welcome
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Welcome back, $firstName 👋',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: _kNavy,
                    letterSpacing: -0.4)),
            const SizedBox(height: 2),
            const Text('Manage your clinic activities efficiently.',
                style: TextStyle(fontSize: 13, color: _kMuted)),
          ]),
        ),

        // Bell badge
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              shape: BoxShape.circle,
              border: Border.all(color: _kBorder),
            ),
            child: const Icon(Icons.notifications_outlined, size: 20, color: _kSlate),
          ),
          Positioned(
            top: -2, right: -2,
            child: Container(
              width: 18, height: 18,
              decoration: const BoxDecoration(color: _kP1, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Text('3',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),

        const SizedBox(width: 14),

        // User info
        Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _kP1,
            child: Text(initials,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fullName,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kNavy)),
            Text(roleLabel,
                style: const TextStyle(fontSize: 11, color: _kMuted)),
          ]),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, color: _kMuted, size: 20),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Actions
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActionsSection extends StatelessWidget {
  final VoidCallback onRegister;
  const _QuickActionsSection({required this.onRegister});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Quick Actions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kNavy)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: _QuickActionCard(
            iconBg: const Color(0xFFEEF2FF),
            iconColor: _kP1,
            icon: Icons.person_add_outlined,
            title: 'Register Patient',
            subtitle: 'Add new patient',
            onTap: onRegister,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionCard(
            iconBg: const Color(0xFFEFF6FF),
            iconColor: _kP2,
            icon: Icons.calendar_today_outlined,
            title: 'New Visit',
            subtitle: 'Record patient visit',
            onTap: () => context.push('/patients'),
          ),
        ),
      ]),
    ]),
  );
}

class _QuickActionCard extends StatelessWidget {
  final Color iconBg, iconColor;
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.iconBg, required this.iconColor, required this.icon,
    required this.title, required this.subtitle, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: iconColor)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(fontSize: 12, color: _kMuted)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: _kMuted, size: 22),
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
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Search + filter row
      Row(children: [
        // Search field
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: TextField(
              controller: controller,
              style: const TextStyle(fontSize: 14, color: _kNavy),
              decoration: InputDecoration(
                hintText: 'Search by name, PRN or phone...',
                hintStyle: const TextStyle(color: _kMuted, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: _kMuted, size: 20),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 17, color: _kMuted),
                        onPressed: onClear)
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kP1, width: 1.5),
                ),
              ),
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // All Patients dropdown (decorative label)
        _FilterButton(
          child: Row(mainAxisSize: MainAxisSize.min, children: const [
            Text('All Patients',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kNavy)),
            SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, color: _kMuted, size: 18),
          ]),
        ),
        const SizedBox(width: 8),

        // Filters button
        _FilterButton(
          child: Row(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.tune_rounded, color: _kSlate, size: 16),
            SizedBox(width: 5),
            Text('Filters',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kNavy)),
          ]),
        ),
        const SizedBox(width: 8),

        // Refresh icon
        GestureDetector(
          onTap: onRefresh,
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder),
            ),
            child: state.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kP1))
                : const Icon(Icons.refresh_rounded, color: _kSlate, size: 18),
          ),
        ),
      ]),

      const SizedBox(height: 16),

      // List header
      Row(children: [
        Text(
          state.isLoading && state.patients.isEmpty
              ? 'Loading patients…'
              : state.search?.isNotEmpty == true
                  ? 'Results'
                  : 'All Patients',
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: _kNavy),
        ),
        const SizedBox(width: 8),
        if (!state.isLoading || state.patients.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('${state.patients.length}',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: _kP1)),
          ),
      ]),
    ]),
  );
}

class _FilterButton extends StatelessWidget {
  final Widget child;
  const _FilterButton({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _kBorder),
    ),
    child: child,
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
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: state.patients.asMap().entries.map((e) {
            final isLast = e.key == state.patients.length - 1;
            return _PatientTile(
              patient: e.value,
              onTap: () => onTap(e.value),
              isLast: isLast,
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Patient tile
// ─────────────────────────────────────────────────────────────────────────────
class _PatientTile extends StatelessWidget {
  final PatientEntity patient;
  final VoidCallback onTap;
  final bool isLast;

  const _PatientTile({
    required this.patient,
    required this.onTap,
    this.isLast = false,
  });

  static const _avatarColors = [
    Color(0xFF14B8A6),
    Color(0xFF3B82F6),
    Color(0xFFF97316),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF10B981),
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.vertical(
          top: isLast == false && patient.id == patient.id ? Radius.zero : Radius.zero,
          bottom: isLast ? const Radius.circular(16) : Radius.zero,
        ),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(bottom: BorderSide(color: _kBorder)),
          ),
          child: Row(children: [
            // Circle avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: color,
              child: Text(
                patient.initials,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),

            // Name + chips
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(patient.fullName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14, color: _kNavy)),
                const SizedBox(height: 5),
                Wrap(spacing: 5, runSpacing: 4, children: [
                  if (patient.ageSex.isNotEmpty)
                    _Chip(patient.ageSex, color),
                  _Chip('PRN: ${patient.prn}', _kMuted),
                  if (patient.phone?.isNotEmpty == true)
                    _Chip(patient.phone!, _kMuted, icon: Icons.phone_outlined),
                ]),
              ]),
            ),

            // Time + chevron
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_timeAgo(patient.createdAt),
                  style: const TextStyle(fontSize: 11, color: _kMuted, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, size: 20, color: _kMuted),
            ]),
          ]),
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
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[
        Icon(icon, size: 9, color: color),
        const SizedBox(width: 3),
      ],
      Text(text,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
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
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: _kP1,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
              color: _kP1.withValues(alpha: 0.35),
              blurRadius: 16, offset: const Offset(0, 6)),
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
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: _kP1.withValues(alpha: 0.08),
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
            decoration: BoxDecoration(
              color: _kP1,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: _kP1.withValues(alpha: 0.3),
                    blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
          decoration: BoxDecoration(
            color: _kP1,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Try Again',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    ]),
  );
}

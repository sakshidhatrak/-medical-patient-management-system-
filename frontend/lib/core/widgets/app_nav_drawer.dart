import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../theme/app_dimensions.dart';

// ── Sidebar design tokens ──────────────────────────────────────────────────
const _kSidebarBg     = Colors.white;
const _kActiveColor   = Color(0xFF4F46E5);
const _kActiveBg      = Color(0xFFEEF2FF);
const _kNavyText      = Color(0xFF0F172A);
const _kMutedText     = Color(0xFF64748B);
const _kBorder        = Color(0xFFE2E8F0);

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;

  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}

final appNavItems = <NavItem>[
  NavItem(
    icon: Icons.grid_view_outlined,
    activeIcon: Icons.grid_view_rounded,
    label: 'Dashboard',
    route: '/dashboard',
  ),
  NavItem(
    icon: Icons.people_outline_rounded,
    activeIcon: Icons.people_rounded,
    label: 'Patients',
    route: '/patients',
  ),
];

/// Persistent rail used on tablets (width ≥ 768)
class AppNavRail extends StatelessWidget {
  final String currentRoute;
  final ValueChanged<String> onSelect;
  final String doctorName;
  final String doctorRole;

  const AppNavRail({
    super.key,
    required this.currentRoute,
    required this.onSelect,
    this.doctorName = 'Dr. Sarah Chen',
    this.doctorRole = 'Cardiologist',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: _kSidebarBg,
        border: Border(right: BorderSide(color: _kBorder)),
      ),
      child: Column(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          const _SidebarLogo(),
          const Divider(height: 1, color: _kBorder),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: appNavItems.length,
              itemBuilder: (context, i) {
                final item = appNavItems[i];
                final isActive = currentRoute.startsWith(item.route);
                return _NavRailItem(
                  item: item,
                  isActive: isActive,
                  onTap: () => onSelect(item.route),
                );
              },
            ),
          ),
          _SidebarFooter(doctorName: doctorName),
        ],
      ),
    );
  }
}

/// Drawer used on phones
class AppNavDrawer extends StatelessWidget {
  final String currentRoute;
  final ValueChanged<String> onSelect;
  final String doctorName;
  final String doctorRole;

  const AppNavDrawer({
    super.key,
    required this.currentRoute,
    required this.onSelect,
    this.doctorName = 'Dr. Sarah Chen',
    this.doctorRole = 'Cardiologist',
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: _kSidebarBg,
      width: 260,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(AppDimensions.radiusXl),
          bottomRight: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const _SidebarLogo(),
            const Divider(height: 1, color: _kBorder),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: appNavItems.length,
                itemBuilder: (context, i) {
                  final item = appNavItems[i];
                  final isActive = currentRoute.startsWith(item.route);
                  return _NavRailItem(
                    item: item,
                    isActive: isActive,
                    onTap: () {
                      Navigator.pop(context);
                      onSelect(item.route);
                    },
                  );
                },
              ),
            ),
            _SidebarFooter(doctorName: doctorName),
          ],
        ),
      ),
    );
  }
}

// ── CarePlus logo header ───────────────────────────────────────────────────
class _SidebarLogo extends StatelessWidget {
  const _SidebarLogo();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF4F46E5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
      ),
      const SizedBox(width: 10),
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('CarePlus',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: _kNavyText,
                letterSpacing: -0.3)),
        Text('Health System',
            style: TextStyle(fontSize: 11, color: _kMutedText)),
      ]),
    ]),
  );
}

// ── Nav item ───────────────────────────────────────────────────────────────
class _NavRailItem extends StatelessWidget {
  final NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _NavRailItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? _kActiveBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(
              isActive ? item.activeIcon : item.icon,
              color: isActive ? _kActiveColor : _kMutedText,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              item.label,
              style: TextStyle(
                color: isActive ? _kActiveColor : _kNavyText,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ]),
        ),
      ),
    ),
  );
}

// ── Footer ─────────────────────────────────────────────────────────────────
class _SidebarFooter extends ConsumerWidget {
  final String doctorName;
  const _SidebarFooter({required this.doctorName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final currentUser = user is AuthAuthenticated ? user.user : null;
    final roleLabel = currentUser?.roleDisplayName ?? 'Admin';
    final isViewOnly = currentUser != null && !currentUser.canWrite;
    final initials = doctorName
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0])
        .join()
        .toUpperCase();

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        if (isViewOnly) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.visibility_outlined, color: Colors.orange, size: 13),
                SizedBox(width: 5),
                Text('View Only Access',
                    style: TextStyle(
                        color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],

        // User pill
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kBorder),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: const Color(0xFF4F46E5),
              child: Text(initials,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(doctorName,
                    style: const TextStyle(
                        color: _kNavyText, fontSize: 12, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(roleLabel,
                    style: const TextStyle(color: _kMutedText, fontSize: 10)),
              ]),
            ),
            const Icon(Icons.settings_outlined, color: _kMutedText, size: 16),
          ]),
        ),

        const SizedBox(height: 8),

        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFFFE4E6), width: 1),
              ),
              backgroundColor: const Color(0xFFFFF1F2),
            ),
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: const Text('Logout',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ),
      ]),
    );
  }
}

/// Shell widget — shows rail on tablet, drawer on phone
class AppShell extends ConsumerWidget {
  final Widget child;
  final String currentRoute;
  final ValueChanged<String> onNavigate;

  const AppShell({
    super.key,
    required this.child,
    required this.currentRoute,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final currentUser = authState is AuthAuthenticated ? authState.user : null;
    final doctorName = currentUser != null
        ? (currentUser.isAdmin ? 'Dr. ${currentUser.fullName}' : currentUser.fullName)
        : 'Dr. Harshal S. Chaudhari';
    final doctorRole = currentUser?.roleDisplayName ?? 'Neurosurgery';

    final isTablet = MediaQuery.of(context).size.width >= 768;

    if (isTablet) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Row(
          children: [
            AppNavRail(
              currentRoute: currentRoute,
              onSelect: onNavigate,
              doctorName: doctorName,
              doctorRole: doctorRole,
            ),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: AppNavDrawer(
        currentRoute: currentRoute,
        onSelect: onNavigate,
        doctorName: doctorName,
        doctorRole: doctorRole,
      ),
      body: child,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

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
  NavItem(
    icon: Icons.insert_chart_outlined_rounded,
    activeIcon: Icons.insert_chart_rounded,
    label: 'Reports',
    route: '/reports',
  ),
  NavItem(
    icon: Icons.print_outlined,
    activeIcon: Icons.print_rounded,
    label: 'Print & Export',
    route: '/print-config',
  ),
  NavItem(
    icon: Icons.calendar_today_outlined,
    activeIcon: Icons.calendar_today_rounded,
    label: 'Appointments',
    route: '/appointments',
  ),
  NavItem(
    icon: Icons.chat_bubble_outline_rounded,
    activeIcon: Icons.chat_bubble_rounded,
    label: 'Messages',
    route: '/messages',
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
      color: AppColors.sidebarBg,
      child: Column(
        children: [
          _SidebarHeader(
            doctorName: doctorName,
            doctorRole: doctorRole,
          ),
          const SizedBox(height: AppDimensions.md),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: AppDimensions.sm),
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
      backgroundColor: AppColors.sidebarBg,
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
            const SizedBox(height: AppDimensions.md),
            _SidebarHeader(
              doctorName: doctorName,
              doctorRole: doctorRole,
            ),
            const SizedBox(height: AppDimensions.md),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: AppDimensions.sm),
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

class _SidebarHeader extends StatelessWidget {
  final String doctorName;
  final String doctorRole;

  const _SidebarHeader({required this.doctorName, required this.doctorRole});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: AppDimensions.md),
      child: Row(
        children: [
          _DoctorAvatar(name: doctorName),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctorName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  doctorRole,
                  style: const TextStyle(
                    color: AppColors.sidebarText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: isActive
                  ? Border(
                      left: BorderSide(
                          color: AppColors.primary, width: 3),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  isActive ? item.activeIcon : item.icon,
                  color: isActive
                      ? AppColors.primary
                      : AppColors.sidebarText,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    color: isActive
                        ? Colors.white
                        : AppColors.sidebarText,
                    fontWeight: isActive
                        ? FontWeight.w600
                        : FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarFooter extends ConsumerWidget {
  final String doctorName;

  const _SidebarFooter({required this.doctorName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.sidebarItemHover,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Row(
              children: [
                _DoctorAvatar(name: doctorName, radius: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctorName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Admin',
                        style: TextStyle(
                          color: AppColors.sidebarText,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.settings_outlined,
                  color: AppColors.sidebarText,
                  size: 18,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () async {
                Navigator.of(context).pop(); // close drawer if open
                await ref.read(authProvider.notifier).logout();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  side: const BorderSide(color: Colors.redAccent, width: 1),
                ),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorAvatar extends StatelessWidget {
  final String name;
  final double radius;

  const _DoctorAvatar({required this.name, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0])
        .join()
        .toUpperCase();

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.7,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Shell widget — shows rail on tablet, drawer on phone
class AppShell extends StatefulWidget {
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
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 768;

    if (isTablet) {
      return Scaffold(
        body: Row(
          children: [
            AppNavRail(
              currentRoute: widget.currentRoute,
              onSelect: widget.onNavigate,
            ),
            Expanded(child: widget.child),
          ],
        ),
      );
    }

    return Scaffold(
      drawer: AppNavDrawer(
        currentRoute: widget.currentRoute,
        onSelect: widget.onNavigate,
      ),
      body: widget.child,
    );
  }
}

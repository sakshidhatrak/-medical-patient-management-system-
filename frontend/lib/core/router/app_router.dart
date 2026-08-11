import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/examinations/presentation/screens/examination_screen.dart';
import '../../features/patients/presentation/screens/patient_detail_screen.dart';
import '../../features/patients/presentation/screens/patient_list_screen.dart';
import '../../features/patients/presentation/screens/patient_register_screen.dart';
import '../../features/print_configuration/presentation/screens/print_config_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/surgeries/presentation/screens/surgery_form_screen.dart';
import '../../features/visits/presentation/screens/add_visit_wizard_screen.dart';
import '../../features/visits/presentation/screens/visit_form_screen.dart';
import '../../features/visits/presentation/screens/visit_view_screen.dart';
import '../widgets/app_nav_drawer.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RouteNames.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final authState  = ref.read(authProvider);
      final isAuth     = authState is AuthAuthenticated;
      final loc        = state.matchedLocation;
      final isAuthPage = loc == RouteNames.login || loc == RouteNames.splash;

      if (!isAuth && !isAuthPage) return RouteNames.login;
      if (isAuth  && loc == RouteNames.login) return RouteNames.patients;

      // View-only guard: assistants cannot access write routes
      if (isAuth && authState.user.role == UserRole.assistant) {
        // Block new patient registration
        if (loc == '/patients/register') return '/patients';

        // Block new visit creation
        if (loc.endsWith('/new-visit')) {
          return loc.substring(0, loc.length - '/new-visit'.length);
        }

        // Block surgery form
        final surgeryMatch = RegExp(r'^(.*)/surgeries/[^/]+$').firstMatch(loc);
        if (surgeryMatch != null) return surgeryMatch.group(1)!;

        // Block visit edit form — redirect to read-only view
        final visitEditMatch =
            RegExp(r'^(/patients/[^/]+/visits/[^/]+)$').firstMatch(loc);
        if (visitEditMatch != null) return '${visitEditMatch.group(1)!}/view';

        // Block examination form — redirect to read-only view
        if (loc.endsWith('/examination')) {
          final base = loc.substring(0, loc.length - '/examination'.length);
          return '$base/view';
        }
      }

      return null;
    },
    refreshListenable: _AuthListenable(ref),
    routes: [
      // ── Auth (no sidebar) ──────────────────────────────────────
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (_, __) => const LoginScreen(),
      ),

      // ── Main app shell (persistent sidebar) ───────────────────
      ShellRoute(
        builder: (context, state, child) => AppShell(
          currentRoute: state.matchedLocation,
          onNavigate: (route) => context.go(route),
          child: child,
        ),
        routes: [
          // Dashboard
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),

          // Reports
          GoRoute(
            path: '/reports',
            name: 'reports',
            builder: (_, __) => const ReportsScreen(),
          ),

          // Print & Export
          GoRoute(
            path: '/print-config',
            name: 'print-config',
            builder: (_, __) => const PrintConfigScreen(),
          ),

          // Appointments placeholder
          GoRoute(
            path: '/appointments',
            name: 'appointments',
            builder: (_, __) => const _PlaceholderScreen(
              title: 'Appointments',
              icon: Icons.calendar_today_rounded,
            ),
          ),

          // Messages placeholder
          GoRoute(
            path: '/messages',
            name: 'messages',
            builder: (_, __) => const _PlaceholderScreen(
              title: 'Messages',
              icon: Icons.chat_bubble_rounded,
            ),
          ),

          // Patients
          GoRoute(
            path: '/patients',
            name: 'patients',
            builder: (_, __) => const PatientListScreen(),
            routes: [
              GoRoute(
                path: 'register',
                name: 'patient-register',
                builder: (_, __) => const PatientRegisterScreen(),
              ),
              GoRoute(
                path: ':patientId',
                name: 'patient-detail',
                builder: (_, s) => PatientDashboardScreen(
                  patientId: s.pathParameters['patientId']!,
                ),
                routes: [
                  // ── New visit wizard (no pre-create) ──────────
                  GoRoute(
                    path: 'new-visit',
                    name: 'new-visit',
                    builder: (_, s) => AddVisitWizardScreen(
                      patientId: s.pathParameters['patientId']!,
                    ),
                  ),

                  // ── Visits (edit/view via wizard) ─────────────
                  GoRoute(
                    path: 'visits/:visitId',
                    name: 'visit-form',
                    builder: (_, s) => AddVisitWizardScreen(
                      patientId: s.pathParameters['patientId']!,
                      visitId:   s.pathParameters['visitId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'examination',
                        name: 'examination',
                        builder: (_, s) => ExaminationScreen(
                          patientId: s.pathParameters['patientId']!,
                          visitId:   s.pathParameters['visitId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'view',
                        name: 'visit-view',
                        builder: (_, s) => VisitViewScreen(
                          patientId: s.pathParameters['patientId']!,
                          visitId:   s.pathParameters['visitId']!,
                        ),
                      ),
                    ],
                  ),

                  // ── Surgeries ─────────────────────────────────
                  GoRoute(
                    path: 'surgeries/:surgeryId',
                    name: 'surgery-form',
                    builder: (_, s) => SurgeryFormScreen(
                      patientId:  s.pathParameters['patientId']!,
                      surgeryId:  s.pathParameters['surgeryId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev.runtimeType != next.runtimeType) notifyListeners();
    });
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  const _PlaceholderScreen({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8FAFC),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: const Color(0xFF6C63FF), size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Coming soon',
            style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    ),
  );
}

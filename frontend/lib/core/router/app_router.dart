import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/patients/presentation/screens/patient_create_screen.dart';
import '../../features/patients/presentation/screens/patient_detail_screen.dart';
import '../../features/patients/presentation/screens/patient_list_screen.dart';
import '../../features/patients/presentation/screens/patient_timeline_screen.dart';
import '../../features/patients/presentation/screens/add_visit_screen.dart';
import '../../features/print_configuration/presentation/screens/print_config_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RouteNames.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isAuthenticated = authState is AuthAuthenticated;
      final location = state.matchedLocation;

      final isAuthRoute = location == RouteNames.login ||
          location == RouteNames.splash;

      if (!isAuthenticated && !isAuthRoute) return RouteNames.login;
      if (isAuthenticated && location == RouteNames.login) {
        return RouteNames.dashboard;
      }
      return null;
    },
    refreshListenable: _AuthStateListenable(ref),
    routes: [
      // ── Auth ──────────────────────────────────────────────────────────────
      GoRoute(
        path: RouteNames.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.login,
        name: 'login',
        builder: (_, __) => const LoginScreen(),
      ),

      // ── Dashboard ─────────────────────────────────────────────────────────
      GoRoute(
        path: RouteNames.dashboard,
        name: 'dashboard',
        builder: (_, __) => const DashboardScreen(),
      ),

      // ── Patients ──────────────────────────────────────────────────────────
      GoRoute(
        path: RouteNames.patients,
        name: 'patients',
        builder: (_, __) => const PatientListScreen(),
        routes: [
          // 'new' must be declared before ':id' so GoRouter matches it first.
          GoRoute(
            path: 'new',
            name: 'patient-create',
            builder: (_, __) => const PatientCreateScreen(),
          ),
          GoRoute(
            path: ':id',
            name: 'patient-detail',
            builder: (_, state) => PatientDetailScreen(
              patientId: state.pathParameters['id']!,
            ),
            routes: [
              GoRoute(
                path: 'timeline',
                name: 'patient-timeline',
                builder: (_, state) => PatientTimelineScreen(
                  patientId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: 'add-visit',
                name: 'patient-add-visit',
                builder: (_, state) => AddVisitScreen(
                  patientId: state.pathParameters['id']!,
                  patientName:
                      state.uri.queryParameters['name'] ?? 'Patient',
                ),
              ),
            ],
          ),
        ],
      ),

      // ── Reports ───────────────────────────────────────────────────────────
      GoRoute(
        path: RouteNames.reports,
        name: 'reports',
        builder: (_, __) => const ReportsScreen(),
      ),

      // ── Print Configuration ───────────────────────────────────────────────
      GoRoute(
        path: RouteNames.printConfig,
        name: 'print-config',
        builder: (_, __) => const PrintConfigScreen(),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});

class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(Ref ref) {
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev.runtimeType != next.runtimeType) {
        notifyListeners();
      }
    });
  }
}

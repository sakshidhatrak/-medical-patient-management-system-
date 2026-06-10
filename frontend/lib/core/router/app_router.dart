import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/examinations/presentation/screens/examination_screen.dart';
import '../../features/patients/presentation/screens/patient_detail_screen.dart';
import '../../features/patients/presentation/screens/patient_list_screen.dart';
import '../../features/patients/presentation/screens/patient_register_screen.dart';
import '../../features/surgeries/presentation/screens/surgery_form_screen.dart';
import '../../features/visits/presentation/screens/visit_form_screen.dart';
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
      if (isAuth  && loc == RouteNames.login) return RouteNames.dashboard;
      return null;
    },
    refreshListenable: _AuthListenable(ref),
    routes: [
      // ── Auth ───────────────────────────────────────────────────
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (_, __) => const LoginScreen(),
      ),

      // ── Dashboard ──────────────────────────────────────────────
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (_, __) => const DashboardScreen(),
      ),

      // ── Patients ───────────────────────────────────────────────
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
              // ── Visits ─────────────────────────────────────────
              GoRoute(
                path: 'visits/:visitId',
                name: 'visit-form',
                builder: (_, s) => VisitFormScreen(
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
                ],
              ),

              // ── Surgeries ──────────────────────────────────────
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

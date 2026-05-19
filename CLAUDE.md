# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Medical Patient Management System** — a full-stack system. The Flutter frontend lives in `frontend/`. Backend, database, and deployment directories are reserved for future implementation.

---

## Flutter Frontend (`frontend/`)

### Common Commands

```bash
# Install dependencies
flutter pub get

# Generate code (freezed models, riverpod providers)
dart run build_runner build --delete-conflicting-outputs

# Watch for code generation (during development)
dart run build_runner watch --delete-conflicting-outputs

# Run with environment variables
flutter run \
  --dart-define=ENV=development \
  --dart-define=BASE_URL=https://dev-api.medimanage.com/v1 \
  --dart-define=API_KEY=your_key

# Run tests
flutter test

# Run a single test file
flutter test test/features/patients/...

# Analyze
flutter analyze

# Build release APK
flutter build apk --release \
  --dart-define=ENV=production \
  --dart-define=BASE_URL=https://api.medimanage.com/v1 \
  --dart-define=API_KEY=your_key
```

### Architecture: Clean Architecture + Feature-First

Every feature follows the same three-layer structure under `lib/features/<feature>/`:

```
<feature>/
├── domain/          # Pure Dart — no Flutter, no framework imports
│   ├── entities/    # Immutable business objects (Equatable)
│   ├── repositories/ # Abstract interfaces only
│   └── usecases/    # One class per use case, calls repository
├── data/            # Infrastructure — implements domain interfaces
│   ├── models/      # JSON/SQLite serialization; toEntity() converts to domain
│   ├── datasources/ # remote (Dio) and local (SQLite) — abstract + impl pairs
│   └── repositories/ # Implements domain repository; orchestrates remote+local
└── presentation/    # Flutter UI
    ├── providers/   # Riverpod: declares providers + Notifier/AsyncNotifier state
    ├── screens/     # Full pages, ConsumerWidget or ConsumerStatefulWidget
    └── widgets/     # Feature-specific reusable widgets
```

**Dependency rule:** domain ← data ← presentation. Domain never imports Flutter.

### Core Infrastructure (`lib/core/`)

| Path | Purpose |
|------|---------|
| `config/env_config.dart` | Compile-time env vars via `--dart-define`; `EnvConfig.baseUrl`, `.isDevelopment`, etc. |
| `config/app_config.dart` | App-wide constants: DB name, page size, API endpoint paths, SecureStorage keys |
| `error/exceptions.dart` | `AppException` hierarchy thrown by data layer |
| `error/failures.dart` | `Failure` hierarchy (Equatable) returned from repositories via `Either<Failure, T>` |
| `error/error_handler.dart` | `ErrorHandler.fromDioException()` → AppException; `ErrorHandler.toFailure()` → Failure |
| `usecases/use_case.dart` | `UseCase<Type, Params>` base with `NoParams` |
| `network/api_client.dart` | Typed Dio wrapper (get/post/put/patch/delete); `apiClientProvider` |
| `network/dio_factory.dart` | Builds Dio with correct interceptor order: Logging → Auth → Error |
| `network/interceptors/auth_interceptor.dart` | Injects Bearer token; silently refreshes on 401 using a secondary Dio instance |
| `database/database_helper.dart` | SQLite singleton with tables: `users`, `patients`, `appointments`, `medical_records` |
| `router/app_router.dart` | GoRouter: redirect on auth state change via `_AuthStateListenable` |
| `router/route_names.dart` | All route path constants |
| `theme/app_theme.dart` | Material 3 light + dark `ThemeData` |
| `theme/app_colors.dart` | Medical blue primary, health green secondary, all semantic colors |
| `theme/app_typography.dart` | Inter font `TextTheme` |
| `theme/app_dimensions.dart` | Spacing, border-radius, component-size constants |

### Reusable Widgets (`lib/core/widgets/`)

- `AppButton` — primary / secondary / outlined / text / danger variants with loading state
- `AppTextField` — with password toggle, validator, prefix/suffix icons
- `AppLoader` / `AppOverlayLoader` — centered spinner with optional message
- `AppErrorWidget` — maps `Failure` to icon + message + retry; network/auth/404 aware
- `AppScaffold` / `AppSliverScaffold` — pre-wired safe area + back button

### State Management Pattern (Riverpod 2.x)

Providers are declared in `presentation/providers/`. Infrastructure providers (`repository`, `datasource`) are `Provider<T>`. State uses `Notifier<State>` / `NotifierProvider` for sync-initiated async, and `FutureProvider.family` for single-item reads.

Sealed `AuthState` classes (`AuthInitial`, `AuthLoading`, `AuthAuthenticated`, `AuthUnauthenticated`, `AuthError`) drive GoRouter redirect via `_AuthStateListenable extends ChangeNotifier`.

### Error Handling Flow

```
DioException
  → ErrorInterceptor (wraps into AppException via ErrorHandler.fromDioException)
  → ApiClient rethrows AppException
  → Repository catches AppException, returns Left(ErrorHandler.toFailure(e))
  → UseCase returns Either<Failure, T>
  → Notifier folds Either → updates state
  → UI pattern-matches state to show AppErrorWidget or SnackBar
```

### Offline Strategy

Patient repository tries remote first; on network failure falls back to SQLite cache. Remote results are persisted asynchronously (`.ignore()`) after successful fetch.

### Code Generation

Models use manual `fromJson`/`toJson`/`fromSqlite`/`toSqlite`. The project is wired for `freezed` + `json_serializable` + `riverpod_generator` — run `build_runner` after adding `@freezed` or `@riverpod` annotations.

### Environment Configuration

All secrets are passed at build time via `--dart-define`. Never commit `.env` files. The `EnvConfig` class reads them with `String.fromEnvironment`.

---

## Repository Layout

```
medical-patient-management-system/
├── frontend/        # Flutter application (see above)
├── backend/         # Reserved for API server
├── database/        # Reserved for migrations / seed scripts
├── deployment/      # Reserved for Docker / CI-CD configs
└── docs/
    ├── architecture.md
    ├── schema.md
    └── roadmap.md
```

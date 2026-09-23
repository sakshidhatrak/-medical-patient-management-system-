# Medical Patient Management System
## High Level Design (HLD) & Low Level Design (LLD)

**Project:** MediManage — Medical Patient Management System
**Platform:** Flutter (iOS & Android)
**Backend:** Supabase (PostgreSQL + Storage)
**Document Date:** 21 September 2026
**Version:** 1.0

---

# PART A — HIGH LEVEL DESIGN (HLD)

---

## 1. System Overview

MediManage is an offline-first mobile application for clinical patient management. It allows medical staff to register patients, record visits, capture examinations, manage prescriptions, document surgeries, and generate PDF reports — with full functionality in disconnected environments and automatic sync when connectivity is restored.

---

## 2. System Context Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         EXTERNAL ACTORS                         │
│                                                                 │
│   Doctor / Admin / Staff / Nurse / Receptionist / Assistant     │
│              (Android Phone / iOS Phone / Tablet)               │
└───────────────────────────────┬─────────────────────────────────┘
                                │  Uses
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    MEDIMANAGE FLUTTER APP                       │
│          (iOS + Android — Dart / Flutter / Riverpod)            │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │  Auth Module │  │  Patient Mgmt│  │  Clinical Records    │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │  PDF / Print │  │  Photo Mgmt  │  │  Offline Sync Engine │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
└───────┬────────────────────────────────────────────────────┬────┘
        │  HTTPS / REST                                      │ SQLite
        ▼                                                    ▼
┌───────────────────────────┐              ┌────────────────────────┐
│       SUPABASE CLOUD      │              │  LOCAL SQLITE DATABASE  │
│                           │              │  (On-Device Storage)    │
│  ┌───────────────────┐    │              │  patients, visits,      │
│  │ Supabase Auth     │    │              │  surgeries, exams,      │
│  │ (JWT tokens)      │    │              │  prescriptions, photos, │
│  └───────────────────┘    │              │  sync_queue, audit_log  │
│  ┌───────────────────┐    │              └────────────────────────┘
│  │ PostgreSQL DB     │    │
│  │ (patient records) │    │
│  └───────────────────┘    │
│  ┌───────────────────┐    │
│  │ Supabase Storage  │    │
│  │ (photos, files)   │    │
│  └───────────────────┘    │
└───────────────────────────┘
```

---

## 3. High Level Architecture

### 3.1 Architecture Pattern

The application is built on **Clean Architecture** combined with a **Feature-First** directory layout. Each feature is an independent vertical slice containing its own domain, data, and presentation layers. Cross-feature dependencies flow only through the domain layer.

```
┌──────────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                            │
│        Flutter Screens  ──  Widgets  ──  Riverpod Providers      │
└─────────────────────────────┬────────────────────────────────────┘
                              │  calls
┌─────────────────────────────▼────────────────────────────────────┐
│                      DOMAIN LAYER                                │
│           Entities  ──  Use Cases  ──  Repository Contracts      │
└─────────────────────────────┬────────────────────────────────────┘
                              │  implements
┌─────────────────────────────▼────────────────────────────────────┐
│                       DATA LAYER                                 │
│  Repository Impl  ──  Remote DataSources  ──  Local DataSources  │
│       Supabase REST (Dio)          SQLite (sqflite)              │
└──────────────────────────────────────────────────────────────────┘
```

**Dependency Rule:** Presentation → Domain ← Data. Domain layer is pure Dart with no Flutter or infrastructure imports.

### 3.2 Feature Modules

| Feature Module | Responsibility |
|----------------|---------------|
| `auth` | Login, logout, token refresh, session management |
| `dashboard` | Patient list home screen, search, pagination |
| `patients` | Registration, detail view, edit, timeline, print |
| `visits` | OPD / Emergency / Follow-up visit wizard and view |
| `examinations` | Neurological examination structured entry |
| `prescriptions` | Drug prescription with autocomplete |
| `surgeries` | Surgical procedure documentation |
| `photos` | Categorised photo gallery and upload |
| `medicines` | Drug master data and autocomplete service |
| `print_configuration` | Template builder for PDF reports |
| `pdf` | PDF generation and export |
| `reports` | Report listing and history |
| `audit` | Audit log viewer |

### 3.3 Core Infrastructure Modules

| Module | Responsibility |
|--------|---------------|
| `core/router` | GoRouter navigation with auth-aware redirect and role guards |
| `core/network` | Dio-based API client with Auth, Logging, Error interceptors |
| `core/database` | SQLite singleton (`DatabaseHelper`) with foreign keys |
| `core/sync` | Offline queue, sync engine, local caches |
| `core/error` | Unified exception and failure hierarchy |
| `core/theme` | Material 3 design tokens (colours, typography, spacing) |
| `core/storage` | flutter_secure_storage wrapper for tokens |
| `core/offline` | Web offline store (SharedPreferences fallback) |

---

## 4. Technology Stack

| Category | Choice | Reason |
|----------|--------|--------|
| Framework | Flutter 3.x | Cross-platform iOS + Android from one codebase |
| Language | Dart 3.x | Null safety, strong typing, async/await |
| State Management | Riverpod 2.x | Compile-safe providers, testable, no BuildContext dependency |
| Navigation | GoRouter | Declarative, URL-based, supports deep links and auth redirect |
| Remote Backend | Supabase | Managed PostgreSQL + Auth + Storage; PostgREST API |
| HTTP Client | Dio | Interceptor chain (Auth → Logging → Error), typed responses |
| Local DB | sqflite (SQLite) | Relational local store; foreign keys; batch operations |
| Secure Storage | flutter_secure_storage | Keychain (iOS) / Keystore (Android) for tokens |
| PDF | pdf + printing | On-device PDF generation and system print dialog |
| Code Gen | build_runner + freezed + riverpod_generator | Reduces boilerplate for models and providers |

---

## 5. Deployment Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    DISTRIBUTION                              │
│                                                             │
│   iOS App Store          Google Play Store                  │
│       │                        │                           │
│       └──────────┬─────────────┘                           │
│                  │  Install                                 │
│                  ▼                                          │
│          End-User Device (iOS / Android)                    │
│          ┌──────────────────────────────┐                   │
│          │  MediManage Flutter App       │                   │
│          │  ┌────────────────────────┐  │                   │
│          │  │  SQLite (local data)   │  │                   │
│          │  └────────────────────────┘  │                   │
│          │  ┌────────────────────────┐  │                   │
│          │  │  Secure Storage (JWT)  │  │                   │
│          │  └────────────────────────┘  │                   │
│          └──────────────┬───────────────┘                   │
│                         │ HTTPS                             │
│                         ▼                                   │
│          ┌──────────────────────────────┐                   │
│          │     Supabase Cloud           │                   │
│          │  (Auth + PostgreSQL + S3)    │                   │
│          └──────────────────────────────┘                   │
└─────────────────────────────────────────────────────────────┘
```

**Build-time secrets** (API keys, base URLs) are injected via `--dart-define` and never committed to source control.

---

## 6. Data Architecture Overview

### 6.1 Offline-First Principle

Every write operation is persisted to SQLite first, then queued for upload. Reads try the remote source first and fall back to SQLite on network failure. This means the app works identically online and offline — the sync engine handles convergence silently in the background.

### 6.2 Data Stores

| Store | Technology | Purpose |
|-------|-----------|---------|
| Remote | Supabase PostgreSQL | Source of truth for all clinical data |
| Local (mobile) | SQLite via sqflite | Offline cache and write queue |
| Local (web) | SharedPreferences | Web fallback (limited) |
| Secure | flutter_secure_storage | Auth tokens |
| Cloud Files | Supabase Storage | Photos, uploaded medical documents |

### 6.3 Sync Strategy

```
Write:   User Action → SQLite (immediate) → sync_queue (queued)
                                         → SyncEngine (background)
                                           → Supabase REST (on connectivity)

Read:    Provider → Supabase (if online) → SQLite upsert
                  → SQLite (if offline / on error)
```

---

## 7. Security Architecture

| Concern | Implementation |
|---------|---------------|
| Authentication | Supabase Auth (email + password); JWT access + refresh tokens |
| Token storage | flutter_secure_storage (Keychain / Keystore) |
| Token refresh | Silent refresh in `AuthInterceptor` on HTTP 401; no user friction |
| Transport | HTTPS only; TLS 1.2+ |
| Authorisation | Role-based guards in GoRouter redirect; Row Level Security on Supabase |
| Secrets | Injected at build time via `--dart-define`; never in source code |
| Data at rest | SQLite on device; encrypted by OS on locked devices (iOS Secure Enclave, Android Keystore) |

---

## 8. Navigation Architecture (Route Map)

```
/  (Splash — auto-redirect)
├── /login
└── /dashboard  (ShellRoute — persistent sidebar)
    ├── /reports
    ├── /print-config
    ├── /appointments  (placeholder)
    ├── /messages      (placeholder)
    └── /patients
        ├── /patients/register
        └── /patients/:patientId
            ├── /patients/:patientId/edit
            ├── /patients/:patientId/new-visit
            └── /patients/:patientId/visits/:visitId
                ├── /patients/:patientId/visits/:visitId/examination
                └── /patients/:patientId/visits/:visitId/view
            └── /patients/:patientId/surgeries/:surgeryId
```

**Auth redirect:** Unauthenticated users attempting any protected route are redirected to `/login`. Authenticated users on `/login` are redirected to `/patients`.

**Role guards:** Read-only roles (doctor, nurse, receptionist, assistant) are redirected away from write routes (register, edit, new-visit, examination, surgery form). Staff can create visits but not surgeries or prescriptions.

---

---

# PART B — LOW LEVEL DESIGN (LLD)

---

## 9. Domain Layer — Entities

### 9.1 UserEntity

```
UserEntity
├── id: String
├── email: String
├── firstName: String
├── lastName: String
├── role: UserRole  [doctor | nurse | admin | staff | receptionist | assistant]
├── avatarUrl: String?
├── createdAt: DateTime
│
├── computed: fullName → "$firstName $lastName"
├── computed: isDoctor → role == doctor
├── computed: isAdmin  → role == admin
├── computed: canWrite → role == admin
└── computed: canEditPatient → role in [admin, staff]
```

### 9.2 PatientEntity

```
PatientEntity
├── id: String                   (UUID — client temp | numeric — server assigned)
├── prn: String                  (Patient Registration Number)
├── firstName: String (required)
├── lastName: String
├── age: int?
├── dateOfBirth: DateTime?
├── sex: String?
├── phone: String?
├── address: String?
├── altPhone: String?
├── email: String?
├── idProofType: String?
├── idProofNumber: String?
├── weight: String?
├── bloodPressure: String?
├── temperature: String?
├── allergies: String?
├── medicalHistory: String?
├── previousHistory: String?
├── notes: String?
├── isActive: bool
├── syncStatus: String           ('synced' | 'pending')
├── createdAt: DateTime
├── updatedAt: DateTime
├── createdBy: String?
└── updatedBy: String?

Computed:
├── fullName:    lastName.isEmpty ? firstName : "$firstName $lastName"
├── initials:    first char of first + last name
├── computedAge: from age field, or calculated from dateOfBirth
├── displayAge:  "42y"
└── ageSex:      "42y / M"
```

### 9.3 VisitEntity

```
VisitEntity
├── id: String
├── patientId: String
├── visitDate: DateTime
├── visitType: VisitType        [opd | emergency | followUp]
├── complaints: String?
├── examination: String?
├── clinicalImpression: String?
├── plan: String?
├── notes: String?
├── bp: String?
├── temperature: String?
├── weight: String?
├── status: String               ('draft' | 'completed')
├── syncStatus: String
├── isActive: bool
├── createdAt / updatedAt: DateTime
└── createdBy / updatedBy: String?

Computed:
├── isDraft: status == 'draft'
└── summary: complaints ?? clinicalImpression ?? 'OPD Visit'
```

### 9.4 ExaminationEntity

```
ExaminationEntity
├── id: String
├── visitId: String
├── patientId: String
│
├── Free text (primary, always available):
│   ├── generalText: String?
│   ├── motorText: String?
│   ├── sensoryText: String?
│   ├── reflexesText: String?
│   ├── cerebellarText: String?
│   └── specialTestsText: String?
│
└── Structured helpers:
    ├── motorData: List<MotorEntry>
    │   └── MotorEntry { joint, right (MRC grade), left (MRC grade), notes }
    ├── sensoryData: List<Map<String, dynamic>>
    └── reflexData: Map<String, dynamic>

MotorEntry.generatedText:
  Auto-produces sentence for any power below 5/5, e.g.:
  "Right Shoulder power 4/5, Left Knee power 3/5"
```

### 9.5 PrescriptionEntity

```
PrescriptionEntity
├── id: String
├── patientId: String
├── visitId: String?
├── text: String?                (free-text prescription)
└── drugs: List<DrugEntry>

DrugEntry
├── id: String
├── genericName: String
├── brandName: String?
├── composition: String?
├── dose: String?
├── frequency: String?
├── duration: String?
├── instructions: String?
└── taperingSteps: List<TaperingStep>
    └── TaperingStep { dose, duration, instructions? }

DrugMaster (catalogue)
├── id, genericName
├── brandNames: List<String>
├── composition, category
└── defaultDose, defaultFrequency, defaultDuration
```

### 9.6 SurgeryEntity

```
SurgeryEntity
├── id: String
├── patientId: String
├── surgeryDate: DateTime
├── yourRole: String?            (Primary / Assistant / Observer)
├── preOpDiagnosis: String?
├── procedure: String?
├── primarySurgeon: String?
├── assistantSurgeons: String?
├── anesthesiaType: String?
├── anesthesiologist: String?
├── implants: String?
├── intraopFindings: String?
├── otNotes: String?
├── complications: String?
├── postOpPlan: String?
├── status: String               ('draft' | 'completed')
└── syncStatus: String
```

### 9.7 PhotoEntity

```
PhotoEntity
├── id: String
├── patientId: String
├── visitId: String?
├── surgeryId: String?
├── storagePath: String          (Supabase Storage path)
├── url: String?                 (public URL)
├── originalFilename: String?
├── category: PhotoCategory      [visit | examination | radiology |
│                                 treatment | surgeryFindings |
│                                 surgeryOtNotes | patientReport]
├── caption: String?
├── isUploaded: bool
├── localPath: String?           (device path for offline photos)
├── fileSize: int?               (bytes)
└── createdAt: DateTime
```

---

## 10. Data Layer — Database Schema

### 10.1 SQLite Tables (Local)

#### Table: `patients`

| Column | Type | Constraints |
|--------|------|-------------|
| id | TEXT | PRIMARY KEY |
| prn | TEXT | NOT NULL |
| first_name | TEXT | NOT NULL |
| last_name | TEXT | NOT NULL |
| age | INTEGER | |
| date_of_birth | TEXT | |
| sex | TEXT | |
| phone | TEXT | |
| address | TEXT | |
| notes | TEXT | |
| data_json | TEXT | Full JSON snapshot |
| sync_status | TEXT | DEFAULT 'pending' |
| is_active | INTEGER | DEFAULT 1 |
| created_at | TEXT | NOT NULL |
| updated_at | TEXT | NOT NULL |
| created_by | TEXT | |
| updated_by | TEXT | |

Index: `idx_patients_name` on `(last_name, first_name)`

#### Table: `visits`

| Column | Type | Constraints |
|--------|------|-------------|
| id | TEXT | PRIMARY KEY |
| patient_id | TEXT | FK → patients.id |
| visit_date | TEXT | NOT NULL |
| visit_type | TEXT | DEFAULT 'opd' |
| complaints | TEXT | |
| examination | TEXT | |
| clinical_impression | TEXT | |
| plan | TEXT | |
| notes | TEXT | |
| status | TEXT | DEFAULT 'draft' |
| data_json | TEXT | Full JSON snapshot |
| sync_status | TEXT | DEFAULT 'pending' |
| is_active | INTEGER | DEFAULT 1 |
| created_at / updated_at | TEXT | |
| created_by / updated_by | TEXT | |

#### Table: `surgeries`

| Column | Type | Constraints |
|--------|------|-------------|
| id | TEXT | PRIMARY KEY |
| patient_id | TEXT | FK → patients.id |
| surgery_date | TEXT | NOT NULL |
| your_role | TEXT | |
| pre_op_diagnosis | TEXT | |
| procedure | TEXT | |
| primary_surgeon | TEXT | |
| assistant_surgeons | TEXT | |
| anesthesia_type | TEXT | |
| anesthesiologist | TEXT | |
| implants | TEXT | |
| intraop_findings | TEXT | |
| ot_notes | TEXT | |
| complications | TEXT | |
| post_op_plan | TEXT | |
| status | TEXT | DEFAULT 'draft' |
| data_json | TEXT | |
| sync_status | TEXT | DEFAULT 'pending' |
| is_active | INTEGER | DEFAULT 1 |

#### Table: `examinations`

| Column | Type | Constraints |
|--------|------|-------------|
| visit_id | TEXT | PRIMARY KEY, FK → visits.id |
| patient_id | TEXT | FK → patients.id |
| data_json | TEXT | Full examination JSON |
| sync_status | TEXT | DEFAULT 'synced' |
| updated_at | TEXT | |

#### Table: `prescriptions`

| Column | Type | Constraints |
|--------|------|-------------|
| visit_id | TEXT | PRIMARY KEY, FK → visits.id |
| patient_id | TEXT | FK → patients.id |
| data_json | TEXT | Full prescription JSON |
| sync_status | TEXT | DEFAULT 'synced' |
| updated_at | TEXT | |

#### Table: `photos`

| Column | Type | Constraints |
|--------|------|-------------|
| id | TEXT | PRIMARY KEY |
| patient_id | TEXT | FK → patients.id |
| visit_id | TEXT | |
| surgery_id | TEXT | |
| storage_path | TEXT | |
| url | TEXT | |
| local_path | TEXT | Device path (offline) |
| category | TEXT | |
| caption | TEXT | |
| is_uploaded | INTEGER | DEFAULT 0 |
| file_size | INTEGER | |
| created_at | TEXT | |

#### Table: `sync_queue`

| Column | Type | Constraints |
|--------|------|-------------|
| id | TEXT | PRIMARY KEY (UUIDv4) |
| entity_type | TEXT | 'patients' \| 'visits' \| 'surgeries' \| etc. |
| entity_id | TEXT | |
| operation | TEXT | 'insert' \| 'update' \| 'patch' \| 'delete' |
| payload | TEXT | JSON-encoded payload |
| queued_at | TEXT | ISO8601 timestamp |
| attempts | INTEGER | DEFAULT 0 |
| last_error | TEXT | Last failure message |

#### Table: `drugs_cache`

| Column | Type | Constraints |
|--------|------|-------------|
| id | TEXT | PRIMARY KEY |
| data_json | TEXT | |
| cached_at | TEXT | |

#### Table: `patient_id_map`

| Column | Type | Constraints |
|--------|------|-------------|
| client_id | TEXT | PRIMARY KEY (offline UUID) |
| server_id | TEXT | Server-assigned numeric ID |

#### Table: `audit_log`

| Column | Type | Constraints |
|--------|------|-------------|
| id | TEXT | PRIMARY KEY |
| entity_type | TEXT | |
| entity_id | TEXT | |
| field_name | TEXT | |
| old_value | TEXT | |
| new_value | TEXT | |
| changed_at | TEXT | |
| changed_by | TEXT | |

#### Table: `patient_details` (legacy)

| Column | Type | Notes |
|--------|------|-------|
| patient_id | TEXT | PRIMARY KEY |
| visits_json | TEXT | DEFAULT '[]' |
| vitals_json | TEXT | |
| emergency_contact_json | TEXT | |
| reports_json | TEXT | DEFAULT '[]' |

### 10.2 Schema Version History

| Version | Migration |
|---------|-----------|
| 1 | Base tables: users, patients, appointments, medical_records |
| 2 | Added `patient_details` table |
| 3 | Added `sync_status` column to patients; added `sync_queue` table |

---

## 11. Network Layer — API Client Design

### 11.1 Interceptor Chain

```
Dio Instance
    │
    ├─ LoggingInterceptor    — logs request/response in debug builds
    ├─ AuthInterceptor       — injects "Authorization: Bearer <token>"
    │                          on 401 → refreshes token silently
    └─ ErrorInterceptor      — maps DioException → AppException
```

### 11.2 ApiClient Methods

```dart
ApiClient
├── get<T>(path, {queryParameters, options, fromJson})
├── post<T>(path, {data, queryParameters, options, fromJson})
├── put<T>(path, {data, ...})
├── patch<T>(path, {data, ...})
└── delete<T>(path, {data, ...})

All methods:
  → call _request()
  → on DioException: re-throw as AppException via ErrorHandler.fromDioException()
```

### 11.3 API Endpoint Paths (SyncEngine Path Builder)

| Entity | Insert Path | Update Path |
|--------|------------|-------------|
| Patient | `POST /patients` | `PUT /patients/:id` |
| Visit | `POST /patients/:patientId/visits` | `PUT /patients/:patientId/visits/:id` |
| Surgery | `POST /patients/:patientId/surgeries` | `PUT /patients/:patientId/surgeries/:id` |
| Examination | `PUT /patients/:patientId/visits/:visitId/examination` | Same path |
| Prescription | `POST /patients/:patientId/visits/:visitId/prescriptions` | `PUT /prescriptions/:id` |

### 11.4 Error Hierarchy

```
AppException
├── NetworkException       — connection/timeout failures
├── AuthException          — 401 Unauthorized
├── ForbiddenException     — 403 Forbidden
├── NotFoundException      — 404 Not Found
├── ServerException        — 5xx errors
└── ValidationException    — 422 Unprocessable Entity

Failure (Equatable — returned via Either<Failure, T>)
├── NetworkFailure
├── AuthFailure
├── ServerFailure
├── CacheFailure
└── ValidationFailure
```

---

## 12. State Management — Riverpod Providers

### 12.1 Auth State Machine

```
AuthState (sealed)
├── AuthInitial          — app just started; reading token from storage
├── AuthLoading          — login request in flight
├── AuthAuthenticated    — user logged in; carries UserEntity
├── AuthUnauthenticated  — logged out or token expired
└── AuthError            — login failed; carries error message

AuthNotifier (Notifier<AuthState>)
├── login(email, password) → LoginUseCase → sets Authenticated | Error
└── logout()              → LogoutUseCase → sets Unauthenticated

_AuthListenable (ChangeNotifier)
└── listens to authProvider → notifyListeners() on state type change
    → triggers GoRouter.redirect()
```

### 12.2 Patient Providers

```
PatientsState
├── patients: List<PatientEntity>
├── isLoading: bool
├── error: String?
├── search: String?
└── hasMore: bool

PatientsNotifier (Notifier<PatientsState>)
├── build()      → loads first page from Supabase | SQLite fallback
├── search(q)    → filters patients by name/PRN/phone
├── loadMore()   → appends next page (infinite scroll)
└── refresh()    → full re-fetch

patientSyncEventProvider (StateProvider<int>)
└── incremented by SyncEngine on patient sync → triggers patientsProvider rebuild
```

### 12.3 Visit Provider

```
VisitState
├── visits: List<VisitEntity>
├── isLoading: bool
└── error: String?

VisitsNotifier
├── loadForPatient(patientId)
├── addVisit(visitEntity)      → SQLite insert → sync_queue enqueue
└── updateVisit(visitEntity)   → SQLite update → sync_queue enqueue

visitSyncEventProvider (StateProvider<int>)
└── incremented by SyncEngine on visit sync → triggers visitsNotifier reload
```

### 12.4 Surgery Provider

```
SurgeryNotifier
├── loadForPatient(patientId)  → Supabase → LocalSurgeryCache fallback
├── saveSurgery(entity)        → SQLite upsert → sync_queue enqueue
└── deleteSurgery(id)          → soft-delete in SQLite + queue

surgerySyncEventProvider → triggers reload after SyncEngine push
```

### 12.5 Sync Engine Providers

```
syncCoordinatorProvider (NotifierProvider)
└── On build:  if online → syncAll()
└── On connectivity restore (offline→online): syncAll()

syncEngineProvider (Provider<SyncEngine>)
└── Depends on: offlineQueueProvider, apiClientProvider,
    localVisitCacheProvider, localSurgeryCacheProvider,
    localPhotoStoreProvider, localPrescriptionCacheProvider,
    patientIdMapProvider

syncSuccessProvider (StateProvider<{count, at}?>)
└── Updated after syncAll() completes with count > 0
    → UI shows "X records synced" toast
```

---

## 13. Sync Engine — Detailed Design

### 13.1 SyncItem

```
SyncItem
├── id: String (UUID)
├── entityType: String
├── entityId: String
├── operation: String    ('insert' | 'update' | 'patch' | 'delete')
├── payload: Map<String, dynamic>
├── queuedAt: String
├── attempts: int
└── lastError: String?
```

### 13.2 syncAll() Flow

```
syncAll()
│
├── resetAllFailed()          ← resets attempt counter; avoids abandoned items
├── items ← queue.pending()  ← ordered by queued_at ASC
│
├── for each item:
│   ├── _resolveUuidPatientId(payload)
│   │   └── if patientId is UUID → look up patient_id_map → substitute numeric ID
│   │
│   ├── _buildPath(item, payload) → REST endpoint path
│   │
│   ├── switch(operation):
│   │   ├── insert patients → POST → get server ID
│   │   │   ├── idMap.insert(clientUUID, serverId)
│   │   │   ├── localVisit/Surgery/Photo/Prescription.remapPatientId()
│   │   │   ├── queue.remapPatientIdInQueue()
│   │   │   └── remapped = true → reload queue (i = 0)
│   │   │
│   │   ├── insert visits → POST → get server visit ID
│   │   │   ├── localVisit.remapVisitId(oldId, newId)
│   │   │   │   ├── UPDATE prescriptions SET visit_id = newId
│   │   │   │   ├── UPDATE examinations  SET visit_id = newId
│   │   │   │   └── UPDATE photos        SET visit_id = newId
│   │   │   └── localVisit.upsert(serverData)
│   │   │
│   │   ├── update → PUT
│   │   ├── patch  → PATCH
│   │   └── delete → DELETE
│   │
│   ├── queue.markDone(item.id)
│   └── on error:
│       ├── NotFoundException → markDone() (no retry)
│       └── other → incrementAttempt()
│
├── resetAllFailed() (second pass — cleanup)
│
├── if pending items remain → schedule retry in 60s
│
└── if syncedCount > 0 → syncAuditLogsFromApi() + update syncSuccessProvider
```

### 13.3 Patient ID Remapping

Offline patients receive a temporary client UUID (`generatePrn()`). When synced, the server assigns a numeric ID. All related entities (visits, surgeries, photos, prescriptions) stored locally with the UUID must be updated to use the numeric server ID. The `patient_id_map` table persists this mapping to handle cases where sync completes in different sessions.

---

## 14. Error Handling Flow

```
User Action (e.g., save visit)
│
▼
Riverpod Notifier calls UseCase
│
▼
Repository Implementation:
  try:
    Remote DataSource → Dio → API call
    on success: return Right(entity)
  catch DioException:
    → ErrorHandler.fromDioException(e) → AppException
    → ErrorHandler.toFailure(e)        → Failure
    → return Left(Failure)
  catch SQLiteException:
    → return Left(CacheFailure(...))
│
▼
Notifier folds Either:
  Right → update state with data
  Left  → update state with error message
│
▼
UI pattern-matches state:
  loading → CircularProgressIndicator
  error   → AppErrorWidget (maps Failure type to icon + message + retry)
  data    → render content
```

---

## 15. PDF Generation — Low Level Design

### 15.1 PDF Service Flow

```
PrintConfigScreen (user toggles fields / selects template)
│
▼
PrintTemplate (Set<String> enabledFieldIds)
│
▼
PdfExportService.generateReport(patient, visit, template)
│
├── Build clinic header (name, logo, contact)
├── Build patient section (from PatientEntity, filter by enabledFieldIds)
├── Build vitals section
├── Build clinical section (visit data, examination data)
├── Build prescription table (from PrescriptionEntity.drugs)
│   └── Columns: Drug Name | Dose | Frequency | Duration | Instructions
│   └── Tapering steps rendered as sub-rows
├── Build uploaded files section (thumbnails of attached images)
│
└── Return pw.Document → Uint8List (bytes)
│
▼
PdfActionBar
├── Print   → Printing.layoutPdf(doc)  → System print dialog
├── Share   → Share.shareXFiles([pdfFile])
└── Save    → getDownloadsDirectory() → File.writeAsBytes(bytes)
```

### 15.2 Report Template Model

```
PrintTemplate
├── id: String
├── name: String
├── enabledFieldIds: Set<String>   (controls which fields appear)
├── sectionOrder: List<String>     (section rendering sequence)
└── isBuiltIn: bool

Built-in templates: tpl_full, tpl_opd, tpl_emergency, tpl_doctor
Custom templates: saved to SharedPreferences / SQLite by user
```

### 15.3 PrintField Model

```
PrintField
├── id: String          (matches enabledFieldIds key)
├── label: String       (display label in config panel and report)
├── section: String     (section group for ordering)
└── getValue: Function  (PatientEntity | VisitEntity → String?)
```

---

## 16. Authentication — Detailed Flow

### 16.1 Login Sequence

```
User taps "Sign In"
│
▼
LoginForm validates (email format, min password length)
│
▼
AuthNotifier.login(email, password)
  → state = AuthLoading
  │
  ▼
  LoginUseCase.call(LoginParams)
    → AuthRepository.login(email, password)
      → AuthRemoteDataSource.login()
        → Supabase.auth.signInWithPassword()
        ← {accessToken, refreshToken, user}
      → StorageService.saveTokens(access, refresh)
      → UserEntity.fromSupabaseUser(user)
    ← UserEntity
  ← UserEntity
│
▼
AuthNotifier: state = AuthAuthenticated(user: UserEntity)
│
▼
_AuthListenable.notifyListeners()
  → GoRouter.redirect() → '/patients'
```

### 16.2 Token Refresh Sequence

```
ApiClient makes request
  → AuthInterceptor injects "Authorization: Bearer <token>"
│
▼
Server returns 401
│
▼
AuthInterceptor.onError():
  → StorageService.getRefreshToken()
  → Secondary Dio (no interceptors) → POST /auth/refresh
  ← {newAccessToken}
  → StorageService.saveAccessToken(newAccessToken)
  → Retry original request with new token
```

---

## 17. Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Local DB schema | Flat columns + `data_json` TEXT column | Flat columns allow indexed SQLite queries; JSON blob preserves full server payload for fidelity |
| ID strategy | UUID locally → numeric server ID after sync | Allows offline creation; `patient_id_map` bridges the identity gap |
| Sync order | Patients first, then visits/surgeries | Avoids FK violations; server requires parent before children |
| Visit ID remapping | `remapVisitId` cascades to prescriptions, exams, photos | Keeps related records consistent after server assigns new ID |
| Orphaned visit repair | 24-hour timestamp proximity heuristic | Covers edge case where patient sync and visit creation were in different sessions before `patient_id_map` table existed |
| Web support | WebOfflineStore (SharedPreferences) | SQLite unavailable on Flutter Web; SharedPreferences provides limited parity |
| PDF generation | On-device (pdf package) | No server round-trip; works offline; no patient data sent to third-party rendering service |
| Template persistence | SharedPreferences | Templates are user preferences, not clinical data; no sync needed |

---

*End of HLD & LLD Document*

*Prepared by the MediManage Development Team — September 2026*

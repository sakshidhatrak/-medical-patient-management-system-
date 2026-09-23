# Medical Patient Management System
## Functional Requirements Document

**Project:** Medical Patient Management System (MediManage)
**Platform:** Flutter (Mobile — iOS & Android)
**Backend:** Supabase (PostgreSQL + Storage)
**Document Date:** 21 September 2026
**Version:** 1.0

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [System Overview](#2-system-overview)
3. [User Roles & Access Control](#3-user-roles--access-control)
4. [Authentication Module](#4-authentication-module)
5. [Dashboard & Patient Search](#5-dashboard--patient-search)
6. [Patient Registration & Management](#6-patient-registration--management)
7. [Visit Management](#7-visit-management)
8. [Clinical Examination Module](#8-clinical-examination-module)
9. [Prescription Management](#9-prescription-management)
10. [Surgery Records](#10-surgery-records)
11. [Photo & Media Management](#11-photo--media-management)
12. [Reports & Print Configuration](#12-reports--print-configuration)
13. [PDF Export & Printing](#13-pdf-export--printing)
14. [Offline Sync Engine](#14-offline-sync-engine)
15. [Audit Trail](#15-audit-trail)
16. [Non-Functional Requirements](#16-non-functional-requirements)

---

## 1. Introduction

The Medical Patient Management System (MediManage) is a mobile-first application designed for clinical environments. It enables doctors, assistants, staff, and administrators to register patients, record clinical visits, capture examinations, manage prescriptions and surgeries, and generate configurable printed reports — all with offline-first reliability backed by real-time cloud sync.

### 1.1 Purpose

This document describes the functional requirements for the Flutter frontend of the MediManage system. It serves as a reference for development, testing, and stakeholder review.

### 1.2 Scope

- Role-based access control with six user roles
- Patient registration, search, and lifecycle management
- Clinical visit recording (OPD, Emergency, Follow-up)
- Neurological examination structured capture
- Drug prescription with medicine autocomplete
- Surgical procedure documentation
- Photo gallery with medical categories
- Configurable PDF report generation and printing
- Offline operation with background cloud synchronisation

---

## 2. System Overview

### 2.1 Architecture

The application follows Clean Architecture with a Feature-First directory structure. Each feature module contains three layers:

| Layer | Responsibility |
|-------|---------------|
| **Domain** | Pure business logic — entities, repository contracts, use cases |
| **Data** | Remote (Supabase) and local (SQLite) data sources; repository implementations |
| **Presentation** | Flutter UI — screens, widgets, and Riverpod state providers |

### 2.2 Technology Stack

| Component | Technology |
|-----------|-----------|
| Frontend | Flutter (Dart) |
| State Management | Riverpod 2.x (Notifier / AsyncNotifier) |
| Navigation | GoRouter with auth-aware redirect |
| Remote Backend | Supabase (PostgreSQL + Supabase Storage) |
| Local Database | SQLite (via sqflite) |
| Network | Dio with Auth + Logging + Error interceptors |
| PDF Generation | pdf / printing packages |
| Secure Storage | flutter_secure_storage |

### 2.3 Data Flow

```
User Action
  → Riverpod Notifier
    → Use Case
      → Repository Implementation
        ├─ Remote: Supabase REST / Storage
        └─ Local: SQLite fallback
          → Returns Either<Failure, Result>
            → UI updates via state pattern-match
```

---

## 3. User Roles & Access Control

The system defines six user roles with differentiated permissions.

| Role | Display Name | Capabilities |
|------|-------------|--------------|
| `doctor` | Doctor | Read-only access to patient data and clinical records |
| `nurse` | Nurse | Read-only access to patient data |
| `admin` | Admin | Full write access: visits, surgeries, prescriptions, photos, patient data |
| `staff` | Staff | Create/update patient personal information; create visits |
| `receptionist` | Receptionist | Read-only access |
| `assistant` | Assistant | Read-only access |

### 3.1 Permission Matrix

| Action | Admin | Staff | Doctor | Nurse | Receptionist | Assistant |
|--------|:-----:|:-----:|:------:|:-----:|:------------:|:---------:|
| Register new patient | Yes | Yes | No | No | No | No |
| Edit patient personal info | Yes | Yes | No | No | No | No |
| Create/update visits | Yes | Yes | No | No | No | No |
| Create prescriptions | Yes | No | No | No | No | No |
| Create surgery records | Yes | No | No | No | No | No |
| Upload photos | Yes | No | No | No | No | No |
| View patient list | Yes | Yes | Yes | Yes | Yes | Yes |
| View patient details | Yes | Yes | Yes | Yes | Yes | Yes |
| Generate PDF reports | Yes | Yes | Yes | Yes | Yes | Yes |
| Configure print templates | Yes | Yes | Yes | Yes | Yes | Yes |

---

## 4. Authentication Module

### 4.1 Screens

**Splash Screen**
- Displays application branding during initialisation.
- Reads persisted auth token from secure storage.
- Automatically redirects to Dashboard if valid session exists; otherwise redirects to Login.

**Login Screen**
- Accepts email address and password.
- Inline validation: email format check, minimum password length.
- Displays loading state during authentication.
- Shows contextual error messages (invalid credentials, network failure, session expired).
- On success: stores access token and refresh token in flutter_secure_storage; navigates to Dashboard.

### 4.2 Authentication Flow

1. User submits credentials via `LoginForm`.
2. `AuthNotifier` calls `LoginUseCase`.
3. `AuthRepository` calls `AuthRemoteDataSource.login()` (Supabase Auth).
4. On success, tokens are persisted locally; `UserEntity` (id, email, name, role) is loaded.
5. GoRouter `_AuthStateListenable` fires a redirect to `/dashboard`.
6. On token expiry, `AuthInterceptor` silently refreshes using a secondary Dio instance.

### 4.3 Logout

- Available from the Dashboard header (logout icon button).
- Clears stored tokens from secure storage.
- Sets auth state to `AuthUnauthenticated`.
- GoRouter redirects to Login screen.

---

## 5. Dashboard & Patient Search

### 5.1 Overview

The Dashboard is the application's home screen. It displays the authenticated user's identity (name, role, initials avatar), a real-time patient count, a global search bar, and a paginated list of all patients.

### 5.2 Patient List

- Patients are displayed as cards showing: full name, age/sex summary, Patient Registration Number (PRN), and relative time since registration.
- Avatar colour is deterministically assigned from the patient ID.
- Infinite scroll: additional pages load automatically as the user scrolls near the bottom.
- Pull-to-refresh: triggers a full re-fetch from the remote source.

### 5.3 Search

- Real-time search by patient name, PRN (patient ID), or phone number.
- Search query is debounced and forwarded to the Supabase query via `patientsProvider.notifier.search()`.
- Empty search results show a contextual empty state illustration.

### 5.4 New Patient FAB

- A floating action button labelled "New Patient" navigates to the Patient Registration screen.
- Visible to Admin and Staff roles only.

### 5.5 Error States

| Condition | Message Shown |
|-----------|-------------|
| Network timeout | "Connection timed out. Check your network." |
| Session expired (JWT error) | "Session expired. Please log in again." |
| Generic error | "An error occurred loading patient data." |
| Retry available | "Try Again" button triggers a full refresh |

---

## 6. Patient Registration & Management

### 6.1 Patient Registration

The registration form captures comprehensive patient data across multiple sections.

**Basic Information**
- First Name (required), Last Name
- Age (numeric) or Date of Birth (date picker — age computed automatically)
- Sex (Male / Female / Other — dropdown)
- Phone number (primary), Alternate phone
- Email address
- Residential address

**Identity Proof**
- ID Proof Type (Aadhaar / PAN / Passport / Driving Licence / Voter ID / Other)
- ID Proof Number

**Baseline Vitals (at Registration)**
- Weight (kg)
- Blood Pressure (mmHg)
- Temperature (°F / °C)

**Medical History**
- Known allergies (free text)
- Medical history (free text)
- Previous treatment history (free text)

**Emergency Contact**
- Emergency contact name, relationship, phone number

**Admin Notes**
- Internal notes visible to staff/admin only

### 6.2 Patient Registration Number (PRN)

- Each patient receives a unique PRN.
- Online: server-assigned UUID-based identifier.
- Offline: temporary PRN generated in format `DDMMYYYYHHmmss` (IST timezone); replaced by server-assigned PRN upon sync.

### 6.3 Patient Detail Screen

Displays a complete patient profile with tabbed sections:
- **Overview** — demographics, contact, vitals, medical history
- **Visits** — chronological list of all clinical visits
- **Surgeries** — list of surgical procedures
- **Prescriptions** — prescription history
- **Photos** — categorised photo gallery
- **Timeline** — unified chronological view of all clinical events

### 6.4 Patient Edit Screen

- Pre-populated form matching the registration form.
- Available only to Admin and Staff roles.
- Changes sync to Supabase immediately; local SQLite updated on success.

### 6.5 Patient Timeline Screen

- Unified chronological list of visits, surgeries, and examinations.
- Each event is a tappable card navigating to the relevant detail screen.

---

## 7. Visit Management

### 7.1 Visit Types

| Type | Value | Description |
|------|-------|-------------|
| OPD | `OPD` | Out-patient department consultation |
| Emergency | `EMERGENCY` | Emergency presentation |
| Follow-up | `FOLLOW_UP` | Scheduled follow-up visit |

### 7.2 Visit Wizard (Add Visit)

A multi-step wizard guides the user through visit creation:

**Step 1 — Visit Details**
- Visit date (date-time picker; defaults to current date/time)
- Visit type (OPD / Emergency / Follow-up)

**Step 2 — Chief Complaints**
- Free-text chief complaints entry
- Quick symptom chips: pre-defined common symptoms selectable with a tap

**Step 3 — Vitals**
- Blood pressure, temperature, weight (per-visit measurements, separate from registration baseline)

**Step 4 — Clinical Notes**
- Examination findings (free text)
- Clinical impression / provisional diagnosis
- Treatment plan
- Additional notes

### 7.3 Visit View Screen

- Read-only view of a completed visit.
- Displays all recorded fields with section headers.
- Navigation links to linked prescription and examination records.
- Photo gallery filtered to the visit's attached photos.

### 7.4 Visit Status

| Status | Meaning |
|--------|---------|
| `draft` | Saved but not finalised |
| `completed` | Finalised visit record |

### 7.5 Visit Form Screen

- Direct edit form for modifying an existing visit.
- All fields pre-populated from the stored `VisitEntity`.
- Saving updates the record in Supabase and local SQLite.

---

## 8. Clinical Examination Module

### 8.1 Overview

The examination module provides structured and free-text capture of neurological examinations, linked to a specific visit.

### 8.2 Examination Sections

| Section | Input Type |
|---------|-----------|
| General Examination | Free text |
| Motor Examination | Structured (per-joint right/left grading) + free text |
| Sensory Examination | Structured data + free text |
| Reflexes | Structured (reflex map) + free text |
| Cerebellar Examination | Free text |
| Special Tests | Free text |

### 8.3 Motor Examination — Structured Entry

- Per-joint entries: Shoulder, Elbow, Wrist, Hip, Knee, Ankle (bilateral — right and left).
- Power graded on MRC scale (0/5 through 5/5).
- Auto-generates summary text: e.g., "Right Shoulder power 4/5, Left Knee power 3/5" — only abnormal values (below 5/5) are included.

### 8.4 Free Text Priority

All structured data has a corresponding free-text field. Free-text always takes precedence for report generation; structured helpers assist clinicians in composing the text efficiently.

---

## 9. Prescription Management

### 9.1 Overview

Prescriptions are linked to a patient and optionally to a specific visit. Each prescription contains a free-text field for general instructions and a structured drug list.

### 9.2 Drug Entry Fields

Each drug entry captures:

| Field | Description |
|-------|-------------|
| Generic Name | Required — the INN/generic drug name |
| Brand Name | Optional — preferred brand |
| Composition | Optional — active ingredients and strengths |
| Dose | e.g., "500 mg", "10 mg" |
| Frequency | e.g., "BD", "TDS", "OD at night" |
| Duration | e.g., "5 days", "2 weeks" |
| Special Instructions | e.g., "Take with food", "Avoid sunlight" |
| Tapering Steps | Ordered list of dose/duration steps for steroid tapers |

### 9.3 Medicine Autocomplete

- Drug name field uses an autocomplete widget backed by a local medicine master list (`medicine_master.dart`).
- Suggestions filtered as the user types (generic name or brand name).
- On selection, default dose, frequency, and duration are auto-populated from the master record.

### 9.4 Tapering Schedule

- Multiple tapering steps can be added to a single drug entry.
- Each step specifies a dose, duration, and optional instruction.
- Steps are displayed in sequence on printed prescriptions.

---

## 10. Surgery Records

### 10.1 Overview

Surgery records document operative procedures and are linked to a patient. A surgery record is created independently of a visit.

### 10.2 Surgery Form Fields

| Field | Description |
|-------|-------------|
| Surgery Date | Date-time of the procedure |
| Your Role | Primary Surgeon / Assistant / Observer |
| Pre-operative Diagnosis | Clinical diagnosis before surgery |
| Procedure | Name / description of the surgical procedure |
| Primary Surgeon | Name of the lead surgeon |
| Assistant Surgeons | Names of assistant surgeons |
| Anaesthesia Type | General / Spinal / Local / Epidural |
| Anaesthesiologist | Name of the anaesthesiologist |
| Implants Used | Implant names, sizes, lot numbers |
| Intra-operative Findings | Findings observed during surgery |
| OT Notes | Operating theatre notes |
| Complications | Any intra- or post-operative complications |
| Post-operative Plan | Follow-up instructions and care plan |

### 10.3 Surgery Status

| Status | Meaning |
|--------|---------|
| `draft` | Record saved but not finalised |
| `completed` | Finalised surgical record |

---

## 11. Photo & Media Management

### 11.1 Overview

Each patient has a photo gallery. Photos are categorised by medical context and may be linked to a visit or surgery record.

### 11.2 Photo Categories

| Category | Label | Use Case |
|----------|-------|----------|
| `visit` | Visit | General visit photos |
| `examination` | Examination | Examination findings photos |
| `radiology` | Radiology | X-rays, MRI, CT scans |
| `treatment` | Treatment | Treatment-related photos |
| `surgery_findings` | Surgical Findings | Intra-operative photos |
| `surgery_ot_notes` | OT Notes | Operative theatre documentation |
| `patient_report` | Patient Report | External reports, referral letters |

### 11.3 Photo Upload

- User selects a photo from the device camera or photo library.
- Category is selected before upload.
- An optional caption can be added.
- Photos are uploaded to Supabase Storage; the storage path and public URL are saved in the database.
- For offline uploads, the local file path is stored and the photo is queued for upload on next sync.

### 11.4 Photo Gallery Widget

- Grid layout displaying thumbnails.
- Tap to view full-screen with caption and metadata.
- Filterable by photo category.

---

## 12. Reports & Print Configuration

### 12.1 Overview

The print configuration module allows users to build custom report templates that control which patient data fields appear in generated PDF reports.

### 12.2 Built-in Templates

| Template ID | Name | Fields Included |
|-------------|------|----------------|
| `tpl_full` | Full Patient Report | All available fields |
| `tpl_opd` | OPD Summary | Name, age, gender, phone, vitals, chief complaint, diagnosis, medications |
| `tpl_emergency` | Emergency Summary | Name, age, gender, phone, vitals, chief complaint, diagnosis |
| `tpl_doctor` | Doctor Summary | Name, age, vitals, allergies, complaint, history, examination, diagnosis, treatment plan, medications, advice |

### 12.3 Custom Template Builder

**Left Panel — Field Toggles**
- All available fields are listed, grouped by section.
- Each field has a toggle switch (enable/disable).
- Enabled fields appear in the report preview.

**Right Panel — Live Preview**
- Shows a real-time preview of the report using current patient data.
- Updates immediately as fields are toggled.

**Template Management**
- Save current field selection as a named custom template.
- Delete custom templates (built-in templates cannot be deleted).
- Switch between templates via a dropdown.

### 12.4 Available Report Fields

**Basic Information:** First Name, Last Name, Age, Gender, Phone, Alternate Phone, Email, Address, ID Proof Type, ID Proof Number, Allergies, Medical History

**Vitals:** Weight, Blood Pressure, Temperature

**Clinical:** Previous History, Chief Complaint, General Examination, Neurological Examination, Clinical Diagnosis, Imaging Results, Other Investigations, Final Diagnosis, Treatment Plan, Medications, Notes, Advice, Investigation To Be Done, Cross Consultation

### 12.5 Report Section Ordering

Sections can be reordered within the template using a drag-and-drop interface. The default section order is: Patient Information → Vitals → Clinical History → Examination → Diagnosis & Plan → Prescriptions.

---

## 13. PDF Export & Printing

### 13.1 PDF Generation

- PDFs are generated on-device using the `pdf` package.
- Clinic header (name, logo, contact) is configurable.
- Patient details are pulled from the current patient record.
- Visit data from the selected visit populates clinical sections.
- Drug entries from the linked prescription are rendered as a formatted table.

### 13.2 PDF Action Bar

Appears below the report preview with the following actions:

| Action | Description |
|--------|-------------|
| Print | Sends PDF to the system print dialog |
| Share | Opens the OS share sheet with the PDF attached |
| Download | Saves the PDF to the device's Downloads folder |
| Zoom In / Out | Adjusts the preview scale |

### 13.3 Staff Report Preview Screen

- A simplified view accessible to staff users.
- Displays a read-only formatted report.
- Provides Share and Print options.
- Does not expose template editing.

### 13.4 Uploaded Medical Files

Users can upload external documents (referral letters, lab reports) and attach them to a patient record. Supported formats: PDF, JPEG, PNG. Files are stored in Supabase Storage and listed under the patient's document section.

---

## 14. Offline Sync Engine

### 14.1 Offline-First Strategy

The application operates fully offline. All data is stored locally in SQLite and synced to Supabase when connectivity is available.

### 14.2 Sync Queue

- Any create or update operation performed offline is added to a `sync_queue` table in SQLite.
- Each queue entry stores: entity type, entity ID, operation type (insert / update / delete), payload JSON, and retry count.

### 14.3 Sync Engine Behaviour

| Event | Action |
|-------|--------|
| App foreground (connectivity restored) | Sync engine processes the queue |
| Network connectivity change (offline → online) | Sync engine triggered via `ConnectivityProvider` |
| Manual refresh (pull-to-refresh) | Forces a full re-fetch and queue flush |

### 14.4 Sync Status Indicators

Each entity carries a `syncStatus` field:

| Value | Meaning |
|-------|---------|
| `synced` | Record confirmed in Supabase |
| `pending` | Record saved locally; awaiting upload |

A `SyncStatusBadge` widget displays sync status on patient cards and visit entries.

### 14.5 Conflict Resolution

- Remote data always wins for server-assigned fields (e.g., server-generated UUID replaces offline PRN).
- Last-write-wins strategy applies to content fields.
- Failed sync operations are retried up to three times with exponential backoff.

---

## 15. Audit Trail

### 15.1 Overview

The audit module records all data modifications for compliance and traceability.

### 15.2 Tracked Fields

Every patient, visit, surgery, and prescription record stores:
- `created_by` — user ID of the creator
- `updated_by` — user ID of the last editor
- `created_at` — UTC timestamp of creation
- `updated_at` — UTC timestamp of last modification

### 15.3 Audit Provider

An `AuditProvider` (Riverpod) tracks the current user's actions and can surface a filtered audit log for admin users.

---

## 16. Non-Functional Requirements

### 16.1 Performance

- Patient list initial load: under 2 seconds on a 4G connection.
- Search results update within 300 ms of the last keystroke (debounced).
- PDF generation for a standard OPD report: under 3 seconds on a mid-range device.
- Infinite scroll pagination: 20 patients per page.

### 16.2 Security

- All API communication over HTTPS (TLS 1.2+).
- Access tokens and refresh tokens stored in flutter_secure_storage (Keychain on iOS, Keystore on Android).
- No sensitive credentials committed to version control; all secrets injected at build time via `--dart-define`.
- Row-Level Security (RLS) enforced at the Supabase level per user role.

### 16.3 Usability

- Supports iOS and Android.
- Adaptive layout for phones and tablets.
- Material 3 design system with medical blue primary colour and health green secondary.
- Inter font for readability.
- All interactive elements meet WCAG AA contrast ratios.

### 16.4 Reliability

- Offline operation: all core workflows function without internet.
- Sync engine retries failed operations without user intervention.
- Graceful error states shown for all network/auth failure conditions.

### 16.5 Scalability

- Backend: Supabase PostgreSQL scales horizontally.
- Frontend: pagination and lazy loading prevent memory exhaustion on large patient lists.

---

*End of Functional Requirements Document*

*Prepared by the MediManage Development Team — September 2026*

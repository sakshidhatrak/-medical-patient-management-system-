import 'package:flutter/material.dart';

// ── Section IDs ───────────────────────────────────────────────────────────────

const String kSectionBasicInfo = 'basicInfo';
const String kSectionVitals = 'vitals';
const String kSectionTreatment = 'treatment';

const List<String> kDefaultSectionOrder = [
  kSectionBasicInfo,
  kSectionVitals,
  kSectionTreatment,
];

// ── Model ─────────────────────────────────────────────────────────────────────

class PrintField {
  final String id;
  final String label;
  final String sectionId;
  final IconData icon;

  const PrintField({
    required this.id,
    required this.label,
    required this.sectionId,
    required this.icon,
  });

  @override
  bool operator ==(Object other) =>
      other is PrintField && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ── All Fields (exactly mirrors the Patient Registration form) ─────────────────

const List<PrintField> kAllPrintFields = [
  // ── Basic Information ──────────────────────────────────────────────────────
  PrintField(
    id: 'firstName',
    label: 'First Name',
    sectionId: kSectionBasicInfo,
    icon: Icons.person_outline,
  ),
  PrintField(
    id: 'lastName',
    label: 'Last Name',
    sectionId: kSectionBasicInfo,
    icon: Icons.person_outline,
  ),
  PrintField(
    id: 'age',
    label: 'Age',
    sectionId: kSectionBasicInfo,
    icon: Icons.calendar_today_outlined,
  ),
  PrintField(
    id: 'gender',
    label: 'Gender',
    sectionId: kSectionBasicInfo,
    icon: Icons.wc_rounded,
  ),
  PrintField(
    id: 'phone',
    label: 'Phone Number',
    sectionId: kSectionBasicInfo,
    icon: Icons.phone_outlined,
  ),
  PrintField(
    id: 'altPhone',
    label: 'Alt. Phone',
    sectionId: kSectionBasicInfo,
    icon: Icons.phone_callback_outlined,
  ),
  PrintField(
    id: 'email',
    label: 'Email',
    sectionId: kSectionBasicInfo,
    icon: Icons.email_outlined,
  ),
  PrintField(
    id: 'address',
    label: 'Address',
    sectionId: kSectionBasicInfo,
    icon: Icons.location_on_outlined,
  ),
  PrintField(
    id: 'idProofType',
    label: 'ID Proof Type',
    sectionId: kSectionBasicInfo,
    icon: Icons.badge_outlined,
  ),
  PrintField(
    id: 'idProofNumber',
    label: 'ID Proof Number',
    sectionId: kSectionBasicInfo,
    icon: Icons.fingerprint_outlined,
  ),
  PrintField(
    id: 'allergies',
    label: 'Known Allergies',
    sectionId: kSectionBasicInfo,
    icon: Icons.warning_amber_outlined,
  ),
  PrintField(
    id: 'medicalHistory',
    label: 'Medical History',
    sectionId: kSectionBasicInfo,
    icon: Icons.history_outlined,
  ),

  // ── Patient Vitals ─────────────────────────────────────────────────────────
  PrintField(
    id: 'weight',
    label: 'Weight',
    sectionId: kSectionVitals,
    icon: Icons.monitor_weight_outlined,
  ),
  PrintField(
    id: 'bloodPressure',
    label: 'Blood Pressure',
    sectionId: kSectionVitals,
    icon: Icons.favorite_border_rounded,
  ),
  PrintField(
    id: 'temperature',
    label: 'Temperature',
    sectionId: kSectionVitals,
    icon: Icons.thermostat_outlined,
  ),

  // ── Treatment Information ──────────────────────────────────────────────────
  PrintField(
    id: 'previousHistory',
    label: 'Previous History',
    sectionId: kSectionTreatment,
    icon: Icons.history_edu_outlined,
  ),
  PrintField(
    id: 'chiefComplaint',
    label: 'Chief Complaint',
    sectionId: kSectionTreatment,
    icon: Icons.assignment_outlined,
  ),
  PrintField(
    id: 'examGeneral',
    label: 'Examination (General)',
    sectionId: kSectionTreatment,
    icon: Icons.search_outlined,
  ),
  PrintField(
    id: 'examNeurological',
    label: 'Examination (Neurological)',
    sectionId: kSectionTreatment,
    icon: Icons.psychology_outlined,
  ),
  PrintField(
    id: 'clinicalDiagnosis',
    label: 'Clinical Diagnosis',
    sectionId: kSectionTreatment,
    icon: Icons.biotech_outlined,
  ),
  PrintField(
    id: 'imaging',
    label: 'Imaging',
    sectionId: kSectionTreatment,
    icon: Icons.image_search_outlined,
  ),
  PrintField(
    id: 'otherInvestigation',
    label: 'Other Investigation',
    sectionId: kSectionTreatment,
    icon: Icons.science_outlined,
  ),
  PrintField(
    id: 'diagnosis',
    label: 'Impression',
    sectionId: kSectionTreatment,
    icon: Icons.local_hospital_outlined,
  ),
  PrintField(
    id: 'treatmentPlan',
    label: 'Plan',
    sectionId: kSectionTreatment,
    icon: Icons.playlist_add_check_rounded,
  ),
  PrintField(
    id: 'medications',
    label: 'Treatment / Medications',
    sectionId: kSectionTreatment,
    icon: Icons.medication_outlined,
  ),
  PrintField(
    id: 'notes',
    label: 'Notes',
    sectionId: kSectionTreatment,
    icon: Icons.notes_rounded,
  ),
  PrintField(
    id: 'advice',
    label: 'Advice',
    sectionId: kSectionTreatment,
    icon: Icons.tips_and_updates_outlined,
  ),
];

// Convenience lookup
PrintField? printFieldById(String id) {
  for (final f in kAllPrintFields) {
    if (f.id == id) return f;
  }
  return null;
}

List<PrintField> fieldsForSection(String sectionId) =>
    kAllPrintFields.where((f) => f.sectionId == sectionId).toList();

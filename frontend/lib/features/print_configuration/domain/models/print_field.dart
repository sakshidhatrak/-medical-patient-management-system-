import 'package:flutter/material.dart';

// ── Section IDs ───────────────────────────────────────────────────────────────

const String kSectionBasicInfo = 'basicInfo';
const String kSectionVitals = 'vitals';
const String kSectionTreatment = 'treatment';
const String kSectionReports = 'reports';

const List<String> kDefaultSectionOrder = [
  kSectionBasicInfo,
  kSectionVitals,
  kSectionTreatment,
  kSectionReports,
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

// ── All Fields ────────────────────────────────────────────────────────────────

const List<PrintField> kAllPrintFields = [
  // Basic Information
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
    id: 'dob',
    label: 'Date of Birth',
    sectionId: kSectionBasicInfo,
    icon: Icons.cake_outlined,
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
    id: 'bloodType',
    label: 'Blood Type',
    sectionId: kSectionBasicInfo,
    icon: Icons.bloodtype_outlined,
  ),

  // Patient Vitals
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

  // Treatment Information
  PrintField(
    id: 'chiefComplaint',
    label: 'Chief Complaint',
    sectionId: kSectionTreatment,
    icon: Icons.assignment_outlined,
  ),
  PrintField(
    id: 'diagnosis',
    label: 'Diagnosis',
    sectionId: kSectionTreatment,
    icon: Icons.local_hospital_outlined,
  ),
  PrintField(
    id: 'treatmentPlan',
    label: 'Treatment Plan',
    sectionId: kSectionTreatment,
    icon: Icons.playlist_add_check_rounded,
  ),
  PrintField(
    id: 'medications',
    label: 'Medications',
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
    id: 'doctorAssigned',
    label: 'Doctor Assigned',
    sectionId: kSectionTreatment,
    icon: Icons.person_pin_rounded,
  ),
  PrintField(
    id: 'visitType',
    label: 'Visit Type',
    sectionId: kSectionTreatment,
    icon: Icons.calendar_today_outlined,
  ),

  // Uploaded Reports
  PrintField(
    id: 'prescription',
    label: 'Prescription',
    sectionId: kSectionReports,
    icon: Icons.receipt_long_outlined,
  ),
  PrintField(
    id: 'labReport',
    label: 'Lab Report',
    sectionId: kSectionReports,
    icon: Icons.science_outlined,
  ),
  PrintField(
    id: 'xray',
    label: 'X-Ray',
    sectionId: kSectionReports,
    icon: Icons.image_outlined,
  ),
  PrintField(
    id: 'mriCt',
    label: 'MRI / CT Scan',
    sectionId: kSectionReports,
    icon: Icons.biotech_outlined,
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

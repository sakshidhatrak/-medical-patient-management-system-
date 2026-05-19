import 'package:flutter/material.dart';

import 'print_field.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class ReportSection {
  final String id;
  final String title;
  final IconData icon;
  final Color color;

  const ReportSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
  });

  List<PrintField> get allFields => fieldsForSection(id);

  List<PrintField> enabledFields(Set<String> enabledIds) =>
      allFields.where((f) => enabledIds.contains(f.id)).toList();

  bool hasEnabledFields(Set<String> enabledIds) =>
      allFields.any((f) => enabledIds.contains(f.id));
}

// ── All Sections ──────────────────────────────────────────────────────────────

const List<ReportSection> kAllReportSections = [
  ReportSection(
    id: kSectionBasicInfo,
    title: 'Basic Information',
    icon: Icons.person_outlined,
    color: Color(0xFF6C63FF),
  ),
  ReportSection(
    id: kSectionVitals,
    title: 'Patient Vitals',
    icon: Icons.monitor_heart_outlined,
    color: Color(0xFFFF647C),
  ),
  ReportSection(
    id: kSectionTreatment,
    title: 'Treatment Information',
    icon: Icons.medical_services_outlined,
    color: Color(0xFF0095FF),
  ),
  ReportSection(
    id: kSectionReports,
    title: 'Uploaded Reports',
    icon: Icons.upload_file_rounded,
    color: Color(0xFF00C48C),
  ),
];

ReportSection? sectionById(String id) {
  for (final s in kAllReportSections) {
    if (s.id == id) return s;
  }
  return null;
}

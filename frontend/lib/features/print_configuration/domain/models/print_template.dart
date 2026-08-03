import 'print_field.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class PrintTemplate {
  final String id;
  final String name;
  final Set<String> enabledFieldIds;
  final List<String> sectionOrder;
  final bool isBuiltIn;

  const PrintTemplate({
    required this.id,
    required this.name,
    required this.enabledFieldIds,
    required this.sectionOrder,
    this.isBuiltIn = false,
  });

  PrintTemplate copyWith({
    String? id,
    String? name,
    Set<String>? enabledFieldIds,
    List<String>? sectionOrder,
    bool? isBuiltIn,
  }) =>
      PrintTemplate(
        id: id ?? this.id,
        name: name ?? this.name,
        enabledFieldIds: enabledFieldIds ?? this.enabledFieldIds,
        sectionOrder: sectionOrder ?? this.sectionOrder,
        isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      );

  @override
  bool operator ==(Object other) =>
      other is PrintTemplate && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ── Built-in Templates ────────────────────────────────────────────────────────

// All fields that exist in the patient registration form
const Set<String> _kAllFieldIds = {
  // Basic Info
  'firstName', 'lastName', 'age', 'gender',
  'phone', 'altPhone', 'email', 'address',
  'idProofType', 'idProofNumber',
  'allergies', 'medicalHistory',
  // Vitals
  'weight', 'bloodPressure', 'temperature',
  // Treatment
  'previousHistory', 'chiefComplaint',
  'examGeneral', 'examNeurological',
  'clinicalDiagnosis', 'imaging', 'otherInvestigation',
  'diagnosis', 'treatmentPlan', 'medications', 'notes', 'advice',
};

const Set<String> _kEmergencyFields = {
  'firstName', 'lastName', 'age', 'gender', 'phone',
  'weight', 'bloodPressure', 'temperature',
  'chiefComplaint', 'diagnosis',
};

const Set<String> _kDoctorFields = {
  'firstName', 'lastName', 'age',
  'weight', 'bloodPressure', 'temperature',
  'chiefComplaint', 'examGeneral', 'examNeurological',
  'clinicalDiagnosis', 'diagnosis', 'treatmentPlan', 'medications', 'notes', 'advice',
};

const List<PrintTemplate> kBuiltInTemplates = [
  PrintTemplate(
    id: 'tpl_full',
    name: 'Full Patient Report',
    enabledFieldIds: _kAllFieldIds,
    sectionOrder: kDefaultSectionOrder,
    isBuiltIn: true,
  ),
  PrintTemplate(
    id: 'tpl_opd',
    name: 'OPD Summary',
    enabledFieldIds: {
      'firstName', 'lastName', 'age', 'gender', 'phone',
      'weight', 'bloodPressure', 'temperature',
      'chiefComplaint', 'diagnosis', 'medications',
    },
    sectionOrder: kDefaultSectionOrder,
    isBuiltIn: true,
  ),
  PrintTemplate(
    id: 'tpl_emergency',
    name: 'Emergency Summary',
    enabledFieldIds: _kEmergencyFields,
    sectionOrder: kDefaultSectionOrder,
    isBuiltIn: true,
  ),
  PrintTemplate(
    id: 'tpl_doctor',
    name: 'Doctor Summary',
    enabledFieldIds: _kDoctorFields,
    sectionOrder: kDefaultSectionOrder,
    isBuiltIn: true,
  ),
];

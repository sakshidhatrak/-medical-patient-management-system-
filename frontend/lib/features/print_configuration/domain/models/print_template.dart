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

const Set<String> _kAllFieldIds = {
  'firstName', 'lastName', 'dob', 'gender', 'phone', 'email', 'address',
  'bloodType',
  'weight', 'bloodPressure', 'temperature',
  'chiefComplaint', 'diagnosis', 'treatmentPlan', 'medications', 'notes',
  'doctorAssigned', 'visitType',
  'prescription', 'labReport', 'xray', 'mriCt',
};

const Set<String> _kEmergencyFields = {
  'firstName', 'lastName', 'dob', 'gender', 'phone', 'bloodType',
  'weight', 'bloodPressure', 'temperature',
  'chiefComplaint', 'diagnosis', 'doctorAssigned', 'visitType',
};

const Set<String> _kInsuranceFields = {
  'firstName', 'lastName', 'dob', 'gender', 'phone', 'email', 'address',
  'bloodType',
  'diagnosis', 'treatmentPlan', 'medications',
  'prescription', 'labReport',
};

const Set<String> _kDoctorFields = {
  'firstName', 'lastName', 'dob', 'bloodType',
  'weight', 'bloodPressure', 'temperature',
  'chiefComplaint', 'diagnosis', 'treatmentPlan', 'medications', 'notes',
  'doctorAssigned', 'visitType',
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
      'firstName', 'lastName', 'dob', 'gender', 'phone', 'bloodType',
      'weight', 'bloodPressure', 'temperature',
      'chiefComplaint', 'diagnosis', 'medications', 'doctorAssigned', 'visitType',
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
    id: 'tpl_insurance',
    name: 'Insurance Copy',
    enabledFieldIds: _kInsuranceFields,
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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/print_field.dart';
import '../../domain/models/print_template.dart';

// ── Mock patient data used in the live preview ────────────────────────────────

const Map<String, String> kMockPatientData = {
  'firstName': 'Sarah',
  'lastName': 'Johnson',
  'age': '41 yrs',
  'gender': 'Female',
  'phone': '+1 555-0101',
  'altPhone': '+1 555-0202',
  'email': 'sarah.johnson@email.com',
  'address': '123 Oak Street, Boston, MA 02101',
  'idProofType': 'Aadhaar Card',
  'idProofNumber': '1234-5678-9012',
  'allergies': 'Penicillin, Sulfa drugs',
  'medicalHistory': 'Hypertension (diagnosed 2018), No prior surgeries.',
  'weight': '65 kg',
  'bloodPressure': '118 / 76 mmHg',
  'temperature': '37.1 °C',
  'previousHistory': 'Hospitalised for atrial fibrillation in 2023.',
  'chiefComplaint': 'Chest pain and shortness of breath for 2 days.',
  'examGeneral': 'Conscious, alert, mild distress. Vitals stable.',
  'examNeurological': 'No focal neurological deficits.',
  'clinicalDiagnosis': 'Acute Coronary Syndrome — NSTEMI',
  'imaging': 'Chest X-Ray: mild pulmonary congestion.',
  'otherInvestigation': 'ECG: ST-segment depression in V4–V6. Troponin elevated.',
  'diagnosis': 'Acute Coronary Syndrome — NSTEMI',
  'treatmentPlan':
      'Admit for monitoring, initiate anticoagulation therapy, cardiology consult within 24 hours.',
  'medications': 'Aspirin 325 mg · Metoprolol 25 mg · Atorvastatin 80 mg',
  'notes':
      'Patient is haemodynamically stable. Follow-up echocardiogram scheduled for tomorrow.',
  'advice': 'Low-sodium diet. Avoid strenuous activity. Follow up in 1 week.',
};

// ── State ─────────────────────────────────────────────────────────────────────

class PrintConfigState {
  final Set<String> enabledFieldIds;
  final List<String> sectionOrder;
  final List<PrintTemplate> templates;
  final String activeTemplateId;
  final bool isExporting;

  const PrintConfigState({
    required this.enabledFieldIds,
    required this.sectionOrder,
    required this.templates,
    required this.activeTemplateId,
    this.isExporting = false,
  });

  // ── Derived ──────────────────────────────────────────────────────────────

  bool isFieldEnabled(String id) => enabledFieldIds.contains(id);

  bool isSectionEnabled(String sectionId) =>
      fieldsForSection(sectionId).any((f) => enabledFieldIds.contains(f.id));

  PrintTemplate? get activeTemplate {
    for (final t in templates) {
      if (t.id == activeTemplateId) return t;
    }
    return null;
  }

  PrintConfigState copyWith({
    Set<String>? enabledFieldIds,
    List<String>? sectionOrder,
    List<PrintTemplate>? templates,
    String? activeTemplateId,
    bool? isExporting,
  }) =>
      PrintConfigState(
        enabledFieldIds: enabledFieldIds ?? this.enabledFieldIds,
        sectionOrder: sectionOrder ?? this.sectionOrder,
        templates: templates ?? this.templates,
        activeTemplateId: activeTemplateId ?? this.activeTemplateId,
        isExporting: isExporting ?? this.isExporting,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class PrintConfigNotifier extends Notifier<PrintConfigState> {
  static const String _defaultTemplateId = 'tpl_full';

  @override
  PrintConfigState build() {
    final defaultTemplate =
        kBuiltInTemplates.firstWhere((t) => t.id == _defaultTemplateId);
    return PrintConfigState(
      enabledFieldIds: Set.from(defaultTemplate.enabledFieldIds),
      sectionOrder: List.from(defaultTemplate.sectionOrder),
      templates: List.from(kBuiltInTemplates),
      activeTemplateId: _defaultTemplateId,
    );
  }

  // ── Field toggles ─────────────────────────────────────────────────────────

  void toggleField(String fieldId) {
    final current = Set<String>.from(state.enabledFieldIds);
    if (current.contains(fieldId)) {
      current.remove(fieldId);
    } else {
      current.add(fieldId);
    }
    state = state.copyWith(
      enabledFieldIds: current,
      activeTemplateId: _customId,
    );
  }

  void toggleSection(String sectionId, {required bool enable}) {
    final ids = fieldsForSection(sectionId).map((f) => f.id).toSet();
    final current = Set<String>.from(state.enabledFieldIds);
    if (enable) {
      current.addAll(ids);
    } else {
      current.removeAll(ids);
    }
    state = state.copyWith(
      enabledFieldIds: current,
      activeTemplateId: _customId,
    );
  }

  // ── Section ordering ──────────────────────────────────────────────────────

  void reorderSections(int oldIndex, int newIndex) {
    final order = List<String>.from(state.sectionOrder);
    if (newIndex > oldIndex) newIndex--;
    final item = order.removeAt(oldIndex);
    order.insert(newIndex, item);
    state = state.copyWith(sectionOrder: order, activeTemplateId: _customId);
  }

  // ── Template management ───────────────────────────────────────────────────

  void loadTemplate(String templateId) {
    final tpl = state.templates.firstWhere(
      (t) => t.id == templateId,
      orElse: () => state.templates.first,
    );
    state = state.copyWith(
      enabledFieldIds: Set.from(tpl.enabledFieldIds),
      sectionOrder: List.from(tpl.sectionOrder),
      activeTemplateId: templateId,
    );
  }

  void saveTemplate(String name) {
    final existing = state.templates
        .where((t) => !t.isBuiltIn && t.name == name)
        .toList();

    final newId = existing.isEmpty
        ? 'tpl_custom_${const Uuid().v4().substring(0, 8)}'
        : existing.first.id;

    final newTemplate = PrintTemplate(
      id: newId,
      name: name,
      enabledFieldIds: Set.from(state.enabledFieldIds),
      sectionOrder: List.from(state.sectionOrder),
    );

    final updated = state.templates
        .where((t) => t.id != newId)
        .toList()
      ..add(newTemplate);

    state = state.copyWith(
      templates: updated,
      activeTemplateId: newId,
    );
  }

  void deleteTemplate(String templateId) {
    if (kBuiltInTemplates.any((t) => t.id == templateId)) return;
    final updated =
        state.templates.where((t) => t.id != templateId).toList();
    final nextId =
        state.activeTemplateId == templateId ? _defaultTemplateId : state.activeTemplateId;
    state = state.copyWith(templates: updated, activeTemplateId: nextId);
    if (state.activeTemplateId != state.activeTemplateId) {
      loadTemplate(nextId);
    }
  }

  void reset() {
    loadTemplate(_defaultTemplateId);
  }

  void setExporting(bool value) {
    state = state.copyWith(isExporting: value);
  }

  // ── Private ───────────────────────────────────────────────────────────────

  static const String _customId = 'tpl_custom';
}

// ── Provider ──────────────────────────────────────────────────────────────────

final printConfigProvider =
    NotifierProvider<PrintConfigNotifier, PrintConfigState>(
  PrintConfigNotifier.new,
);

/// Holds real patient data for the active print job.
/// Null means no patient selected — preview falls back to [kMockPatientData].
final activePatientDataProvider =
    StateProvider<Map<String, String>?>((ref) => null);

/// Returns the effective data map: real patient data or mock fallback.
final effectivePatientDataProvider = Provider<Map<String, String>>((ref) {
  return ref.watch(activePatientDataProvider) ?? kMockPatientData;
});

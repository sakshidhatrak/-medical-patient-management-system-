import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../medicines/data/medicine_service.dart';
import '../../../patients/domain/entities/patient_entity.dart';
import '../../../patients/presentation/providers/patient_provider.dart';
import '../../../photos/domain/entities/photo_entity.dart';
import '../../../photos/presentation/providers/photo_provider.dart';
import '../../domain/entities/visit_entity.dart';
import '../providers/visit_provider.dart';
import 'package:medical_patient_management/core/theme/theme_extensions.dart';

// ── fixed palette (same in both modes) ───────────────────────────────────────
const _kP1    = Color(0xFF5B5ECC);
const _kGreen = Color(0xFF3DB070);
const _kRed   = Color(0xFFCC6B6B);
const _kAmber = Color(0xFFD97706);

// ── Medicine entry ────────────────────────────────────────────────────────────
class _Medicine {
  final TextEditingController name   = TextEditingController();
  final TextEditingController dosage = TextEditingController();
  void dispose() { name.dispose(); dosage.dispose(); }
}

// ── Screen ────────────────────────────────────────────────────────────────────
class VisitFormScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String visitId;
  const VisitFormScreen({super.key, required this.patientId, required this.visitId});

  @override
  ConsumerState<VisitFormScreen> createState() => _VisitFormState();
}

class _VisitFormState extends ConsumerState<VisitFormScreen> {
  bool _loaded         = false;
  bool _patientApplied = false;
  bool _saving         = false;
  bool _uploadingFiles = false;
  bool _examTabGeneral = true;

  DateTime  _visitDate    = DateTime.now();
  DateTime? _followUpDate;
  VisitType _visitType    = VisitType.opd;

  final _prevHistoryCtrl = TextEditingController();
  final _complaintCtrl   = TextEditingController();
  final _examGeneralCtrl = TextEditingController();
  final _examNeuroCtrl   = TextEditingController();
  final _clinDiagCtrl    = TextEditingController();
  final _imagingCtrl     = TextEditingController();
  final _otherInvestCtrl = TextEditingController();
  final _impressionCtrl  = TextEditingController();
  final _planCtrl        = TextEditingController();
  final _adviceCtrl      = TextEditingController();
  final _notesCtrl       = TextEditingController();

  // Vitals — stored per visit
  final _bpCtrl      = TextEditingController();
  final _tempCtrl    = TextEditingController();
  final _weightCtrl  = TextEditingController();

  List<_Medicine> _medicines = [];
  final List<({String name, Uint8List bytes})> _pendingFiles = [];

  @override
  void initState() {
    super.initState();
    _medicines.add(_Medicine());
  }

  @override
  void dispose() {
    for (final c in [
      _prevHistoryCtrl, _complaintCtrl, _examGeneralCtrl, _examNeuroCtrl,
      _clinDiagCtrl, _imagingCtrl, _otherInvestCtrl,
      _impressionCtrl, _planCtrl, _adviceCtrl, _notesCtrl,
      _bpCtrl, _tempCtrl, _weightCtrl,
    ]) c.dispose();
    for (final m in _medicines) m.dispose();
    super.dispose();
  }

  void _populateFrom(VisitEntity v) {
    if (_loaded) return;
    _loaded = true;
    _visitDate = v.visitDate;
    _visitType = v.visitType;
    void set(TextEditingController c, String? val) {
      if (val?.isNotEmpty == true) c.text = val!;
    }
    set(_complaintCtrl,  v.complaints);
    set(_impressionCtrl, v.clinicalImpression);
    set(_planCtrl,       v.plan);
    set(_notesCtrl,      v.notes);
    set(_bpCtrl,         v.bp);
    set(_tempCtrl,       v.temperature);
    set(_weightCtrl,     v.weight);

    if (v.examination?.isNotEmpty == true) {
      try {
        final m = jsonDecode(v.examination!) as Map<String, dynamic>;
        set(_prevHistoryCtrl,  m['previousHistory']    as String?);
        set(_examGeneralCtrl,  m['examGeneral']         as String?);
        set(_examNeuroCtrl,    m['examNeurological']    as String?);
        set(_clinDiagCtrl,     m['clinicalDiagnosis']   as String?);
        set(_imagingCtrl,      m['imaging']              as String?);
        set(_otherInvestCtrl,  m['otherInvestigation']  as String?);
        set(_adviceCtrl,       m['advice']               as String?);

        final fuStr = m['followUpDate'] as String?;
        if (fuStr?.isNotEmpty == true) {
          try { _followUpDate = DateTime.parse(fuStr!); } catch (_) {}
        }

        final medsStr = m['medications'] as String?;
        if (medsStr?.isNotEmpty == true) {
          final parsed = medsStr!.split(', ').map((s) {
            final med   = _Medicine();
            final match = RegExp(r'^(.+?)\s*\((.+?)\)$').firstMatch(s.trim());
            if (match != null) {
              med.name.text   = match.group(1)!;
              med.dosage.text = match.group(2)!;
            } else {
              med.name.text = s.trim();
            }
            return med;
          }).toList();
          for (final old in _medicines) old.dispose();
          _medicines = parsed;
        }
      } catch (_) {}
    }
    setState(() {});
  }

  void _applyPatientFallbacks(PatientEntity patient) {
    if (_patientApplied) return;
    _patientApplied = true;
    Map<String, String> notes = {};
    if (patient.notes?.isNotEmpty == true) {
      try {
        notes = (jsonDecode(patient.notes!) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {}
    }
    void fill(TextEditingController ctrl, String key) {
      if (ctrl.text.isEmpty && notes[key]?.isNotEmpty == true) {
        ctrl.text = notes[key]!;
      }
    }
    fill(_complaintCtrl,  'chiefComplaint');
    fill(_impressionCtrl, 'diagnosis');
    fill(_planCtrl,       'treatmentPlan');
    fill(_notesCtrl,      'treatmentNotes');
    setState(() {});
  }

  String? _buildExamination() {
    final m = <String, String>{};
    void add(String k, String v) { if (v.trim().isNotEmpty) m[k] = v.trim(); }
    add('previousHistory',   _prevHistoryCtrl.text);
    add('examGeneral',        _examGeneralCtrl.text);
    add('examNeurological',   _examNeuroCtrl.text);
    add('clinicalDiagnosis',  _clinDiagCtrl.text);
    add('imaging',             _imagingCtrl.text);
    add('otherInvestigation', _otherInvestCtrl.text);
    add('advice',              _adviceCtrl.text);
    if (_followUpDate != null) {
      m['followUpDate'] = DateFormat('yyyy-MM-dd').format(_followUpDate!);
    }
    final medsStr = _medicines
        .where((med) => med.name.text.trim().isNotEmpty)
        .map((med) {
          final d = med.dosage.text.trim();
          return d.isNotEmpty ? '${med.name.text.trim()} ($d)' : med.name.text.trim();
        })
        .join(', ');
    if (medsStr.isNotEmpty) m['medications'] = medsStr;
    return m.isEmpty ? null : jsonEncode(m);
  }

  Future<void> _save({bool complete = true}) async {
    if (_saving || _uploadingFiles) return;
    _saving = true;
    setState(() {});

    final current = ref.read(visitEditProvider('${widget.patientId}/${widget.visitId}'));
    if (current == null) { setState(() => _saving = false); return; }

    String? nonEmpty(String s) => s.trim().isNotEmpty ? s.trim() : null;
    final updated = current.copyWith(
      visitDate:          _visitDate,
      visitType:          _visitType,
      complaints:         nonEmpty(_complaintCtrl.text),
      clinicalImpression: nonEmpty(_impressionCtrl.text),
      plan:               nonEmpty(_planCtrl.text),
      notes:              nonEmpty(_notesCtrl.text),
      bp:                 nonEmpty(_bpCtrl.text),
      temperature:        nonEmpty(_tempCtrl.text),
      weight:             nonEmpty(_weightCtrl.text),
      examination:        _buildExamination(),
      status:             complete ? 'completed' : 'draft',
    );

    ref.read(visitEditProvider('${widget.patientId}/${widget.visitId}').notifier).update(updated);
    final ok = await ref.read(visitEditProvider('${widget.patientId}/${widget.visitId}').notifier).save();

    if (ok) {
      final medsStr = _medicines
          .where((med) => med.name.text.trim().isNotEmpty)
          .map((med) {
            final d = med.dosage.text.trim();
            return d.isNotEmpty ? '${med.name.text.trim()} ($d)' : med.name.text.trim();
          })
          .join(', ');
      if (medsStr.isNotEmpty) {
        unawaited(ref.read(medicineServiceProvider).savePrescription(
          visitId: widget.visitId,
          patientId: widget.patientId,
          visitDate: _visitDate,
          medicationsText: medsStr,
        ));
      }
    }

    if (ok && _pendingFiles.isNotEmpty) {
      setState(() { _saving = false; _uploadingFiles = true; });
      final notifier = ref.read(photoProvider(widget.patientId).notifier);
      for (final f in _pendingFiles) {
        await notifier.upload(
          bytes:    f.bytes,
          filename: f.name,
          category: PhotoCategory.patientReport,
          visitId:  widget.visitId,
          caption:  f.name,
        );
      }
      if (mounted) setState(() => _uploadingFiles = false);
    } else {
      if (mounted) setState(() => _saving = false);
    }

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          SizedBox(width: 10),
          Text('Visit saved', style: TextStyle(fontWeight: FontWeight.w600)),
        ]),
        backgroundColor: _kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to save visit. Please try again.'),
        backgroundColor: _kRed,
        behavior: SnackBarBehavior.floating,
      ));
      setState(() => _saving = false);
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      withData: true,
    );
    if (result == null) return;
    setState(() {
      for (final f in result.files) {
        if (f.bytes != null) {
          _pendingFiles.add((name: f.name, bytes: f.bytes!));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final patientAsync   = ref.watch(patientByIdProvider(widget.patientId));
    final visit          = ref.watch(visitEditProvider('${widget.patientId}/${widget.visitId}'));
    final existingPhotos = ref.watch(photoProvider(widget.patientId)).photos
        .where((p) => p.visitId == widget.visitId).toList();

    if (visit != null && !_loaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _populateFrom(visit));
    }
    patientAsync.whenData((patient) {
      if (patient != null && !_patientApplied) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _applyPatientFallbacks(patient));
      }
    });

    final busy = _saving || _uploadingFiles;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _VisitAppBar(
            busy: busy,
            uploadingFiles: _uploadingFiles,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
              children: [
                patientAsync.when(
                  loading: () => const SizedBox(
                      height: 56,
                      child: Center(child: CircularProgressIndicator(color: _kP1, strokeWidth: 2))),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (p) => p == null
                      ? const SizedBox.shrink()
                      : _PatientInfoCard(patient: p),
                ),

                // 1. History & Complaint
                _SectionCard(
                  title: 'History & Complaint',
                  children: [
                    _ExpandField(
                      hint: 'Previous medical history',
                      controller: _prevHistoryCtrl,
                      label: 'Previous Medical History',
                    ),
                    const SizedBox(height: 10),
                    _ExpandField(
                      hint: 'Chief complaint — e.g. Fever, Headache',
                      controller: _complaintCtrl,
                      label: 'Chief Complaint',
                    ),
                  ],
                ),

                // 2. Vitals
                _SectionCard(
                  title: 'Vitals',
                  children: [
                    Row(children: [
                      Expanded(
                        child: _InlineField(
                          label: 'Blood Pressure',
                          hint: 'e.g. 120/80',
                          controller: _bpCtrl,
                          icon: Icons.favorite_border_rounded,
                          keyboardType: TextInputType.text,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InlineField(
                          label: 'Temperature',
                          hint: 'e.g. 98.6 °F',
                          controller: _tempCtrl,
                          icon: Icons.thermostat_outlined,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InlineField(
                          label: 'Weight',
                          hint: 'e.g. 65 kg',
                          controller: _weightCtrl,
                          icon: Icons.monitor_weight_outlined,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ]),
                  ],
                ),

                // 3. Examination Finding
                _SectionCard(
                  title: 'Examination Finding',
                  children: [
                    Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: context.inputColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: Row(children: [
                        _ExamTab(
                          label: 'General',
                          selected: _examTabGeneral,
                          onTap: () => setState(() => _examTabGeneral = true),
                        ),
                        _ExamTab(
                          label: 'Neurological',
                          selected: !_examTabGeneral,
                          onTap: () => setState(() => _examTabGeneral = false),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    _ExpandField(
                      hint: _examTabGeneral
                          ? 'General examination findings'
                          : 'Neurological examination findings',
                      controller: _examTabGeneral ? _examGeneralCtrl : _examNeuroCtrl,
                      label: _examTabGeneral ? 'General Examination' : 'Neurological Examination',
                      maxLines: 3,
                    ),
                  ],
                ),

                // 3. Investigation
                _SectionCard(
                  title: 'Investigation',
                  children: [
                    _ExpandField(
                      hint: 'Clinical diagnosis — e.g. Viral Fever',
                      controller: _clinDiagCtrl,
                      label: 'Clinical Diagnosis',
                    ),
                    const SizedBox(height: 10),
                    _ExpandField(
                      hint: 'Imaging findings (X-Ray, MRI, CT)',
                      controller: _imagingCtrl,
                      label: 'Imaging Findings',
                    ),
                    const SizedBox(height: 10),
                    _ExpandField(
                      hint: 'Other investigation (lab reports, etc.)',
                      controller: _otherInvestCtrl,
                      label: 'Other Investigation',
                    ),
                  ],
                ),

                // 4. Clinical Plan
                _SectionCard(
                  title: 'Clinical Plan',
                  children: [
                    _ExpandField(
                      hint: 'Impression',
                      controller: _impressionCtrl,
                      label: 'Impression',
                    ),
                    const SizedBox(height: 10),
                    _ExpandField(
                      hint: 'Recommended plan',
                      controller: _planCtrl,
                      label: 'Recommended Plan',
                    ),
                  ],
                ),

                // 5. Medicines
                _MedicinesSection(
                  medicines: _medicines,
                  patientId: widget.patientId,
                  onAdd: () => setState(() => _medicines.add(_Medicine())),
                  onRemove: (i) => setState(() {
                    _medicines[i].dispose();
                    _medicines.removeAt(i);
                  }),
                ),

                // 6. Advice & Follow-up
                _AdviceSection(
                  adviceCtrl:      _adviceCtrl,
                  notesCtrl:       _notesCtrl,
                  followUpDate:    _followUpDate,
                  pendingFiles:    _pendingFiles,
                  existingPhotos:  existingPhotos,
                  uploading:       _uploadingFiles,
                  onPickFollowUp:  () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _followUpDate ?? DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (c, w) => Theme(
                        data: Theme.of(c).copyWith(
                          colorScheme: const ColorScheme.dark(primary: _kP1),
                        ),
                        child: w!,
                      ),
                    );
                    if (d != null) setState(() => _followUpDate = d);
                  },
                  onPickFiles:     _pickFiles,
                  onRemoveFile:    (i) => setState(() => _pendingFiles.removeAt(i)),
                  onDeletePhoto:   (p) => ref.read(photoProvider(widget.patientId).notifier).delete(p),
                ),
              ],
            ),
          ),

          _BottomButtons(
            busy: busy,
            onPreview: () => context.pop(),
            onSave:    () => _save(complete: true),
          ),
        ]),
      ),
    );
  }
}

// ── AppBar ────────────────────────────────────────────────────────────────────
class _VisitAppBar extends StatelessWidget {
  final bool busy;
  final bool uploadingFiles;
  final VoidCallback onBack;
  const _VisitAppBar({required this.busy, required this.uploadingFiles, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(children: [
        GestureDetector(
          onTap: onBack,
          child: Icon(Icons.chevron_left, color: context.textPrimary, size: 28),
        ),
        const SizedBox(width: 10),
        Text(
          busy ? (uploadingFiles ? 'Uploading…' : 'Saving…') : 'Add Visit',
          style: TextStyle(
              color: context.textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        if (busy) ...[
          const SizedBox(width: 12),
          const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kP1)),
        ],
      ]),
    );
  }
}

// ── Patient info card ─────────────────────────────────────────────────────────
class _PatientInfoCard extends StatelessWidget {
  final PatientEntity patient;
  const _PatientInfoCard({required this.patient});

  String? _allergy(PatientEntity p) {
    if (p.notes?.isNotEmpty != true) return null;
    try {
      final m = jsonDecode(p.notes!) as Map<String, dynamic>;
      final a = m['allergies'] as String?;
      return (a?.trim().isNotEmpty == true) ? a : null;
    } catch (_) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    final allergy  = _allergy(patient);
    final ageSex   = patient.ageSex.isNotEmpty ? patient.ageSex : null;
    final prn      = patient.prn;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: _avatarColor(patient.initials),
          child: Text(patient.initials,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(patient.fullName,
                style: TextStyle(
                    color: context.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
            Text(
              [if (ageSex != null) ageSex, prn].join(' · '),
              style: TextStyle(color: context.textDisabled, fontSize: 11),
            ),
          ]),
        ),
        if (allergy != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _kAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kAmber.withValues(alpha: 0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.warning_amber_rounded, size: 12, color: _kAmber),
              const SizedBox(width: 4),
              Text(allergy,
                  style: const TextStyle(
                      color: _kAmber, fontSize: 10, fontWeight: FontWeight.w700)),
            ]),
          ),
      ]),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
    decoration: BoxDecoration(
      color: context.cardColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.borderColor),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: TextStyle(
              color: context.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
      const SizedBox(height: 12),
      ...children,
    ]),
  );
}

// ── Examination tab toggle ─────────────────────────────────────────────────────
class _ExamTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ExamTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: selected ? _kP1 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : context.textDisabled,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Text field with expand (↑) button ─────────────────────────────────────────
class _ExpandField extends StatelessWidget {
  final String hint;
  final String label;
  final TextEditingController controller;
  final int maxLines;
  const _ExpandField({
    required this.hint,
    required this.label,
    required this.controller,
    this.maxLines = 2,
  });

  void _expand(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16,
            MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(
                  color: ctx.borderColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          Row(children: [
            Text(label,
                style: TextStyle(
                    color: ctx.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Icon(Icons.close_rounded, color: ctx.textDisabled, size: 20),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: 8,
            style: TextStyle(color: ctx.textPrimary, fontSize: 14),
            decoration: _buildDecoration(ctx, hint),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                backgroundColor: _kP1,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Done',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  InputDecoration _buildDecoration(BuildContext context, String hintText) =>
      InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: context.textDisabled, fontSize: 13),
        filled: true,
        fillColor: context.inputColor,
        contentPadding: const EdgeInsets.fromLTRB(14, 12, 46, 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: context.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kP1, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: context.textPrimary, fontSize: 13),
          decoration: _buildDecoration(context, hint),
        ),
        Positioned(
          top: 8, right: 8,
          child: GestureDetector(
            onTap: () => _expand(context),
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: context.borderColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(Icons.open_in_full_rounded,
                  size: 14, color: context.textSecondary),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Compact inline field (for vitals row) ────────────────────────────────────
class _InlineField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType keyboardType;
  const _InlineField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.icon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 12, color: context.textDisabled),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: context.textDisabled),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: context.textDisabled, fontSize: 12),
            filled: true,
            fillColor: context.inputColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: BorderSide(color: context.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: BorderSide(color: context.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(color: _kP1, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Medicine name field with autocomplete overlay ──────────────────────────────
class _MedicineNameField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final String patientId;
  const _MedicineNameField({required this.controller, required this.patientId});

  @override
  ConsumerState<_MedicineNameField> createState() => _MedicineNameFieldState();
}

class _MedicineNameFieldState extends ConsumerState<_MedicineNameField> {
  final _focus      = FocusNode();
  final _layerLink  = LayerLink();
  OverlayEntry? _overlay;
  List<MedicineSuggestion> _suggestions = [];
  Timer? _debounce;

  Color _cardColor    = const Color(0xFF2A2A3A);
  Color _borderColor  = const Color(0xFF3A3A4A);
  Color _textPrimary  = Colors.white;
  Color _textDisabled = Colors.grey;
  Color _inputColor   = const Color(0xFF1E1E2E);

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus) {
      Future.delayed(const Duration(milliseconds: 150), _removeOverlay);
    }
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final q = value.trim();
      if (q.length < 2) {
        _removeOverlay();
        if (mounted) setState(() => _suggestions = []);
        return;
      }
      final results = await ref.read(medicineServiceProvider).getSuggestions(
        query: q,
        patientId: widget.patientId,
      );
      if (!mounted) return;
      setState(() => _suggestions = results);
      results.isNotEmpty ? _showOverlay() : _removeOverlay();
    });
  }

  void _select(String name) {
    widget.controller.text = name;
    widget.controller.selection = TextSelection.collapsed(offset: name.length);
    _removeOverlay();
    if (mounted) setState(() => _suggestions = []);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _showOverlay() {
    if (_overlay != null) { _overlay!.markNeedsBuild(); return; }
    final overlayState = Overlay.of(context);
    final cardColor    = _cardColor;
    final borderColor  = _borderColor;
    final textPrimary  = _textPrimary;
    final textDisabled = _textDisabled;
    _overlay = OverlayEntry(builder: (_) {
      final box   = context.findRenderObject() as RenderBox?;
      final width = box?.size.width ?? 220;
      return Positioned(
        width: width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 4),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
                boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                )],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: borderColor.withValues(alpha: 0.5),
                  ),
                  itemBuilder: (_, i) {
                    final s = _suggestions[i];
                    return InkWell(
                      onTap: () => _select(s.name),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(children: [
                          Icon(
                            s.isHistory ? Icons.history_rounded : Icons.medication_rounded,
                            size: 14,
                            color: s.isHistory ? _kGreen : _kP1,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
                                  overflow: TextOverflow.ellipsis),
                              if (s.subtitle.isNotEmpty)
                                Text(s.subtitle,
                                    style: TextStyle(fontSize: 10, color: s.isHistory ? _kGreen : textDisabled),
                                    overflow: TextOverflow.ellipsis),
                            ],
                          )),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
    });
    overlayState.insert(_overlay!);
  }

  @override
  Widget build(BuildContext context) {
    _cardColor    = context.cardColor;
    _borderColor  = context.borderColor;
    _textPrimary  = context.textPrimary;
    _textDisabled = context.textDisabled;
    _inputColor   = context.inputColor;
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode:  _focus,
        onChanged:  _onTextChanged,
        style: TextStyle(color: _textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Medicine name',
          hintStyle: TextStyle(color: _textDisabled, fontSize: 13),
          filled: true,
          fillColor: _inputColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kP1, width: 1.5),
          ),
        ),
      ),
    );
  }
}

// ── Medicines section ─────────────────────────────────────────────────────────
class _MedicinesSection extends StatelessWidget {
  final List<_Medicine> medicines;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  final String patientId;
  const _MedicinesSection({
    required this.medicines,
    required this.onAdd,
    required this.onRemove,
    required this.patientId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('MEDICINES',
              style: TextStyle(
                  color: context.textSecondary, fontWeight: FontWeight.w800,
                  fontSize: 11, letterSpacing: 0.8)),
          const Spacer(),
          GestureDetector(
            onTap: onAdd,
            child: const Text('+ Add',
                style: TextStyle(
                    color: _kP1, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 10),
        ...List.generate(medicines.length, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Expanded(
              flex: 3,
              child: _MedicineNameField(
                controller: medicines[i].name,
                patientId: patientId,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _FlatField(
                controller: medicines[i].dosage,
                hint: '1-0-1',
              ),
            ),
            if (medicines.length > 1) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => onRemove(i),
                child: Container(
                  width: 30, height: 44,
                  decoration: BoxDecoration(
                    color: _kRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kRed.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.remove_rounded, size: 16, color: _kRed),
                ),
              ),
            ],
          ]),
        )),
      ]),
    );
  }
}

// ── Advice & Follow-up section ────────────────────────────────────────────────
class _AdviceSection extends StatelessWidget {
  final TextEditingController adviceCtrl;
  final TextEditingController notesCtrl;
  final DateTime? followUpDate;
  final List<({String name, Uint8List bytes})> pendingFiles;
  final List<PhotoEntity> existingPhotos;
  final bool uploading;
  final VoidCallback onPickFollowUp;
  final VoidCallback onPickFiles;
  final void Function(int) onRemoveFile;
  final void Function(PhotoEntity) onDeletePhoto;

  const _AdviceSection({
    required this.adviceCtrl,
    required this.notesCtrl,
    required this.followUpDate,
    required this.pendingFiles,
    required this.existingPhotos,
    required this.uploading,
    required this.onPickFollowUp,
    required this.onPickFiles,
    required this.onRemoveFile,
    required this.onDeletePhoto,
  });

  InputDecoration _dec(BuildContext context, String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: context.textDisabled, fontSize: 13),
    filled: true,
    fillColor: context.inputColor,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: context.borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: context.borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _kP1, width: 1.5),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('ADVICE & FOLLOW-UP',
          style: TextStyle(
              color: context.textSecondary, fontWeight: FontWeight.w800,
              fontSize: 11, letterSpacing: 0.8)),
      const SizedBox(height: 12),

      Text('Treatment Advice',
          style: TextStyle(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      TextField(
        controller: adviceCtrl,
        maxLines: 3,
        style: TextStyle(color: context.textPrimary, fontSize: 13),
        decoration: _dec(context, 'Rest, drink plenty of fluids'),
      ),
      const SizedBox(height: 14),

      Text('Follow-up Date',
          style: TextStyle(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: onPickFollowUp,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: context.inputColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(children: [
            Icon(Icons.calendar_today_outlined,
                size: 15, color: context.textDisabled),
            const SizedBox(width: 10),
            Text(
              followUpDate != null
                  ? DateFormat('dd MMM yyyy').format(followUpDate!)
                  : 'Select date',
              style: TextStyle(
                  fontSize: 13,
                  color: followUpDate != null ? context.textPrimary : context.textDisabled,
                  fontWeight: FontWeight.w500),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 14),

      Text('Notes',
          style: TextStyle(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      TextField(
        controller: notesCtrl,
        maxLines: 3,
        style: TextStyle(color: context.textPrimary, fontSize: 13),
        decoration: _dec(context, 'Take medicines after food'),
      ),
      const SizedBox(height: 14),

      Text('Upload Reports',
          style: TextStyle(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),

      if (uploading)
        Container(
          height: 56,
          alignment: Alignment.center,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: _kP1)),
            const SizedBox(width: 10),
            Text('Uploading…', style: TextStyle(color: context.textDisabled, fontSize: 13)),
          ]),
        )
      else
        GestureDetector(
          onTap: onPickFiles,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: context.inputColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _kP1.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.upload_rounded, size: 17, color: _kP1),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Tap to attach lab reports or documents',
                    style: TextStyle(color: context.textDisabled, fontSize: 13)),
              ),
            ]),
          ),
        ),

      if (pendingFiles.isNotEmpty) ...[
        const SizedBox(height: 8),
        ...List.generate(pendingFiles.length, (i) => Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(children: [
            Icon(Icons.insert_drive_file_outlined,
                size: 16, color: context.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(pendingFiles[i].name,
                  style: TextStyle(color: context.textPrimary, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ),
            GestureDetector(
              onTap: () => onRemoveFile(i),
              child: Icon(Icons.close_rounded, size: 16, color: context.textDisabled),
            ),
          ]),
        )),
      ],

      if (existingPhotos.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text('Uploaded',
            style: TextStyle(color: context.textSecondary, fontSize: 11,
                fontWeight: FontWeight.w600, letterSpacing: 0.3)),
        const SizedBox(height: 6),
        ...existingPhotos.map((p) => _SavedFileTile(
          photo: p,
          onDelete: () => onDeletePhoto(p),
        )),
      ],

      const SizedBox(height: 8),
    ]);
  }
}

// ── Plain input field (for medicines row) ─────────────────────────────────────
class _FlatField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _FlatField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    style: TextStyle(color: context.textPrimary, fontSize: 13),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: context.textDisabled, fontSize: 13),
      filled: true,
      fillColor: context.inputColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: context.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: context.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kP1, width: 1.5),
      ),
    ),
  );
}

// ── Saved file tile ───────────────────────────────────────────────────────────
class _SavedFileTile extends StatelessWidget {
  final PhotoEntity photo;
  final VoidCallback onDelete;
  const _SavedFileTile({required this.photo, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name = photo.caption ?? photo.storagePath.split('/').last;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(children: [
        Icon(Icons.insert_drive_file_outlined, size: 16, color: context.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(name,
              style: TextStyle(color: context.textPrimary, fontSize: 12),
              overflow: TextOverflow.ellipsis),
        ),
        if (photo.url != null)
          GestureDetector(
            onTap: () async {
              try {
                await launchUrl(Uri.parse(photo.url!),
                    mode: LaunchMode.externalApplication);
              } catch (_) {}
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.open_in_new_rounded, size: 15, color: _kP1),
            ),
          ),
        GestureDetector(
          onTap: onDelete,
          child: const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.delete_outline_rounded, size: 15, color: _kRed),
          ),
        ),
      ]),
    );
  }
}

// ── Bottom buttons ────────────────────────────────────────────────────────────
class _BottomButtons extends StatelessWidget {
  final bool busy;
  final VoidCallback onPreview;
  final VoidCallback onSave;
  const _BottomButtons({required this.busy, required this.onPreview, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(14, 12, 14, 12 + bottom),
      decoration: BoxDecoration(
        color: context.cardColor,
        border: Border(top: BorderSide(color: context.borderColor)),
      ),
      child: Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: busy ? null : onPreview,
            style: OutlinedButton.styleFrom(
              foregroundColor: context.textPrimary,
              side: BorderSide(color: context.borderColor, width: 1.5),
              backgroundColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
            ),
            child: const Text('Preview'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton(
            onPressed: busy ? null : onSave,
            style: FilledButton.styleFrom(
              backgroundColor: _kP1,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 15),
            ),
            child: busy
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save & Print'),
          ),
        ),
      ]),
    );
  }
}

// ── Avatar color helper ───────────────────────────────────────────────────────
const _avatarPalette = [
  Color(0xFF5B5ECC), Color(0xFF8B6914), Color(0xFF9B4A38),
  Color(0xFF7B52AB), Color(0xFF2E7D32), Color(0xFF0277BD),
  Color(0xFFAD1457), Color(0xFF00695C),
];

Color _avatarColor(String initials) {
  final code = initials.codeUnits.fold(0, (a, b) => a + b);
  return _avatarPalette[code % _avatarPalette.length];
}

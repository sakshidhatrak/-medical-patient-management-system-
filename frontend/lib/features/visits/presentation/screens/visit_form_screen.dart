// ─────────────────────────────────────────────────────────────────────────────
// visit_form_screen.dart  –  Premium 6-step OPD Visit Wizard
// Design: Linear × Stripe × Apple Health — production-ready healthcare SaaS
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../patients/domain/entities/patient_entity.dart';
import '../../../patients/presentation/providers/patient_provider.dart';
import '../../domain/entities/visit_entity.dart';
import '../providers/visit_provider.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kP1     = Color(0xFF7C3AED);   // primary purple
const _kP2     = Color(0xFF3B82F6);   // primary blue
const _kP1L    = Color(0xFFF5F3FF);   // purple surface
const _kGreen  = Color(0xFF10B981);
const _kAmber  = Color(0xFFF59E0B);
const _kBg     = Color(0xFFF8FAFC);
const _kCard   = Colors.white;
const _kNavy   = Color(0xFF0F172A);
const _kSlate  = Color(0xFF475569);
const _kMuted  = Color(0xFF94A3B8);
const _kBorder = Color(0xFFE2E8F0);

// ── Step metadata ──────────────────────────────────────────────────────────────
const _kLabels = ['Patient', 'Details', 'Complaints', 'Vitals', 'Diagnosis', 'Review'];
const _kTitles = [
  'Select Patient', 'Visit Details', 'Chief Complaints',
  'Vitals & Exam', 'Diagnosis & Plan', 'Review & Save',
];
const _kSubtitles = [
  'Choose or search a patient',
  'Date, time & visit type',
  'What brought the patient in',
  'Record measurements & findings',
  'Clinical impression & treatment',
  'Confirm and finalize',
];

// ── Static data ───────────────────────────────────────────────────────────────
const _kVisitTypes = ['OPD Consultation', 'Emergency', 'Follow-up'];
const _kDoctors    = ['Dr. Harshal S. Chaudhari', 'Dr. Ananya Sharma', 'Dr. Rohit Verma'];
const _kDepts      = ['Neurosurgery', 'General Medicine', 'Orthopedics', 'Cardiology', 'Radiology'];
const _kQuickComplaints = [
  'Headache', 'Fever', 'Weakness', 'Numbness',
  'Tingling', 'Dizziness', 'Back Pain', 'Neck Pain',
  'Seizures', 'Vomiting', 'Chest Pain', 'Shortness of Breath',
];

// ─────────────────────────────────────────────────────────────────────────────
// Root screen widget
// ─────────────────────────────────────────────────────────────────────────────
class VisitFormScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String visitId;
  const VisitFormScreen({super.key, required this.patientId, required this.visitId});

  @override
  ConsumerState<VisitFormScreen> createState() => _VFState();
}

class _VFState extends ConsumerState<VisitFormScreen> {
  int  _step   = 0;
  bool _saving = false;
  bool _loaded = false;

  // Step 2
  late DateTime  _date;
  late TimeOfDay _time;
  String  _visitTypeLabel = 'OPD Consultation';
  String  _provider       = _kDoctors.first;
  String? _department;

  // Step 3
  final List<String> _chips = [];
  final _chipCtrl    = TextEditingController();
  final _historyCtrl = TextEditingController();

  // Step 4
  final _bpCtrl   = TextEditingController();
  final _pulCtrl  = TextEditingController();
  final _tmpCtrl  = TextEditingController();
  final _spo2Ctrl = TextEditingController();
  final _wtCtrl   = TextEditingController();
  final _htCtrl   = TextEditingController();
  final _physCtrl = TextEditingController();
  final _sysCtrl  = TextEditingController();

  // Step 5
  final _diagCtrl = TextEditingController();
  final _planCtrl = TextEditingController();
  final _medsCtrl = TextEditingController();
  final _invCtrl  = TextEditingController();
  final _advCtrl  = TextEditingController();
  final _fuCtrl   = TextEditingController();

  @override
  void initState() {
    super.initState();
    _date = DateTime.now();
    _time = TimeOfDay.fromDateTime(DateTime.now());
  }

  @override
  void dispose() {
    for (final c in [
      _chipCtrl, _historyCtrl,
      _bpCtrl, _pulCtrl, _tmpCtrl, _spo2Ctrl, _wtCtrl, _htCtrl, _physCtrl, _sysCtrl,
      _diagCtrl, _planCtrl, _medsCtrl, _invCtrl, _advCtrl, _fuCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _populateFrom(VisitEntity v) {
    _date = v.visitDate;
    _time = TimeOfDay.fromDateTime(v.visitDate);
    _visitTypeLabel = switch (v.visitType) {
      VisitType.emergency => 'Emergency',
      VisitType.followUp  => 'Follow-up',
      _                   => 'OPD Consultation',
    };
    if (v.complaints?.isNotEmpty == true) {
      _chips..clear()..addAll(v.complaints!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty));
    }
    _historyCtrl.text = v.notes ?? '';
    if (v.examination?.isNotEmpty == true) {
      try {
        final m = json.decode(v.examination!) as Map<String, dynamic>;
        _bpCtrl.text   = (m['bp']       as String?) ?? '';
        _pulCtrl.text  = (m['pulse']    as String?) ?? '';
        _tmpCtrl.text  = (m['temp']     as String?) ?? '';
        _spo2Ctrl.text = (m['spo2']     as String?) ?? '';
        _wtCtrl.text   = (m['weight']   as String?) ?? '';
        _htCtrl.text   = (m['height']   as String?) ?? '';
        _physCtrl.text = (m['physical'] as String?) ?? '';
        _sysCtrl.text  = (m['systemic'] as String?) ?? '';
      } catch (_) {
        _physCtrl.text = v.examination!;
      }
    }
    _diagCtrl.text = v.clinicalImpression ?? '';
    _planCtrl.text = v.plan ?? '';
    setState(() {});
  }

  String get _visitTypeName => switch (_visitTypeLabel) {
    'Emergency' => 'emergency',
    'Follow-up' => 'follow_up',
    _           => 'opd',
  };

  VisitEntity? _asEntity(String status) {
    final v = ref.read(visitEditProvider(widget.visitId));
    if (v == null) return null;
    final fullDate = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final vitals = json.encode({
      'bp': _bpCtrl.text, 'pulse': _pulCtrl.text, 'temp': _tmpCtrl.text,
      'spo2': _spo2Ctrl.text, 'weight': _wtCtrl.text, 'height': _htCtrl.text,
      'physical': _physCtrl.text, 'systemic': _sysCtrl.text,
    });
    final planParts = [
      if (_planCtrl.text.isNotEmpty) 'Treatment Plan: ${_planCtrl.text}',
      if (_medsCtrl.text.isNotEmpty) 'Medications: ${_medsCtrl.text}',
      if (_invCtrl.text.isNotEmpty)  'Investigations: ${_invCtrl.text}',
      if (_advCtrl.text.isNotEmpty)  'Advice: ${_advCtrl.text}',
      if (_fuCtrl.text.isNotEmpty)   'Follow-up: ${_fuCtrl.text}',
    ];
    return v.copyWith(
      visitDate:          fullDate,
      visitType:          VisitTypeX.fromValue(_visitTypeName),
      complaints:         _chips.join(', '),
      examination:        vitals,
      clinicalImpression: _diagCtrl.text.isEmpty ? null : _diagCtrl.text,
      plan:               planParts.isEmpty ? null : planParts.join('\n'),
      notes:              _historyCtrl.text.isEmpty ? null : _historyCtrl.text,
      status:             status,
    );
  }

  Future<void> _saveDraft() async {
    final e = _asEntity('draft');
    if (e == null) return;
    ref.read(visitEditProvider(widget.visitId).notifier).update(e);
    await ref.read(visitEditProvider(widget.visitId).notifier).save();
  }

  Future<void> _saveComplete() async {
    setState(() => _saving = true);
    try {
      final e = _asEntity('completed');
      if (e == null) return;
      ref.read(visitEditProvider(widget.visitId).notifier).update(e);
      final ok = await ref.read(visitEditProvider(widget.visitId).notifier).save();
      if (mounted) {
        if (ok) {
          context.pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Failed to save. Check your connection.'),
            backgroundColor: Colors.red,
          ));
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _next() { _saveDraft(); setState(() => _step++); }
  void _back() { if (_step == 0) context.pop(); else setState(() => _step--); }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final visit = ref.watch(visitEditProvider(widget.visitId));
    if (visit != null && !_loaded) {
      _loaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _populateFrom(visit); });
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(children: [
          _PremiumHeader(step: _step, onBack: _back),
          _PremiumStepBar(step: _step),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0.03, 0), end: Offset.zero).animate(anim),
                  child: child,
                ),
              ),
              child: KeyedSubtree(key: ValueKey(_step), child: _stepContent()),
            ),
          ),
          _PremiumBottomNav(step: _step, saving: _saving, onBack: _back, onNext: _next, onSave: _saveComplete),
        ]),
      ),
    );
  }

  Widget _stepContent() => switch (_step) {
    0 => _VStep1Patient(patientId: widget.patientId),
    1 => _VStep2Details(
        date: _date, time: _time, visitType: _visitTypeLabel,
        provider: _provider, department: _department,
        onDate: (d) => setState(() => _date = d),
        onTime: (t) => setState(() => _time = t),
        onType: (t) => setState(() => _visitTypeLabel = t),
        onProv: (p) => setState(() => _provider = p),
        onDept: (d) => setState(() => _department = d),
      ),
    2 => _VStep3Complaints(
        chips: _chips, chipCtrl: _chipCtrl, historyCtrl: _historyCtrl,
        onToggle: (c) => setState(() { if (_chips.contains(c)) _chips.remove(c); else _chips.add(c); }),
        onAdd:    (s) { if (s.trim().isNotEmpty) setState(() { _chips.add(s.trim()); _chipCtrl.clear(); }); },
        onRemove: (i) => setState(() => _chips.removeAt(i)),
      ),
    3 => _VStep4Vitals(
        bp: _bpCtrl, pulse: _pulCtrl, temp: _tmpCtrl, spo2: _spo2Ctrl,
        wt: _wtCtrl, ht: _htCtrl, phys: _physCtrl, sys: _sysCtrl,
      ),
    4 => _VStep5Diagnosis(
        diag: _diagCtrl, plan: _planCtrl, meds: _medsCtrl,
        inv: _invCtrl, adv: _advCtrl, fu: _fuCtrl,
      ),
    _ => _VStep6Review(
        patientId: widget.patientId,
        date: _date, time: _time, visitType: _visitTypeLabel,
        provider: _provider, department: _department,
        chips: List.unmodifiable(_chips), history: _historyCtrl.text,
        bp: _bpCtrl.text, pulse: _pulCtrl.text,
        temp: _tmpCtrl.text, spo2: _spo2Ctrl.text,
        wt: _wtCtrl.text, ht: _htCtrl.text,
        diag: _diagCtrl.text, plan: _planCtrl.text,
        meds: _medsCtrl.text, inv: _invCtrl.text,
        adv: _advCtrl.text, fu: _fuCtrl.text,
        onEdit: (s) => setState(() => _step = s),
      ),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium gradient header
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumHeader extends StatelessWidget {
  final int step;
  final VoidCallback onBack;
  const _PremiumHeader({required this.step, required this.onBack});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF6D28D9), Color(0xFF3B82F6)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
    child: Row(children: [
      IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 17),
        onPressed: onBack,
        padding: const EdgeInsets.all(8),
      ),
      const SizedBox(width: 2),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('OPD Consultation',
                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
            ),
            const SizedBox(width: 8),
            Text('Step ${step + 1} of 6',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 10)),
          ]),
          const SizedBox(height: 3),
          const Text('New Visit',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3)),
          Text(_kTitles[step],
              style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
        ]),
      ),
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.medical_services_outlined, color: Colors.white, size: 18),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium step bar with gradient circles
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumStepBar extends StatelessWidget {
  final int step;
  const _PremiumStepBar({required this.step});

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
    ),
    child: Row(
      children: List.generate(6, (i) {
        final done   = i < step;
        final active = i == step;
        return Expanded(
          child: Row(children: [
            if (i > 0) Expanded(child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: i <= step
                    ? const LinearGradient(colors: [_kP1, _kP2])
                    : null,
                color: i <= step ? null : _kBorder,
                borderRadius: BorderRadius.circular(1),
              ),
            )),
            _StepCircle(index: i, done: done, active: active),
            if (i < 5) Expanded(child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: i < step
                    ? const LinearGradient(colors: [_kP1, _kP2])
                    : null,
                color: i < step ? null : _kBorder,
                borderRadius: BorderRadius.circular(1),
              ),
            )),
          ]),
        );
      }),
    ),
  );
}

class _StepCircle extends StatelessWidget {
  final int index;
  final bool done, active;
  const _StepCircle({required this.index, required this.done, required this.active});

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: done || active
            ? const LinearGradient(colors: [_kP1, _kP2], begin: Alignment.topLeft, end: Alignment.bottomRight)
            : null,
        color: done || active ? null : Colors.white,
        border: Border.all(color: done || active ? Colors.transparent : _kBorder, width: 1.5),
        boxShadow: done || active
            ? [BoxShadow(color: _kP1.withValues(alpha: 0.28), blurRadius: 8, offset: const Offset(0, 3))]
            : [],
      ),
      alignment: Alignment.center,
      child: done
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
          : Text('${index + 1}', style: TextStyle(
              color: active ? Colors.white : _kMuted,
              fontWeight: FontWeight.w800, fontSize: 11)),
    ),
    const SizedBox(height: 3),
    Text(_kLabels[index], style: TextStyle(
      fontSize: 8,
      color: active ? _kP1 : done ? _kP2 : _kMuted,
      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
    )),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium bottom navigation
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumBottomNav extends StatelessWidget {
  final int step;
  final bool saving;
  final VoidCallback onBack, onNext, onSave;
  const _PremiumBottomNav({
    required this.step, required this.saving,
    required this.onBack, required this.onNext, required this.onSave,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: _kBorder)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, -2))],
    ),
    child: Row(children: [
      if (step > 0) ...[
        Expanded(
          child: OutlinedButton.icon(
            onPressed: saving ? null : onBack,
            icon: const Icon(Icons.arrow_back_ios_new, size: 13),
            label: const Text('Back'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kSlate,
              side: const BorderSide(color: _kBorder, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
      Expanded(
        flex: step > 0 ? 2 : 1,
        child: GestureDetector(
          onTap: saving ? null : (step == 5 ? onSave : onNext),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              gradient: step == 5
                  ? const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)])
                  : const LinearGradient(colors: [_kP1, _kP2]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (step == 5 ? _kGreen : _kP1).withValues(alpha: 0.3),
                  blurRadius: 14, offset: const Offset(0, 5),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(
                      step == 5 ? 'Save Visit' : 'Continue',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(width: 6),
                    Icon(step == 5 ? Icons.check_circle_outline : Icons.arrow_forward_ios,
                        color: Colors.white, size: step == 5 ? 18 : 13),
                  ]),
          ),
        ),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared card wrapper
// ─────────────────────────────────────────────────────────────────────────────
class _PCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget child;
  final Color? accent;
  const _PCard({this.title, this.icon, required this.child, this.accent});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _kBorder),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (title != null)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            if (icon != null) ...[
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [accent ?? _kP1, _kP2]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 10),
            ],
            Text(title!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kNavy)),
          ]),
        ),
      if (title != null) const SizedBox(height: 10),
      if (title != null) Divider(height: 1, color: _kBorder),
      Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ]),
  );
}

// Input decoration factory
InputDecoration _pDec(String hint, {IconData? prefix, Widget? suffix}) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: _kMuted, fontSize: 13),
  prefixIcon: prefix != null ? Icon(prefix, color: _kMuted, size: 18) : null,
  suffixIcon: suffix,
  filled: true, fillColor: _kBg,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBorder)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBorder)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kP1, width: 1.5)),
);

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kSlate)),
      if (required) const Text(' *', style: TextStyle(color: Colors.red, fontSize: 12)),
    ]),
  );
}

class _PDropdown<T> extends StatelessWidget {
  final T? value;
  final List<T> items;
  final String Function(T) label;
  final ValueChanged<T?> onChanged;
  final String? hint;
  final bool nullable;
  const _PDropdown({required this.value, required this.items, required this.label, required this.onChanged, this.hint, this.nullable = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: _kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _kBorder),
    ),
    child: DropdownButton<T>(
      value: value, isExpanded: true, underline: const SizedBox(),
      hint: hint != null ? Text(hint!, style: const TextStyle(color: _kMuted, fontSize: 13)) : null,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _kMuted, size: 20),
      style: const TextStyle(fontSize: 13, color: _kNavy, fontWeight: FontWeight.w500),
      items: [
        if (nullable) const DropdownMenuItem(value: null, child: Text('None')),
        ...items.map((i) => DropdownMenuItem(value: i, child: Text(label(i)))),
      ],
      onChanged: onChanged,
    ),
  );
}

class _TapField extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _TapField({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _kBorder)),
      child: Row(children: [
        Icon(icon, size: 16, color: _kP1),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13, color: _kNavy, fontWeight: FontWeight.w500)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 1: Select Patient
// ─────────────────────────────────────────────────────────────────────────────
class _VStep1Patient extends ConsumerWidget {
  final String patientId;
  const _VStep1Patient({required this.patientId});

  static const _avatarGrads = [
    [Color(0xFF7C3AED), Color(0xFF6D28D9)],
    [Color(0xFF2563EB), Color(0xFF3B82F6)],
    [Color(0xFF059669), Color(0xFF10B981)],
    [Color(0xFFDC2626), Color(0xFFEF4444)],
    [Color(0xFFD97706), Color(0xFFF59E0B)],
    [Color(0xFF0891B2), Color(0xFF06B6D4)],
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSelected = ref.watch(patientByIdProvider(patientId));
    final recent = ref.watch(patientsProvider).patients.take(6).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Search bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: TextField(
            readOnly: true,
            decoration: InputDecoration(
              hintText: 'Search by name, phone or UHID…',
              hintStyle: const TextStyle(color: _kMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: _kMuted, size: 20),
              suffixIcon: Container(
                margin: const EdgeInsets.all(6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kP1L, borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('⌘K', style: TextStyle(fontSize: 10, color: _kP1, fontWeight: FontWeight.w700)),
              ),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Selected patient
        asyncSelected.when(
          loading: () => const Center(heightFactor: 2, child: CircularProgressIndicator(color: _kP1, strokeWidth: 2)),
          error: (_, __) => const SizedBox(),
          data: (p) => p == null ? const SizedBox() : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _SectionLabel('Selected Patient'),
            const SizedBox(height: 8),
            _PatientCard(patient: p, selected: true, grads: _avatarGrads),
            const SizedBox(height: 14),
          ]),
        ),

        _SectionLabel('Recent Patients'),
        const SizedBox(height: 8),
        ...recent.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _PatientCard(patient: p, selected: p.id == patientId, grads: _avatarGrads),
        )),

        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => context.push('/patients/register'),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Register New Patient'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _kP1,
            side: const BorderSide(color: _kP1, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kMuted, letterSpacing: 0.8),
  );
}

class _PatientCard extends StatelessWidget {
  final PatientEntity patient;
  final bool selected;
  final List<List<Color>> grads;
  const _PatientCard({required this.patient, required this.selected, required this.grads});

  @override
  Widget build(BuildContext context) {
    final grad = grads[patient.id.hashCode.abs() % grads.length];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: selected ? _kP1L : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? _kP1 : _kBorder, width: selected ? 1.5 : 1),
        boxShadow: selected
            ? [BoxShadow(color: _kP1.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 3))]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(patient.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(patient.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _kNavy)),
            const SizedBox(height: 3),
            Row(children: [
              _MiniTag(patient.ageSex, grad[0]),
              const SizedBox(width: 5),
              _MiniTag('UHID: ${patient.prn}', _kMuted),
            ]),
          ]),
        ),
        if (selected)
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kP1, _kP2]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
          )
        else
          const Icon(Icons.chevron_right_rounded, color: _kMuted, size: 20),
      ]),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String text;
  final Color color;
  const _MiniTag(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
    child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 2: Visit Details
// ─────────────────────────────────────────────────────────────────────────────
class _VStep2Details extends StatelessWidget {
  final DateTime date;
  final TimeOfDay time;
  final String visitType, provider;
  final String? department;
  final ValueChanged<DateTime>  onDate;
  final ValueChanged<TimeOfDay> onTime;
  final ValueChanged<String>    onType, onProv;
  final ValueChanged<String?>   onDept;

  const _VStep2Details({
    required this.date, required this.time, required this.visitType,
    required this.provider, required this.department,
    required this.onDate, required this.onTime, required this.onType,
    required this.onProv, required this.onDept,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE, d MMM yyyy');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _PCard(
          title: 'Date & Time',
          icon: Icons.event_outlined,
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _FieldLabel('Visit Date', required: true),
              _TapField(
                icon: Icons.calendar_today_outlined,
                label: fmt.format(date),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context, initialDate: date,
                    firstDate: DateTime(2020), lastDate: DateTime(2030),
                    builder: (c, w) => Theme(
                      data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: _kP1)),
                      child: w!,
                    ),
                  );
                  if (d != null) onDate(d);
                },
              ),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _FieldLabel('Visit Time'),
              _TapField(
                icon: Icons.access_time_outlined,
                label: time.format(context),
                onTap: () async {
                  final t = await showTimePicker(
                    context: context, initialTime: time,
                    builder: (c, w) => Theme(
                      data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: _kP1)),
                      child: w!,
                    ),
                  );
                  if (t != null) onTime(t);
                },
              ),
            ])),
          ]),
        ),

        _PCard(
          title: 'Visit Type',
          icon: Icons.category_outlined,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _FieldLabel('Type', required: true),
            Row(children: _kVisitTypes.map((t) {
              final sel = visitType == t;
              return Expanded(child: Padding(
                padding: EdgeInsets.only(right: t != _kVisitTypes.last ? 8 : 0),
                child: GestureDetector(
                  onTap: () => onType(t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: sel ? const LinearGradient(colors: [_kP1, _kP2]) : null,
                      color: sel ? null : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sel ? Colors.transparent : _kBorder, width: sel ? 0 : 1),
                      boxShadow: sel ? [BoxShadow(color: _kP1.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))] : [],
                    ),
                    alignment: Alignment.center,
                    child: Text(t, style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : _kSlate,
                    ), textAlign: TextAlign.center),
                  ),
                ),
              ));
            }).toList()),
          ]),
        ),

        _PCard(
          title: 'Provider',
          icon: Icons.person_pin_outlined,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _FieldLabel('Doctor / Provider', required: true),
            _PDropdown<String>(
              value: provider, items: _kDoctors, label: (v) => v,
              onChanged: (v) { if (v != null) onProv(v); },
            ),
            const SizedBox(height: 14),
            const _FieldLabel('Department'),
            _PDropdown<String>(
              value: department, items: _kDepts, label: (v) => v,
              hint: 'Select department (optional)', nullable: true,
              onChanged: (v) => onDept(v),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 3: Chief Complaints
// ─────────────────────────────────────────────────────────────────────────────
class _VStep3Complaints extends StatelessWidget {
  final List<String> chips;
  final TextEditingController chipCtrl, historyCtrl;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onAdd;
  final ValueChanged<int>    onRemove;

  const _VStep3Complaints({
    required this.chips, required this.chipCtrl, required this.historyCtrl,
    required this.onToggle, required this.onAdd, required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      _PCard(
        title: 'Chief Complaints',
        icon: Icons.sick_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Custom entry
          Row(children: [
            Expanded(
              child: TextField(
                controller: chipCtrl,
                decoration: _pDec('Type a complaint and press +'),
                onSubmitted: onAdd,
                textInputAction: TextInputAction.done,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => onAdd(chipCtrl.text),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_kP1, _kP2]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: _kP1.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
              ),
            ),
          ]),

          // Added chips
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 7, runSpacing: 7, children: chips.asMap().entries.map((e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kP1, _kP2]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: _kP1.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(e.value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => onRemove(e.key),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                ),
              ]),
            )).toList()),
            Align(
              alignment: Alignment.centerRight,
              child: Text('${chips.length}/20', style: const TextStyle(fontSize: 10, color: _kMuted)),
            ),
          ],

          // Quick-add grid
          const SizedBox(height: 14),
          Row(children: [
            const Icon(Icons.flash_on_rounded, size: 13, color: _kAmber),
            const SizedBox(width: 4),
            const Text('QUICK ADD', style: TextStyle(fontSize: 10, color: _kMuted, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7, runSpacing: 7,
            children: _kQuickComplaints.map((c) {
              final sel = chips.contains(c);
              return GestureDetector(
                onTap: () => onToggle(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: sel ? const LinearGradient(colors: [_kP1, _kP2]) : null,
                    color: sel ? null : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? Colors.transparent : _kBorder),
                    boxShadow: sel ? [BoxShadow(color: _kP1.withValues(alpha: 0.2), blurRadius: 8)] : [],
                  ),
                  child: Text(c, style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : _kSlate,
                  )),
                ),
              );
            }).toList(),
          ),
        ]),
      ),

      _PCard(
        title: 'History & Notes',
        icon: Icons.notes_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _FieldLabel('History, observations, notes…'),
          TextField(
            controller: historyCtrl,
            decoration: _pDec('Add history, chief complaints history, notes…'),
            maxLines: 5, maxLength: 1000,
          ),
        ]),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 4: Vitals & Exam
// ─────────────────────────────────────────────────────────────────────────────
class _VStep4Vitals extends StatelessWidget {
  final TextEditingController bp, pulse, temp, spo2, wt, ht, phys, sys;
  const _VStep4Vitals({
    required this.bp, required this.pulse, required this.temp, required this.spo2,
    required this.wt, required this.ht, required this.phys, required this.sys,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      _PCard(
        title: 'Vitals',
        icon: Icons.monitor_heart_outlined,
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.75,
          children: [
            _VitalCard(label: 'Blood Pressure', unit: 'mmHg', hint: '120/80', ctrl: bp, icon: Icons.favorite_outline, color: _kP1, numOnly: false),
            _VitalCard(label: 'Pulse Rate', unit: 'bpm', hint: '72', ctrl: pulse, icon: Icons.monitor_heart_outlined, color: const Color(0xFFEF4444)),
            _VitalCard(label: 'Temperature', unit: '°F', hint: '98.6', ctrl: temp, icon: Icons.thermostat_outlined, color: _kAmber),
            _VitalCard(label: 'SpO2', unit: '%', hint: '98', ctrl: spo2, icon: Icons.air_outlined, color: _kP2),
            _VitalCard(label: 'Weight', unit: 'kg', hint: '70', ctrl: wt, icon: Icons.scale_outlined, color: _kGreen),
            _VitalCard(label: 'Height', unit: 'cm', hint: '170', ctrl: ht, icon: Icons.height_outlined, color: const Color(0xFF8B5CF6)),
          ],
        ),
      ),

      _PCard(
        title: 'Examination Findings',
        icon: Icons.document_scanner_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _FieldLabel('Physical Examination'),
          TextField(controller: phys, decoration: _pDec('General appearance, chest, abdomen…'), maxLines: 4),
          const SizedBox(height: 14),
          const _FieldLabel('Systemic Examination'),
          TextField(controller: sys, decoration: _pDec('CNS, CVS, respiratory, GIT…'), maxLines: 4),
        ]),
      ),
    ]),
  );
}

class _VitalCard extends StatelessWidget {
  final String label, unit, hint;
  final TextEditingController ctrl;
  final IconData icon;
  final Color color;
  final bool numOnly;
  const _VitalCard({
    required this.label, required this.unit, required this.hint,
    required this.ctrl, required this.icon, required this.color, this.numOnly = true,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _kBorder),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 12, color: color),
        ),
        const SizedBox(width: 5),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _kSlate), overflow: TextOverflow.ellipsis)),
        Text(unit, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
      ]),
      Expanded(
        child: TextField(
          controller: ctrl,
          keyboardType: numOnly ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 16, color: color.withValues(alpha: 0.2), fontWeight: FontWeight.w700),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 5: Diagnosis & Plan
// ─────────────────────────────────────────────────────────────────────────────
class _VStep5Diagnosis extends StatelessWidget {
  final TextEditingController diag, plan, meds, inv, adv, fu;
  const _VStep5Diagnosis({
    required this.diag, required this.plan, required this.meds,
    required this.inv, required this.adv, required this.fu,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      _PCard(
        title: 'Clinical Diagnosis',
        icon: Icons.biotech_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _FieldLabel('Diagnosis / ICD Code'),
          TextField(
            controller: diag,
            decoration: _pDec('Search ICD-10, enter diagnosis…',
                prefix: Icons.search_rounded,
                suffix: Container(
                  margin: const EdgeInsets.all(6),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: _kP1L, borderRadius: BorderRadius.circular(6)),
                  child: const Text('ICD', style: TextStyle(fontSize: 9, color: _kP1, fontWeight: FontWeight.w800)),
                )),
          ),
        ]),
      ),

      _PCard(
        title: 'Treatment Plan',
        icon: Icons.receipt_long_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _FieldLabel('Treatment Plan'),
          TextField(controller: plan, decoration: _pDec('Enter treatment plan, management…'), maxLines: 4, maxLength: 1000),
        ]),
      ),

      // Collapsible sections
      _CollapsibleCard(label: 'Medications', icon: Icons.medication_outlined, color: const Color(0xFF7C3AED), ctrl: meds, hint: 'Tab 1mg × OD × 5 days, Inj X mg IV…'),
      _CollapsibleCard(label: 'Investigations', icon: Icons.science_outlined, color: _kP2, ctrl: inv, hint: 'CBC, LFT, CT Brain, MRI Spine…'),
      _CollapsibleCard(label: 'Patient Advice', icon: Icons.info_outline_rounded, color: _kGreen, ctrl: adv, hint: 'Bed rest, diet, activity restrictions…'),
      _CollapsibleCard(label: 'Follow-up', icon: Icons.event_repeat_outlined, color: _kAmber, ctrl: fu, hint: 'Review after 1 week / PRN…'),
    ]),
  );
}

class _CollapsibleCard extends StatefulWidget {
  final String label, hint;
  final IconData icon;
  final Color color;
  final TextEditingController ctrl;
  const _CollapsibleCard({required this.label, required this.hint, required this.icon, required this.color, required this.ctrl});

  @override
  State<_CollapsibleCard> createState() => _CollapsibleCardState();
}

class _CollapsibleCardState extends State<_CollapsibleCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _open ? widget.color.withValues(alpha: 0.3) : _kBorder),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: Column(children: [
      InkWell(
        onTap: () => setState(() => _open = !_open),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(widget.icon, size: 14, color: widget.color),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _kNavy))),
            if (widget.ctrl.text.isNotEmpty)
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
              ),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: _open ? 0.25 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(_open ? Icons.remove_rounded : Icons.add_rounded, color: widget.color, size: 20),
            ),
          ]),
        ),
      ),
      AnimatedCrossFade(
        firstChild: const SizedBox(width: double.infinity),
        secondChild: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: TextField(
            controller: widget.ctrl,
            decoration: _pDec(widget.hint),
            maxLines: 3,
          ),
        ),
        crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        duration: const Duration(milliseconds: 200),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 6: Review & Save
// ─────────────────────────────────────────────────────────────────────────────
class _VStep6Review extends ConsumerWidget {
  final String patientId, visitType, provider;
  final String? department;
  final DateTime date;
  final TimeOfDay time;
  final List<String> chips;
  final String history, bp, pulse, temp, spo2, wt, ht;
  final String diag, plan, meds, inv, adv, fu;
  final ValueChanged<int> onEdit;

  const _VStep6Review({
    required this.patientId, required this.date, required this.time,
    required this.visitType, required this.provider, required this.department,
    required this.chips, required this.history,
    required this.bp, required this.pulse, required this.temp,
    required this.spo2, required this.wt, required this.ht,
    required this.diag, required this.plan,
    required this.meds, required this.inv, required this.adv, required this.fu,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPt  = ref.watch(patientByIdProvider(patientId));
    final fmt      = DateFormat('EEE, d MMM yyyy · h:mm a');
    final fullDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final vitals   = [
      if (bp.isNotEmpty)    'BP: $bp mmHg',
      if (pulse.isNotEmpty) 'Pulse: $pulse bpm',
      if (temp.isNotEmpty)  'Temp: $temp°F',
      if (spo2.isNotEmpty)  'SpO2: $spo2%',
      if (wt.isNotEmpty)    'Wt: $wt kg',
      if (ht.isNotEmpty)    'Ht: $ht cm',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Banner
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF6D28D9), _kP2]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.assignment_turned_in_outlined, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Review & Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                Text('Check all details before saving', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: const Text('Step 6/6', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),

        _ReviewCard(
          title: 'Patient & Visit',
          onEdit: () => onEdit(1),
          rows: [
            _RRow('Patient', asyncPt.valueOrNull?.fullName ?? '—'),
            _RRow('Visit Type', visitType),
            _RRow('Provider', provider),
            if (department != null) _RRow('Department', department!),
            _RRow('Date & Time', fmt.format(fullDate)),
          ],
        ),

        if (chips.isNotEmpty || history.isNotEmpty)
          _ReviewCard(
            title: 'Chief Complaints',
            onEdit: () => onEdit(2),
            rows: [
              if (chips.isNotEmpty) _RRow('Complaints', chips.join(', ')),
              if (history.isNotEmpty) _RRow('History', history),
            ],
          ),

        if (vitals.isNotEmpty)
          _ReviewCard(
            title: 'Vitals',
            onEdit: () => onEdit(3),
            rows: vitals.map((v) {
              final parts = v.split(': ');
              return _RRow(parts[0], parts.length > 1 ? parts[1] : v);
            }).toList(),
          ),

        if (diag.isNotEmpty || plan.isNotEmpty || meds.isNotEmpty)
          _ReviewCard(
            title: 'Diagnosis & Plan',
            onEdit: () => onEdit(4),
            rows: [
              if (diag.isNotEmpty) _RRow('Diagnosis', diag),
              if (plan.isNotEmpty) _RRow('Treatment Plan', plan),
              if (meds.isNotEmpty) _RRow('Medications', meds),
              if (inv.isNotEmpty)  _RRow('Investigations', inv),
              if (adv.isNotEmpty)  _RRow('Advice', adv),
              if (fu.isNotEmpty)   _RRow('Follow-up', fu),
            ],
          ),
      ]),
    );
  }
}

class _RRow {
  final String k, v;
  const _RRow(this.k, this.v);
}

class _ReviewCard extends StatelessWidget {
  final String title;
  final VoidCallback onEdit;
  final List<_RRow> rows;
  const _ReviewCard({required this.title, required this.onEdit, required this.rows});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _kBorder),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 0),
        child: Row(children: [
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _kMuted, letterSpacing: 0.8)),
          const Spacer(),
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 13),
            label: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(foregroundColor: _kP1, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
          ),
        ]),
      ),
      const Divider(height: 8, color: _kBorder),
      ...rows.map((r) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 110,
            child: Text(r.k, style: const TextStyle(fontSize: 12, color: _kMuted, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(r.v, style: const TextStyle(fontSize: 13, color: _kNavy, fontWeight: FontWeight.w600))),
        ]),
      )),
      const SizedBox(height: 6),
    ]),
  );
}

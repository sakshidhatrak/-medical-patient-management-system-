// ─────────────────────────────────────────────────────────────────────────────
// surgery_form_screen.dart  –  6-step Operative Note wizard
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../patients/domain/entities/patient_entity.dart';
import '../../../patients/presentation/providers/patient_provider.dart';
import '../../domain/entities/surgery_entity.dart';
import '../providers/surgery_provider.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _kRed   = Color(0xFFDC2626);
const _kRedL  = Color(0xFFFEE2E2);
const _kBg    = Color(0xFFF8FAFC);
const _kText2 = Color(0xFF475569);
const _kGrey  = Color(0xFF94A3B8);
const _kLine  = Color(0xFFE2E8F0);

const _kSLabels = ['Patient', 'Details', 'Preop', 'Intraop', 'Postop', 'Review'];
const _kSTitles = [
  'Select Patient', 'Surgery Details', 'Preoperative',
  'Intraoperative', 'Postoperative', 'Review & Save',
];

const _kSurgeons    = ['Dr. Harshal S. Chaudhari', 'Dr. Ananya Sharma', 'Dr. Rohit Verma'];
const _kProcedures  = [
  'Craniotomy', 'Laminectomy', 'Discectomy', 'VP Shunt', 'Microdiscectomy',
  'Spinal Fusion', 'Decompression', 'Tumour Excision', 'Other',
];
const _kAnesthesia  = ['General Anesthesia', 'Spinal', 'Epidural', 'Local', 'MAC'];
const _kConditions  = ['Stable', 'Critical', 'Guarded', 'Fair', 'Good'];
const _kInvestigations = ['CBC', 'LFT', 'RFT', 'Coagulation Profile', 'Blood Group', 'CT Scan', 'MRI', 'USG', 'X-Ray', 'ECG'];

// ─────────────────────────────────────────────────────────────────────────────
// Main screen
// ─────────────────────────────────────────────────────────────────────────────
class SurgeryFormScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String surgeryId;
  const SurgeryFormScreen({super.key, required this.patientId, required this.surgeryId});

  @override
  ConsumerState<SurgeryFormScreen> createState() => _SFState();
}

class _SFState extends ConsumerState<SurgeryFormScreen> {
  int  _step   = 0;
  bool _saving = false;
  bool _loaded = false;

  // ── Step 2: Surgery Details ───────────────────────────────────────
  late DateTime  _date;
  late TimeOfDay _time;
  String  _surgeon    = _kSurgeons.first;
  String  _procedure  = _kProcedures.first;
  String  _anesthesia = _kAnesthesia.first;
  final TextEditingController _assistantCtrl    = TextEditingController();
  final TextEditingController _anesthCtrl       = TextEditingController();

  // ── Step 3: Preoperative ─────────────────────────────────────────
  final TextEditingController _preopDiagCtrl    = TextEditingController();
  final TextEditingController _preopNotesCtrl   = TextEditingController();

  // ── Step 4: Intraoperative ───────────────────────────────────────
  final TextEditingController _opFindingsCtrl   = TextEditingController();
  final TextEditingController _procedureCtrl    = TextEditingController();
  final List<String> _investigations            = [];
  final TextEditingController _eblCtrl          = TextEditingController();
  String? _specimens;

  // ── Step 5: Postoperative ────────────────────────────────────────
  bool _sameAsPreop = false;
  final TextEditingController _postDiagCtrl     = TextEditingController();
  final TextEditingController _complicationsCtrl = TextEditingController();
  final TextEditingController _postNotesCtrl    = TextEditingController();
  String _condition = _kConditions.first;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = now;
    _time = TimeOfDay.fromDateTime(now);
  }

  @override
  void dispose() {
    for (final c in [
      _assistantCtrl, _anesthCtrl,
      _preopDiagCtrl, _preopNotesCtrl,
      _opFindingsCtrl, _procedureCtrl, _eblCtrl,
      _postDiagCtrl, _complicationsCtrl, _postNotesCtrl,
    ]) c.dispose();
    super.dispose();
  }

  void _populateFrom(SurgeryEntity s) {
    _date = s.surgeryDate;
    _time = TimeOfDay.fromDateTime(s.surgeryDate);
    if (s.primarySurgeon?.isNotEmpty == true) _surgeon = s.primarySurgeon!;
    if (s.procedure?.isNotEmpty == true) {
      _procedure = _kProcedures.contains(s.procedure) ? s.procedure! : 'Other';
    }
    if (s.anesthesiaType?.isNotEmpty == true) {
      _anesthesia = _kAnesthesia.contains(s.anesthesiaType) ? s.anesthesiaType! : _kAnesthesia.first;
    }
    _assistantCtrl.text  = s.assistantSurgeons ?? '';
    _anesthCtrl.text     = s.anesthesiologist  ?? '';
    _preopDiagCtrl.text  = s.preOpDiagnosis    ?? '';
    _preopNotesCtrl.text = s.otNotes           ?? '';
    _opFindingsCtrl.text = s.intraopFindings   ?? '';

    // Decode implants JSON for intraop extras
    if (s.implants?.isNotEmpty == true) {
      try {
        final m = json.decode(s.implants!) as Map<String, dynamic>;
        _procedureCtrl.text = (m['procedureSteps'] as String?) ?? '';
        _eblCtrl.text       = (m['ebl']            as String?) ?? '';
        _specimens          = m['specimens'] as String?;
        final inv           = m['investigations'] as List<dynamic>?;
        if (inv != null) {
          _investigations.clear();
          _investigations.addAll(inv.cast<String>());
        }
      } catch (_) {
        _procedureCtrl.text = s.implants!;
      }
    }

    // Decode postOpPlan JSON
    if (s.postOpPlan?.isNotEmpty == true) {
      try {
        final m = json.decode(s.postOpPlan!) as Map<String, dynamic>;
        _sameAsPreop            = m['sameAsPreop'] == true;
        _postDiagCtrl.text      = (m['postopDiag'] as String?) ?? '';
        _complicationsCtrl.text = s.complications               ?? '';
        _postNotesCtrl.text     = (m['notes']       as String?) ?? '';
        final cond = m['condition'] as String?;
        if (cond != null && _kConditions.contains(cond)) _condition = cond;
      } catch (_) {
        _postNotesCtrl.text = s.postOpPlan!;
        _complicationsCtrl.text = s.complications ?? '';
      }
    } else {
      _complicationsCtrl.text = s.complications ?? '';
    }
    setState(() {});
  }

  SurgeryEntity? _asEntity(String status) {
    final s = ref.read(surgeryEditProvider(widget.surgeryId));
    if (s == null) return null;
    final fullDate = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final intraopExtras = json.encode({
      'procedureSteps': _procedureCtrl.text,
      'ebl':            _eblCtrl.text,
      'specimens':      _specimens,
      'investigations': _investigations,
    });
    final postopData = json.encode({
      'sameAsPreop': _sameAsPreop,
      'postopDiag':  _sameAsPreop ? _preopDiagCtrl.text : _postDiagCtrl.text,
      'notes':       _postNotesCtrl.text,
      'condition':   _condition,
    });
    return s.copyWith(
      surgeryDate:      fullDate,
      primarySurgeon:   _surgeon,
      procedure:        _procedure,
      assistantSurgeons: _assistantCtrl.text.isEmpty ? null : _assistantCtrl.text,
      anesthesiaType:   _anesthesia,
      anesthesiologist: _anesthCtrl.text.isEmpty ? null : _anesthCtrl.text,
      preOpDiagnosis:   _preopDiagCtrl.text.isEmpty ? null : _preopDiagCtrl.text,
      otNotes:          _preopNotesCtrl.text.isEmpty ? null : _preopNotesCtrl.text,
      intraopFindings:  _opFindingsCtrl.text.isEmpty ? null : _opFindingsCtrl.text,
      implants:         intraopExtras,
      complications:    _complicationsCtrl.text.isEmpty ? null : _complicationsCtrl.text,
      postOpPlan:       postopData,
      status:           status,
    );
  }

  Future<void> _saveDraft() async {
    final e = _asEntity('draft');
    if (e == null) return;
    ref.read(surgeryEditProvider(widget.surgeryId).notifier).update(e);
    await ref.read(surgeryEditProvider(widget.surgeryId).notifier).save();
  }

  Future<void> _saveComplete() async {
    setState(() => _saving = true);
    try {
      final e = _asEntity('completed');
      if (e == null) return;
      ref.read(surgeryEditProvider(widget.surgeryId).notifier).update(e);
      final ok = await ref.read(surgeryEditProvider(widget.surgeryId).notifier).save();
      if (mounted) {
        if (ok) {
          context.pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save. Check connection.'), backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _next() { _saveDraft(); setState(() => _step++); }
  void _back() { if (_step == 0) context.pop(); else setState(() => _step--); }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final surgery = ref.watch(surgeryEditProvider(widget.surgeryId));
    if (surgery != null && !_loaded) {
      _loaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _populateFrom(surgery); });
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildStepBar(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(anim),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(key: ValueKey(_step), child: _stepContent()),
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
    color: _kRed,
    padding: const EdgeInsets.fromLTRB(4, 8, 14, 8),
    child: Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          onPressed: _back,
          padding: const EdgeInsets.all(8),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New Surgery',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              Text('Step ${_step + 1} of 6  ·  ${_kSTitles[_step]}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ),
        const Icon(Icons.search, color: Colors.white70, size: 22),
      ],
    ),
  );

  Widget _buildStepBar() => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
    child: Row(
      children: List.generate(6, (i) {
        final done   = i < _step;
        final active = i == _step;
        return Expanded(
          child: Row(
            children: [
              if (i > 0) Expanded(child: Container(height: 1.5, color: i <= _step ? _kRed : _kLine)),
              _SWizStepCircle(index: i, done: done, active: active, label: _kSLabels[i]),
              if (i < 5) Expanded(child: Container(height: 1.5, color: i < _step ? _kRed : _kLine)),
            ],
          ),
        );
      }),
    ),
  );

  Widget _stepContent() => switch (_step) {
    0 => _SStep1Patient(patientId: widget.patientId),
    1 => _SStep2Details(
        date: _date, time: _time, surgeon: _surgeon, procedure: _procedure, anesthesia: _anesthesia,
        assistantCtrl: _assistantCtrl, anesthCtrl: _anesthCtrl,
        onDate:      (d) => setState(() => _date = d),
        onTime:      (t) => setState(() => _time = t),
        onSurgeon:   (v) => setState(() => _surgeon = v),
        onProcedure: (v) => setState(() => _procedure = v),
        onAnesthesia:(v) => setState(() => _anesthesia = v),
      ),
    2 => _SStep3Preop(diagCtrl: _preopDiagCtrl, notesCtrl: _preopNotesCtrl),
    3 => _SStep4Intraop(
        findingsCtrl: _opFindingsCtrl, procedureCtrl: _procedureCtrl,
        eblCtrl: _eblCtrl,
        investigations: _investigations,
        specimens: _specimens,
        onInvToggle: (inv) => setState(() {
          if (_investigations.contains(inv)) _investigations.remove(inv);
          else _investigations.add(inv);
        }),
        onSpecimens: (s) => setState(() => _specimens = s),
      ),
    4 => _SStep5Postop(
        sameAsPreop: _sameAsPreop,
        postDiagCtrl: _postDiagCtrl,
        complicationsCtrl: _complicationsCtrl,
        postNotesCtrl: _postNotesCtrl,
        condition: _condition,
        onSameToggle: (v) => setState(() => _sameAsPreop = v),
        onCondition:  (v) => setState(() => _condition = v),
      ),
    _ => _SStep6Review(
        patientId: widget.patientId,
        date: _date, time: _time,
        surgeon: _surgeon, procedure: _procedure, anesthesia: _anesthesia,
        assistant: _assistantCtrl.text,
        preopDiag: _preopDiagCtrl.text,
        findings: _opFindingsCtrl.text,
        ebl: _eblCtrl.text,
        investigations: List.unmodifiable(_investigations),
        condition: _condition,
        complications: _complicationsCtrl.text,
        onEdit: (s) => setState(() => _step = s),
      ),
  };

  Widget _buildBottomNav() => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
    decoration: const BoxDecoration(
      color: Colors.white, border: Border(top: BorderSide(color: _kLine)),
    ),
    child: Row(
      children: [
        if (_step > 0) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : _back,
              style: OutlinedButton.styleFrom(
                foregroundColor: _kText2,
                side: const BorderSide(color: _kLine),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Back', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: ElevatedButton(
            onPressed: _saving ? null : (_step == 5 ? _saveComplete : _next),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_step == 5 ? 'Save Surgery' : 'Next',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared surgery primitives
// ─────────────────────────────────────────────────────────────────────────────
class _SWizStepCircle extends StatelessWidget {
  final int index;
  final bool done, active;
  final String label;
  const _SWizStepCircle({required this.index, required this.done, required this.active, required this.label});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done || active ? _kRed : Colors.white,
          border: Border.all(color: done || active ? _kRed : _kLine, width: 1.5),
        ),
        alignment: Alignment.center,
        child: done
            ? const Icon(Icons.check, color: Colors.white, size: 14)
            : Text('${index + 1}', style: TextStyle(
                color: active ? Colors.white : _kGrey,
                fontWeight: FontWeight.w700, fontSize: 11)),
      ),
      const SizedBox(height: 3),
      Text(label, style: TextStyle(
          fontSize: 8,
          color: active ? _kRed : _kGrey,
          fontWeight: active ? FontWeight.w700 : FontWeight.normal)),
    ],
  );
}

class _SWizCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SWizCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _kLine),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(title.toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: _kGrey, letterSpacing: 0.8)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: child,
        ),
      ],
    ),
  );
}

class _SWizLabel extends StatelessWidget {
  final String text;
  final bool req;
  const _SWizLabel(this.text, {this.req = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kText2)),
      if (req) const Text(' *', style: TextStyle(color: Colors.red, fontSize: 13)),
    ]),
  );
}

InputDecoration _sDec(String hint, {Widget? suffix}) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: _kGrey, fontSize: 13),
  suffixIcon: suffix,
  filled: true, fillColor: _kBg,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kLine)),
  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kLine)),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _kRed, width: 1.5)),
);

class _SWizDropdown<T> extends StatelessWidget {
  final T? value;
  final List<T> items;
  final String Function(T) label;
  final ValueChanged<T?> onChanged;
  final String? hint;
  const _SWizDropdown({
    required this.value, required this.items,
    required this.label, required this.onChanged, this.hint,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: _kBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _kLine),
    ),
    child: DropdownButton<T>(
      value: value, isExpanded: true, underline: const SizedBox(),
      hint: hint != null ? Text(hint!, style: const TextStyle(color: _kGrey, fontSize: 13)) : null,
      icon: const Icon(Icons.keyboard_arrow_down, color: _kGrey),
      style: const TextStyle(fontSize: 13, color: Color(0xFF37474F)),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(label(i)))).toList(),
      onChanged: onChanged,
    ),
  );
}

class _STappableField extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _STappableField({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _kBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _kLine),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: _kGrey),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF37474F))),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 1 – Select Patient
// ─────────────────────────────────────────────────────────────────────────────
class _SStep1Patient extends ConsumerWidget {
  final String patientId;
  const _SStep1Patient({required this.patientId});

  static const _colors = [
    Color(0xFF1565C0), Color(0xFF00695C), Color(0xFF6A1B9A),
    Color(0xFFE65100), Color(0xFFC62828), Color(0xFF00838F),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSelected = ref.watch(patientByIdProvider(patientId));
    final recent = ref.watch(patientsProvider).patients.take(6).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            readOnly: true,
            decoration: InputDecoration(
              hintText: 'Search by name, phone or UHID',
              hintStyle: const TextStyle(color: _kGrey, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: _kGrey, size: 20),
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kLine)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kLine)),
            ),
          ),
          const SizedBox(height: 16),

          asyncSelected.when(
            loading: () => const Center(heightFactor: 2, child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox(),
            data: (p) => p == null ? const SizedBox() : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Selected Patient',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kText2, letterSpacing: 0.3)),
                const SizedBox(height: 8),
                _SPatientCard(patient: p, selected: true, colors: _colors),
                const SizedBox(height: 16),
              ],
            ),
          ),

          const Text('Recent Patients',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kText2, letterSpacing: 0.3)),
          const SizedBox(height: 8),
          ...recent.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SPatientCard(patient: p, selected: p.id == patientId, colors: _colors),
          )),

          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => context.push('/patients/register'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add New Patient'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kRed,
              side: const BorderSide(color: _kRed),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SPatientCard extends StatelessWidget {
  final PatientEntity patient;
  final bool selected;
  final List<Color> colors;
  const _SPatientCard({required this.patient, required this.selected, required this.colors});

  @override
  Widget build(BuildContext context) {
    final color = colors[patient.id.hashCode.abs() % colors.length];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: selected ? _kRedL : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? _kRed : _kLine, width: selected ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(patient.initials,
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patient.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1A1A2E))),
                const SizedBox(height: 2),
                Text('${patient.ageSex}  ·  UHID: ${patient.prn}',
                    style: const TextStyle(color: _kGrey, fontSize: 11)),
              ],
            ),
          ),
          if (selected) const Icon(Icons.check_circle_rounded, color: _kRed, size: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 2 – Surgery Details
// ─────────────────────────────────────────────────────────────────────────────
class _SStep2Details extends StatelessWidget {
  final DateTime date;
  final TimeOfDay time;
  final String surgeon, procedure, anesthesia;
  final TextEditingController assistantCtrl, anesthCtrl;
  final ValueChanged<DateTime>  onDate;
  final ValueChanged<TimeOfDay> onTime;
  final ValueChanged<String>    onSurgeon, onProcedure, onAnesthesia;

  const _SStep2Details({
    required this.date, required this.time,
    required this.surgeon, required this.procedure, required this.anesthesia,
    required this.assistantCtrl, required this.anesthCtrl,
    required this.onDate, required this.onTime,
    required this.onSurgeon, required this.onProcedure, required this.onAnesthesia,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _SWizCard(
            title: 'Surgery Date & Time',
            child: Row(
              children: [
                Expanded(
                  child: _STappableField(
                    icon: Icons.calendar_today_outlined,
                    label: fmt.format(date),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2020), lastDate: DateTime(2030),
                        builder: (c, w) => Theme(
                          data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: _kRed)),
                          child: w!,
                        ),
                      );
                      if (d != null) onDate(d);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _STappableField(
                    icon: Icons.access_time_outlined,
                    label: time.format(context),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context, initialTime: time,
                        builder: (c, w) => Theme(
                          data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: _kRed)),
                          child: w!,
                        ),
                      );
                      if (t != null) onTime(t);
                    },
                  ),
                ),
              ],
            ),
          ),

          _SWizCard(
            title: 'Surgeon & Procedure',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SWizLabel('Surgeon', req: true),
                _SWizDropdown<String>(
                  value: surgeon, items: _kSurgeons, label: (v) => v,
                  onChanged: (v) { if (v != null) onSurgeon(v); },
                ),
                const SizedBox(height: 14),
                const _SWizLabel('Procedure / Surgery', req: true),
                _SWizDropdown<String>(
                  value: procedure, items: _kProcedures, label: (v) => v,
                  onChanged: (v) { if (v != null) onProcedure(v); },
                ),
                const SizedBox(height: 14),
                const _SWizLabel('Assistant (Optional)'),
                TextField(
                  controller: assistantCtrl,
                  decoration: _sDec('Dr. Name'),
                ),
              ],
            ),
          ),

          _SWizCard(
            title: 'Anaesthesia',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SWizLabel('Anesthesia Type', req: true),
                _SWizDropdown<String>(
                  value: anesthesia, items: _kAnesthesia, label: (v) => v,
                  onChanged: (v) { if (v != null) onAnesthesia(v); },
                ),
                const SizedBox(height: 14),
                const _SWizLabel('Anesthesiologist (Optional)'),
                TextField(
                  controller: anesthCtrl,
                  decoration: _sDec('Dr. Name'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 3 – Preoperative
// ─────────────────────────────────────────────────────────────────────────────
class _SStep3Preop extends StatelessWidget {
  final TextEditingController diagCtrl, notesCtrl;
  const _SStep3Preop({required this.diagCtrl, required this.notesCtrl});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        _SWizCard(
          title: 'Preoperative Diagnosis',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SWizLabel('Preoperative Diagnosis', req: true),
              TextField(
                controller: diagCtrl,
                decoration: _sDec('Enter diagnosis or ICD code...',
                    suffix: const Icon(Icons.search, color: _kGrey, size: 20)),
              ),
            ],
          ),
        ),

        _SWizCard(
          title: 'Notes',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SWizLabel('Preoperative Notes'),
              TextField(
                controller: notesCtrl,
                decoration: _sDec('Enter preoperative notes...'),
                maxLines: 5, maxLength: 1000,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 4 – Intraoperative
// ─────────────────────────────────────────────────────────────────────────────
class _SStep4Intraop extends StatelessWidget {
  final TextEditingController findingsCtrl, procedureCtrl, eblCtrl;
  final List<String> investigations;
  final String? specimens;
  final ValueChanged<String>  onInvToggle;
  final ValueChanged<String?> onSpecimens;

  const _SStep4Intraop({
    required this.findingsCtrl, required this.procedureCtrl, required this.eblCtrl,
    required this.investigations, required this.specimens,
    required this.onInvToggle, required this.onSpecimens,
  });

  static const _specimenOpts = ['None', 'Biopsy', 'Fluid', 'Calculus', 'Tumour', 'Other'];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        _SWizCard(
          title: 'Operative Findings',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SWizLabel('Operative Findings', req: true),
              TextField(
                controller: findingsCtrl,
                decoration: _sDec('Enter operative findings...'),
                maxLines: 5, maxLength: 1500,
              ),
            ],
          ),
        ),

        _SWizCard(
          title: 'Procedure Performed',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SWizLabel('Procedure Performed', req: true),
              TextField(
                controller: procedureCtrl,
                decoration: _sDec('Describe procedure step by step...'),
                maxLines: 5, maxLength: 3000,
              ),
            ],
          ),
        ),

        _SWizCard(
          title: 'Investigations Reviewed',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...List.generate(3, (row) {
                return Row(
                  children: List.generate(3, (col) {
                    final idx = row * 3 + col;
                    if (idx >= _kInvestigations.length) return const Expanded(child: SizedBox());
                    final inv = _kInvestigations[idx];
                    return Expanded(
                      child: CheckboxListTile(
                        value: investigations.contains(inv),
                        onChanged: (_) => onInvToggle(inv),
                        title: Text(inv, style: const TextStyle(fontSize: 12)),
                        activeColor: _kRed,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    );
                  }),
                );
              }),
            ],
          ),
        ),

        _SWizCard(
          title: 'EBL & Specimens',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SWizLabel('Estimated Blood Loss (ml)'),
                    TextField(
                      controller: eblCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _sDec('50'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SWizLabel('Specimens Sent'),
                    _SWizDropdown<String>(
                      value: specimens,
                      items: _specimenOpts,
                      label: (v) => v,
                      hint: 'Select',
                      onChanged: (v) => onSpecimens(v),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 5 – Postoperative
// ─────────────────────────────────────────────────────────────────────────────
class _SStep5Postop extends StatelessWidget {
  final bool sameAsPreop;
  final TextEditingController postDiagCtrl, complicationsCtrl, postNotesCtrl;
  final String condition;
  final ValueChanged<bool>   onSameToggle;
  final ValueChanged<String> onCondition;

  const _SStep5Postop({
    required this.sameAsPreop,
    required this.postDiagCtrl, required this.complicationsCtrl, required this.postNotesCtrl,
    required this.condition,
    required this.onSameToggle, required this.onCondition,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        _SWizCard(
          title: 'Postoperative Diagnosis',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Same as preoperative',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kText2)),
                  ),
                  Switch(
                    value: sameAsPreop,
                    onChanged: onSameToggle,
                    activeColor: _kRed,
                  ),
                ],
              ),
              if (!sameAsPreop) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: postDiagCtrl,
                  decoration: _sDec('Enter postoperative diagnosis...'),
                ),
              ],
            ],
          ),
        ),

        _SWizCard(
          title: 'Complications',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SWizLabel('Complications (if any)'),
              TextField(
                controller: complicationsCtrl,
                decoration: _sDec('Enter complications...'),
                maxLines: 3,
              ),
            ],
          ),
        ),

        _SWizCard(
          title: 'Postoperative Notes & Outcome',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SWizLabel('Postoperative Notes'),
              TextField(
                controller: postNotesCtrl,
                decoration: _sDec('Enter postoperative notes...'),
                maxLines: 4, maxLength: 1000,
              ),
              const SizedBox(height: 10),
              const _SWizLabel('Condition'),
              _SWizDropdown<String>(
                value: condition, items: _kConditions, label: (v) => v,
                onChanged: (v) { if (v != null) onCondition(v); },
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 6 – Review & Save
// ─────────────────────────────────────────────────────────────────────────────
class _SStep6Review extends ConsumerWidget {
  final String patientId;
  final DateTime date;
  final TimeOfDay time;
  final String surgeon, procedure, anesthesia, assistant;
  final String preopDiag, findings, ebl, condition, complications;
  final List<String> investigations;
  final ValueChanged<int> onEdit;

  const _SStep6Review({
    required this.patientId, required this.date, required this.time,
    required this.surgeon, required this.procedure, required this.anesthesia,
    required this.assistant, required this.preopDiag,
    required this.findings, required this.ebl,
    required this.investigations, required this.condition,
    required this.complications, required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPt  = ref.watch(patientByIdProvider(patientId));
    final fmt      = DateFormat('d MMM yyyy, h:mm a');
    final fullDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: _kRedL, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kRed.withOpacity(0.35)),
            ),
            child: const Row(
              children: [
                Icon(Icons.assignment_turned_in_outlined, color: _kRed, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Review Surgery Note before saving.',
                      style: TextStyle(color: _kRed, fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ],
            ),
          ),

          _SReviewCard(title: 'Patient & Surgery', onEdit: () => onEdit(1), rows: [
            _SRRow('Patient',    asyncPt.valueOrNull?.fullName ?? '—'),
            _SRRow('Procedure',  procedure),
            _SRRow('Surgeon',    surgeon),
            if (assistant.isNotEmpty) _SRRow('Assistant', assistant),
            _SRRow('Anesthesia', anesthesia),
            _SRRow('Date & Time', fmt.format(fullDate)),
          ]),

          if (preopDiag.isNotEmpty)
            _SReviewCard(title: 'Preoperative', onEdit: () => onEdit(2), rows: [
              _SRRow('Diagnosis', preopDiag),
            ]),

          _SReviewCard(title: 'Intraoperative', onEdit: () => onEdit(3), rows: [
            if (findings.isNotEmpty) _SRRow('Findings', findings),
            if (investigations.isNotEmpty) _SRRow('Investigations', investigations.join(', ')),
            if (ebl.isNotEmpty) _SRRow('EBL', '$ebl ml'),
          ]),

          _SReviewCard(title: 'Postoperative', onEdit: () => onEdit(4), rows: [
            if (complications.isNotEmpty) _SRRow('Complications', complications),
            _SRRow('Condition', condition),
          ]),
        ],
      ),
    );
  }
}

class _SReviewCard extends StatelessWidget {
  final String title;
  final VoidCallback onEdit;
  final List<_SRRow> rows;
  const _SReviewCard({required this.title, required this.onEdit, required this.rows});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: _kLine),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
          child: Row(children: [
            Text(title.toUpperCase(),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: _kGrey, letterSpacing: 0.8)),
            const Spacer(),
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 14),
              label: const Text('Edit', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(foregroundColor: _kRed),
            ),
          ]),
        ),
        const Divider(height: 1, color: _kLine),
        ...rows.map((r) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(r.k, style: const TextStyle(fontSize: 12, color: _kGrey, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(r.v,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF37474F), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        )),
        const SizedBox(height: 6),
      ],
    ),
  );
}

class _SRRow {
  final String k, v;
  const _SRRow(this.k, this.v);
}

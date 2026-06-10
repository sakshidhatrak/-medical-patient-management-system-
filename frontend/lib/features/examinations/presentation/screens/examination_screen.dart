import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/examination_entity.dart';

// ── Provider ────────────────────────────────────────────────────────

final examinationProvider = StateNotifierProvider.family<
    ExaminationNotifier, ExaminationEntity?, String>((ref, visitId) =>
    ExaminationNotifier(visitId));

class ExaminationNotifier
    extends StateNotifier<ExaminationEntity?> {
  final String visitId;
  ExaminationNotifier(this.visitId) : super(null) {
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await sb.Supabase.instance.client
          .from('examinations')
          .select()
          .eq('visit_id', visitId)
          .maybeSingle();
      if (data != null) {
        final motorList = (data['motor_data'] as List<dynamic>?)
                ?.map((e) => MotorEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        state = ExaminationEntity(
          id: data['id'] as String,
          visitId: visitId,
          patientId: data['patient_id'] as String,
          generalText:       data['general_text']        as String?,
          motorText:         data['motor_text']          as String?,
          sensoryText:       data['sensory_text']        as String?,
          reflexesText:      data['reflexes_text']       as String?,
          cerebellarText:    data['cerebellar_text']     as String?,
          specialTestsText:  data['special_tests_text']  as String?,
          motorData:         motorList,
          createdAt: DateTime.parse(data['created_at'] as String),
          updatedAt: DateTime.parse(data['updated_at'] as String),
        );
      }
    } catch (_) {}
  }

  void update(ExaminationEntity exam) => state = exam;

  Future<bool> save(String patientId) async {
    try {
      final payload = {
        'patient_id':        patientId,
        'visit_id':          visitId,
        'general_text':      state?.generalText,
        'motor_text':        state?.motorText,
        'sensory_text':      state?.sensoryText,
        'reflexes_text':     state?.reflexesText,
        'cerebellar_text':   state?.cerebellarText,
        'special_tests_text': state?.specialTestsText,
        'motor_data': state?.motorData.map((m) => m.toJson()).toList() ?? [],
      };
      if (state == null) {
        final id = const Uuid().v4();
        await sb.Supabase.instance.client
            .from('examinations')
            .insert({...payload, 'id': id});
      } else {
        await sb.Supabase.instance.client
            .from('examinations')
            .update(payload)
            .eq('id', state!.id);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ── Screen ──────────────────────────────────────────────────────────

class ExaminationScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String visitId;
  const ExaminationScreen(
      {super.key, required this.patientId, required this.visitId});

  @override
  ConsumerState<ExaminationScreen> createState() =>
      _ExaminationScreenState();
}

class _ExaminationScreenState extends ConsumerState<ExaminationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  final _generalCtrl    = TextEditingController();
  final _motorCtrl      = TextEditingController();
  final _sensoryCtrl    = TextEditingController();
  final _reflexesCtrl   = TextEditingController();
  final _cerebellarCtrl = TextEditingController();
  final _specialCtrl    = TextEditingController();

  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
  }

  void _apply(ExaminationEntity e) {
    _generalCtrl.text    = e.generalText ?? '';
    _motorCtrl.text      = e.motorText ?? '';
    _sensoryCtrl.text    = e.sensoryText ?? '';
    _reflexesCtrl.text   = e.reflexesText ?? '';
    _cerebellarCtrl.text = e.cerebellarText ?? '';
    _specialCtrl.text    = e.specialTestsText ?? '';
    _loaded = true;
  }

  ExaminationEntity _buildEntity(ExaminationEntity? existing) {
    final t = DateTime.now();
    return ExaminationEntity(
      id:               existing?.id ?? '',
      visitId:          widget.visitId,
      patientId:        widget.patientId,
      generalText:      _v(_generalCtrl),
      motorText:        _v(_motorCtrl),
      sensoryText:      _v(_sensoryCtrl),
      reflexesText:     _v(_reflexesCtrl),
      cerebellarText:   _v(_cerebellarCtrl),
      specialTestsText: _v(_specialCtrl),
      motorData:        existing?.motorData ?? [],
      createdAt:        existing?.createdAt ?? t,
      updatedAt:        t,
    );
  }

  String? _v(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in [
      _generalCtrl, _motorCtrl, _sensoryCtrl,
      _reflexesCtrl, _cerebellarCtrl, _specialCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exam = ref.watch(examinationProvider(widget.visitId));
    if (exam != null && !_loaded) _apply(exam);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('CNS Examination',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () async {
              ref
                  .read(examinationProvider(widget.visitId).notifier)
                  .update(_buildEntity(exam));
              final ok = await ref
                  .read(examinationProvider(widget.visitId).notifier)
                  .save(widget.patientId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(ok ? 'Saved' : 'Save failed'),
                  backgroundColor: ok ? Colors.green : Colors.red,
                ));
              }
            },
            child: const Text('Save'),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'General'),
            Tab(text: 'Motor'),
            Tab(text: 'Sensory'),
            Tab(text: 'Reflexes'),
            Tab(text: 'Cerebellar'),
            Tab(text: 'Special'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ExamTab(
            hint: 'General condition, built, nourishment, pallor, '
                'icterus, vitals...',
            controller: _generalCtrl,
          ),
          _MotorTab(
            freeTextCtrl: _motorCtrl,
            motorData: exam?.motorData ?? [],
            onMotorDataChanged: (data) {
              final updated = _buildEntity(exam).copyWith(motorData: data);
              ref
                  .read(examinationProvider(widget.visitId).notifier)
                  .update(updated);
              final generated = data
                  .where((e) => e.generatedText.isNotEmpty)
                  .map((e) => e.generatedText)
                  .join('. ');
              if (generated.isNotEmpty && _motorCtrl.text.isEmpty) {
                setState(() => _motorCtrl.text = generated);
              }
            },
          ),
          _ExamTab(
            hint: 'Pain sensation, touch sensation, dermatome-wise...',
            controller: _sensoryCtrl,
          ),
          _ExamTab(
            hint: 'DTRs: Biceps, Triceps, Supinator, Knee, Ankle\n'
                'Plantar: Right — Left\nHoffmann: Right — Left',
            controller: _reflexesCtrl,
            quickInserts: const [
              'DTRs normal bilaterally',
              'Plantars: B/L flexor',
              'Plantars: B/L extensor',
              'Right plantar extensor',
              'Left plantar extensor',
              'Hoffmann positive B/L',
            ],
          ),
          _ExamTab(
            hint: 'Finger-nose test, heel-shin test, tandem gait, '
                'Romberg sign...',
            controller: _cerebellarCtrl,
            quickInserts: const [
              'Cerebellar signs absent',
              'Positive finger-nose test',
              'Romberg positive',
              'Dysdiadochokinesia present',
            ],
          ),
          _ExamTab(
            hint: 'Spurling test, SLR, SLUMP, Barre-Lieou...',
            controller: _specialCtrl,
          ),
        ],
      ),
    );
  }
}

class _ExamTab extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final List<String>? quickInserts;
  const _ExamTab(
      {required this.hint,
      required this.controller,
      this.quickInserts});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (quickInserts != null) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: quickInserts!
                      .map((q) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActionChip(
                              label: Text(q,
                                  style: const TextStyle(fontSize: 11)),
                              onPressed: () {
                                final cur = controller.text;
                                controller.text =
                                    cur.isEmpty ? q : '$cur\n$q';
                              },
                              backgroundColor:
                                  AppColors.primary.withOpacity(0.08),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle:
                      TextStyle(color: Colors.grey[400], fontSize: 13),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),
          ],
        ),
      );
}

// ── Structured Motor Tab ─────────────────────────────────────────

class _MotorTab extends StatefulWidget {
  final TextEditingController freeTextCtrl;
  final List<MotorEntry> motorData;
  final ValueChanged<List<MotorEntry>> onMotorDataChanged;
  const _MotorTab({
    required this.freeTextCtrl,
    required this.motorData,
    required this.onMotorDataChanged,
  });

  @override
  State<_MotorTab> createState() => _MotorTabState();
}

class _MotorTabState extends State<_MotorTab> {
  late List<MotorEntry> _entries;
  bool _showStructured = false;

  static const _joints = [
    'Shoulder abduction',
    'Elbow flexion',
    'Elbow extension',
    'Wrist extension',
    'Grip',
    'Finger abduction',
    'Hip flexion',
    'Knee extension',
    'Ankle dorsiflexion',
    'Great toe extension',
  ];

  static const _grading = [
    '0/5', '1/5', '2/5', '3/5', '4/5', '5/5',
  ];

  @override
  void initState() {
    super.initState();
    _entries = List.of(widget.motorData);
    if (_entries.isEmpty) {
      _entries = _joints
          .map((j) => MotorEntry(joint: j, right: '5/5', left: '5/5'))
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Text('Free text:',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _showStructured = !_showStructured),
                  icon: Icon(
                      _showStructured ? Icons.text_fields : Icons.table_rows,
                      size: 16),
                  label: Text(_showStructured ? 'Free text' : 'Structured'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (!_showStructured)
              Expanded(
                child: TextField(
                  controller: widget.freeTextCtrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    hintText: 'Motor examination findings...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(14),
                  ),
                ),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    // Header
                    Row(
                      children: [
                        const Expanded(
                            flex: 3,
                            child: Text('Joint',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                        const Expanded(
                            child: Text('Right',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                        const SizedBox(width: 8),
                        const Expanded(
                            child: Text('Left',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _entries.length,
                        itemBuilder: (ctx, i) {
                          final e = _entries[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                    flex: 3,
                                    child: Text(e.joint,
                                        style: const TextStyle(
                                            fontSize: 12))),
                                Expanded(
                                  child: _GradeDropdown(
                                    value: e.right,
                                    onChanged: (v) {
                                      setState(() {
                                        _entries[i] = MotorEntry(
                                            joint: e.joint,
                                            right: v,
                                            left: e.left);
                                        widget.onMotorDataChanged(
                                            _entries);
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _GradeDropdown(
                                    value: e.left,
                                    onChanged: (v) {
                                      setState(() {
                                        _entries[i] = MotorEntry(
                                            joint: e.joint,
                                            right: e.right,
                                            left: v);
                                        widget.onMotorDataChanged(
                                            _entries);
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        final generated = _entries
                            .where((e) => e.generatedText.isNotEmpty)
                            .map((e) => e.generatedText)
                            .join('. ');
                        if (generated.isNotEmpty) {
                          widget.freeTextCtrl.text = generated;
                          setState(() => _showStructured = false);
                        }
                      },
                      icon: const Icon(Icons.auto_fix_high, size: 16),
                      label: const Text('Generate text from table'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}

class _GradeDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  static const _grades = ['0/5','1/5','2/5','3/5','4/5','5/5'];

  const _GradeDropdown({this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          isExpanded: true,
          underline: const SizedBox(),
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          items: _grades
              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
              .toList(),
          onChanged: onChanged,
        ),
      );
}

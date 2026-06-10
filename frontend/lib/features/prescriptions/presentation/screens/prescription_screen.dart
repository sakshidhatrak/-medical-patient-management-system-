import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/prescription_entity.dart';

// ── Providers ──────────────────────────────────────────────────────

final drugsMasterProvider = FutureProvider<List<DrugMaster>>((ref) async {
  final data = await sb.Supabase.instance.client
      .from('drugs_master')
      .select()
      .eq('is_active', true)
      .order('generic_name');
  return (data as List)
      .map((e) => DrugMaster.fromJson(e as Map<String, dynamic>))
      .toList();
});

final prescriptionProvider =
    StateNotifierProvider.family<PrescriptionNotifier, PrescriptionEntity?,
        String>((ref, visitId) => PrescriptionNotifier(visitId));

class PrescriptionNotifier
    extends StateNotifier<PrescriptionEntity?> {
  final String visitId;
  PrescriptionNotifier(this.visitId) : super(null) {
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await sb.Supabase.instance.client
          .from('prescriptions')
          .select()
          .eq('visit_id', visitId)
          .maybeSingle();
      if (data != null) {
        final drugs = (data['drugs'] as List<dynamic>?)
                ?.map((e) => DrugEntry.fromJson(
                    e is String ? {} : e as Map<String, dynamic>))
                .toList() ??
            [];
        state = PrescriptionEntity(
          id: data['id'] as String,
          patientId: data['patient_id'] as String,
          visitId: visitId,
          text: data['text'] as String?,
          drugs: drugs,
          createdAt: DateTime.parse(data['created_at'] as String),
          updatedAt: DateTime.parse(data['updated_at'] as String),
        );
      }
    } catch (_) {}
  }

  void updateText(String text) {
    if (state == null) return;
    state = state!.copyWith(text: text);
  }

  void addDrug(DrugEntry drug) {
    if (state == null) return;
    state = state!.copyWith(drugs: [...state!.drugs, drug]);
  }

  void removeDrug(String id) {
    if (state == null) return;
    state =
        state!.copyWith(drugs: state!.drugs.where((d) => d.id != id).toList());
  }

  Future<bool> save(String patientId) async {
    try {
      final drugs =
          state?.drugs.map((d) => d.toJson()).toList() ?? [];
      final payload = {
        'patient_id': patientId,
        'visit_id': visitId,
        'text': state?.text,
        'drugs': drugs,
      };
      if (state == null) {
        final id = const Uuid().v4();
        final data = await sb.Supabase.instance.client
            .from('prescriptions')
            .insert({...payload, 'id': id})
            .select()
            .single();
        state = PrescriptionEntity(
          id: data['id'] as String,
          patientId: patientId,
          visitId: visitId,
          text: state?.text,
          drugs: state?.drugs ?? [],
          createdAt: DateTime.parse(data['created_at'] as String),
          updatedAt: DateTime.parse(data['updated_at'] as String),
        );
      } else {
        await sb.Supabase.instance.client
            .from('prescriptions')
            .update(payload)
            .eq('id', state!.id);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ── Screen ─────────────────────────────────────────────────────────

class PrescriptionScreen extends ConsumerStatefulWidget {
  final String patientId;
  final String visitId;
  const PrescriptionScreen(
      {super.key, required this.patientId, required this.visitId});

  @override
  ConsumerState<PrescriptionScreen> createState() =>
      _PrescriptionScreenState();
}

class _PrescriptionScreenState
    extends ConsumerState<PrescriptionScreen> {
  final _textCtrl = TextEditingController();
  bool _showDrugPanel = false;

  @override
  Widget build(BuildContext context) {
    final prescription = ref.watch(prescriptionProvider(widget.visitId));
    final drugsAsync   = ref.watch(drugsMasterProvider);

    if (prescription != null &&
        _textCtrl.text.isEmpty &&
        prescription.text?.isNotEmpty == true) {
      _textCtrl.text = prescription.text!;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── Free text ─────────────────────────────────────
          Expanded(
            flex: 3,
            child: TextField(
              controller: _textCtrl,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              onChanged: (v) =>
                  ref.read(prescriptionProvider(widget.visitId).notifier)
                      .updateText(v),
              decoration: InputDecoration(
                hintText:
                    'Type prescription here...\nor use Add Drug below',
                hintStyle:
                    TextStyle(color: Colors.grey[400], fontSize: 14),
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

          const SizedBox(height: 8),

          // ── Structured drugs ──────────────────────────────
          if (prescription?.drugs.isNotEmpty == true) ...[
            Expanded(
              flex: 2,
              child: _DrugList(
                drugs: prescription!.drugs,
                onRemove: (id) => ref
                    .read(prescriptionProvider(widget.visitId).notifier)
                    .removeDrug(id),
              ),
            ),
          ],

          // ── Actions ───────────────────────────────────────
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _showDrugPanel = !_showDrugPanel),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Drug'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final ok = await ref
                        .read(prescriptionProvider(widget.visitId).notifier)
                        .save(widget.patientId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok ? 'Rx saved' : 'Save failed'),
                        backgroundColor: ok ? Colors.green : Colors.red,
                      ));
                    }
                  },
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('Save Rx'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                ),
              ),
            ],
          ),

          // ── Drug picker panel ─────────────────────────────
          if (_showDrugPanel)
            drugsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (drugs) => _DrugPickerPanel(
                drugs: drugs,
                onAdd: (drug) {
                  ref
                      .read(prescriptionProvider(widget.visitId).notifier)
                      .addDrug(drug);
                  setState(() => _showDrugPanel = false);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DrugList extends StatelessWidget {
  final List<DrugEntry> drugs;
  final ValueChanged<String> onRemove;
  const _DrugList({required this.drugs, required this.onRemove});

  @override
  Widget build(BuildContext context) => ListView.builder(
        itemCount: drugs.length,
        itemBuilder: (ctx, i) {
          final d = drugs[i];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Color(0xFFE8E8E8)),
            ),
            child: ListTile(
              dense: true,
              title: Text(d.displayName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: Text(d.displayDosage,
                  style: const TextStyle(fontSize: 12)),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline,
                    color: Colors.red, size: 18),
                onPressed: () => onRemove(d.id),
              ),
            ),
          );
        },
      );
}

class _DrugPickerPanel extends StatefulWidget {
  final List<DrugMaster> drugs;
  final ValueChanged<DrugEntry> onAdd;
  const _DrugPickerPanel({required this.drugs, required this.onAdd});

  @override
  State<_DrugPickerPanel> createState() => _DrugPickerPanelState();
}

class _DrugPickerPanelState extends State<_DrugPickerPanel> {
  String _search = '';
  DrugMaster? _selected;
  final _doseCtrl = TextEditingController();
  final _freqCtrl = TextEditingController();
  final _durCtrl  = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final filtered = widget.drugs
        .where((d) =>
            d.genericName.toLowerCase().contains(_search.toLowerCase()) ||
            d.brandNames.any((b) =>
                b.toLowerCase().contains(_search.toLowerCase())))
        .toList();

    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: const InputDecoration(
              hintText: 'Search drug...',
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
          const SizedBox(height: 8),
          if (_selected == null)
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final d = filtered[i];
                  return ListTile(
                    dense: true,
                    title: Text(d.genericName,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(d.brandNames.take(2).join(', '),
                        style: const TextStyle(fontSize: 11)),
                    onTap: () {
                      setState(() {
                        _selected = d;
                        _doseCtrl.text = d.defaultDose ?? '';
                        _freqCtrl.text = d.defaultFrequency ?? '';
                        _durCtrl.text  = d.defaultDuration ?? '';
                      });
                    },
                  );
                },
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  Text(_selected!.genericName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                          child: _SmallField(
                              label: 'Dose', ctrl: _doseCtrl)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _SmallField(
                              label: 'Frequency', ctrl: _freqCtrl)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _SmallField(
                              label: 'Duration', ctrl: _durCtrl)),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      TextButton(
                          onPressed: () =>
                              setState(() => _selected = null),
                          child: const Text('Back')),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          widget.onAdd(DrugEntry(
                            id: const Uuid().v4(),
                            genericName: _selected!.genericName,
                            brandName: _selected!.brandNames.isNotEmpty
                                ? _selected!.brandNames.first
                                : null,
                            composition: _selected!.composition,
                            dose: _doseCtrl.text.trim().isEmpty
                                ? null
                                : _doseCtrl.text.trim(),
                            frequency: _freqCtrl.text.trim().isEmpty
                                ? null
                                : _freqCtrl.text.trim(),
                            duration: _durCtrl.text.trim().isEmpty
                                ? null
                                : _durCtrl.text.trim(),
                          ));
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary),
                        child: const Text('Add',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SmallField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  const _SmallField({required this.label, required this.ctrl});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          TextField(
            controller: ctrl,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(),
            ),
          ),
        ],
      );
}

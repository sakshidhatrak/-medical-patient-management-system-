import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/sync/sync_engine.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/prescription_entity.dart';

// ── Providers ──────────────────────────────────────────────────────

final drugsMasterProvider = FutureProvider<List<DrugMaster>>((ref) async {
  final localCache = ref.read(localDrugCacheProvider);
  final online = ref.read(isOnlineProvider);

  if (online) {
    try {
      final drugs = await ref.read(apiClientProvider).get<List<DrugMaster>>(
        '/drugs',
        fromJson: (json) {
          final list =
              (json as Map<String, dynamic>)['data'] as List<dynamic>;
          return list
              .map((e) => DrugMaster.fromApiJson(e as Map<String, dynamic>))
              .toList();
        },
      );
      // Cache for offline use.
      if (!kIsWeb) {
        await localCache.upsertAll(
            drugs.map((d) => _drugMasterToJson(d)).toList());
      }
      return drugs;
    } catch (_) {}
  }

  // Offline fallback.
  if (!kIsWeb) {
    final rows = await localCache.getAll();
    if (rows.isNotEmpty) {
      return rows
          .map((r) => DrugMaster.fromApiJson(r))
          .toList();
    }
  }
  return [];
});

Map<String, dynamic> _drugMasterToJson(DrugMaster d) => {
      'id': d.id,
      'genericName': d.genericName,
      'brandNames': d.brandNames.join(','),
      'composition': d.composition,
      'category': d.category,
      'defaultDose': d.defaultDose,
      'defaultFrequency': d.defaultFrequency,
      'defaultDuration': d.defaultDuration,
    };

// arg: "patientId/visitId"
final prescriptionProvider = StateNotifierProvider.family<
    PrescriptionNotifier, PrescriptionEntity?, String>((ref, arg) =>
    PrescriptionNotifier(
      arg,
      ref.read(apiClientProvider),
      ref.read(localPrescriptionCacheProvider),
      ref.read(offlineQueueProvider),
      ref.read(isOnlineProvider),
    ));

class PrescriptionNotifier extends StateNotifier<PrescriptionEntity?> {
  final String _arg;
  final ApiClient _api;
  final LocalPrescriptionCache _local;
  final OfflineQueue _queue;
  final bool _online;

  PrescriptionNotifier(
      this._arg, this._api, this._local, this._queue, this._online)
      : super(null) {
    _load();
  }

  String get _patientId => _arg.split('/')[0];
  String get _visitId =>
      _arg.split('/').length > 1 ? _arg.split('/')[1] : _arg;

  PrescriptionEntity _fromDto(Map<String, dynamic> data) {
    final drugsStr = data['drugs'] as String?;
    final drugs = drugsStr != null && drugsStr.isNotEmpty
        ? (jsonDecode(drugsStr) as List<dynamic>)
            .map((e) => DrugEntry.fromJson(
                e is String ? {} : e as Map<String, dynamic>))
            .toList()
        : <DrugEntry>[];
    final now = DateTime.now().toIso8601String();
    return PrescriptionEntity(
      id: data['id'] != null ? (data['id'] as Object).toString() : '',
      patientId: _patientId,
      visitId: _visitId,
      text: data['text'] as String?,
      drugs: drugs,
      createdAt:
          DateTime.parse((data['createdAt'] ?? now) as String),
      updatedAt:
          DateTime.parse((data['updatedAt'] ?? now) as String),
    );
  }

  Future<void> _load() async {
    // 1. Load from local cache.
    if (!kIsWeb) {
      try {
        final cached = await _local.getForVisit(_visitId);
        if (cached != null) state = _fromDto(cached);
      } catch (_) {}
    }

    // 2. Sync from API.
    if (_online) {
      try {
        final list = await _api.get<List<dynamic>>(
          '/patients/$_patientId/visits/$_visitId/prescriptions',
          fromJson: (json) =>
              (json as Map<String, dynamic>)['data'] as List<dynamic>,
        );
        if (list.isNotEmpty) {
          final data = list.first as Map<String, dynamic>;
          state = _fromDto(data);
          if (!kIsWeb) await _local.upsert(_visitId, _patientId, data);
        }
      } catch (_) {}
    }
  }

  void update(PrescriptionEntity entity) => state = entity;

  void updateText(String text) {
    if (state == null) {
      state = PrescriptionEntity(
        id: '',
        patientId: _patientId,
        visitId: _visitId,
        text: text,
        drugs: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      return;
    }
    state = state!.copyWith(text: text);
  }

  void addDrug(DrugEntry drug) {
    if (state == null) {
      state = PrescriptionEntity(
        id: '',
        patientId: _patientId,
        visitId: _visitId,
        text: null,
        drugs: [drug],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      return;
    }
    state = state!.copyWith(drugs: [...state!.drugs, drug]);
  }

  void removeDrug(String id) {
    if (state == null) return;
    state = state!
        .copyWith(drugs: state!.drugs.where((d) => d.id != id).toList());
  }

  Future<bool> save(String patientId) async {
    final drugsJson = jsonEncode(
        state?.drugs.map((d) => d.toJson()).toList() ?? []);
    final payload = {'text': state?.text, 'drugs': drugsJson};
    final isNew = state == null || state!.id.isEmpty;

    // Save locally first.
    if (!kIsWeb) {
      final localData = {
        ...payload,
        'id': state?.id ?? '',
        'patientId': _patientId,
        'visitId': _visitId,
        'createdAt': state?.createdAt.toIso8601String() ??
            DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await _local.upsert(_visitId, _patientId, localData);
    }

    if (_online) {
      try {
        final Map<String, dynamic> data;
        if (isNew) {
          data = await _api.post<Map<String, dynamic>>(
            '/patients/$_patientId/visits/$_visitId/prescriptions',
            data: payload,
            fromJson: (json) => (json as Map<String, dynamic>)['data']
                as Map<String, dynamic>,
          );
        } else {
          data = await _api.put<Map<String, dynamic>>(
            '/prescriptions/${state!.id}',
            data: payload,
            fromJson: (json) => (json as Map<String, dynamic>)['data']
                as Map<String, dynamic>,
          );
        }
        state = _fromDto(data);
        if (!kIsWeb) await _local.upsert(_visitId, _patientId, data);
        return true;
      } catch (_) {}
    }

    // Offline: enqueue.
    if (!kIsWeb) {
      await _queue.enqueue(
        entityType: 'prescriptions',
        entityId: _visitId,
        operation: isNew ? 'insert' : 'update',
        payload: {
          ...payload,
          'id': state?.id ?? '',
          'patientId': _patientId,
          'visitId': _visitId,
        },
      );
    }
    return true;
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
    final prescription = ref.watch(prescriptionProvider('${widget.patientId}/${widget.visitId}'));
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
                  ref.read(prescriptionProvider('${widget.patientId}/${widget.visitId}').notifier)
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
                    .read(prescriptionProvider('${widget.patientId}/${widget.visitId}').notifier)
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
                        .read(prescriptionProvider('${widget.patientId}/${widget.visitId}').notifier)
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
                      .read(prescriptionProvider('${widget.patientId}/${widget.visitId}').notifier)
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

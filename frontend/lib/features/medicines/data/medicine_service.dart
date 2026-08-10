import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/sync/sync_engine.dart';
import 'medicine_master.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class MedicineSuggestion {
  final String name;
  final String? defaultDose;
  final String? frequency;
  final String? category;

  // non-null = came from patient's past visit
  final String? visitDateLabel;
  final bool isHistory;

  const MedicineSuggestion({
    required this.name,
    this.defaultDose,
    this.frequency,
    this.category,
    this.visitDateLabel,
    this.isHistory = false,
  });

  String get subtitle {
    if (isHistory && visitDateLabel != null) {
      return 'Prescribed · $visitDateLabel';
    }
    final parts = [defaultDose, frequency].where((e) => e?.isNotEmpty == true);
    return parts.isNotEmpty ? parts.join(' · ') : (category ?? 'Master list');
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

class MedicineService {
  final LocalPrescriptionCache _prescriptions;
  final LocalDrugCache _drugs;
  final ApiClient _api;

  MedicineService(this._prescriptions, this._drugs, this._api);

  // Seed master list into drugs_cache on first run.
  Future<void> seedMasterIfEmpty() async {
    if (kIsWeb) return;
    try {
      final hasData = await _drugs.hasCache();
      if (!hasData) {
        await _drugs.upsertAll(kMedicineMasterList.map((m) => {...m}).toList());
      }
    } catch (_) {}
  }

  // Fetch the live drug list from the backend and refresh drugs_cache.
  // Called after login so the doctor can manage drugs from the backend
  // without an APK update. Silently ignores errors (offline / cold start).
  Future<void> syncDrugsFromApi() async {
    if (kIsWeb) return;
    try {
      final resp = await _api.get<Map<String, dynamic>>('/drugs');
      final data = resp['data'];
      if (data is! List || data.isEmpty) return;
      final drugs = data.whereType<Map<String, dynamic>>().map<Map<String, dynamic>>((d) => {
            'id': d['id'].toString(),
            'genericName': (d['genericName'] ?? '') as String,
            'brandNames': (d['brandNames'] ?? '') as String,
            'defaultDose': (d['defaultDose'] ?? '') as String,
            'defaultFrequency': (d['defaultFrequency'] ?? '') as String,
            'defaultDuration': (d['defaultDuration'] ?? '') as String,
            'category': (d['category'] ?? '') as String,
          }).toList();
      // Clear first so hardcoded-seed IDs don't cause duplicates.
      await _drugs.clearAll();
      await _drugs.upsertAll(drugs);
    } catch (_) {
      // Silent — keep using hardcoded / previously cached list
    }
  }

  // Get autocomplete suggestions for [query], prioritising patient history.
  Future<List<MedicineSuggestion>> getSuggestions({
    required String query,
    required String patientId,
    int limit = 12,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return [];

    final histSuggestions = await _patientHistorySuggestions(patientId, q);
    final masterSuggestions = await _masterSuggestions(
      q,
      exclude: histSuggestions.map((s) => s.name.toLowerCase()).toSet(),
      limit: limit - histSuggestions.length,
    );

    return [...histSuggestions, ...masterSuggestions];
  }

  // Save medicines text to local prescriptions cache for this visit.
  Future<void> savePrescription({
    required String visitId,
    required String patientId,
    required DateTime visitDate,
    required String medicationsText,
  }) async {
    if (kIsWeb) return;
    if (medicationsText.trim().isEmpty) return;
    try {
      await _prescriptions.upsert(visitId, patientId, {
        'text': medicationsText.trim(),
        'visitDate': visitDate.toIso8601String().split('T').first,
        'drugs': <Map<String, dynamic>>[],
      });
    } catch (_) {}
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<List<MedicineSuggestion>> _patientHistorySuggestions(
      String patientId, String q) async {
    if (kIsWeb) return [];
    try {
      final rows = await _prescriptions.getAllForPatient(patientId);
      final seen = <String>{};
      final result = <MedicineSuggestion>[];

      for (final row in rows) {
        final text = row['text'] as String? ?? '';
        final visitDate = row['visitDate'] as String? ??
            row['_updatedAt'] as String? ?? '';
        final dateLabel = _formatDateLabel(visitDate);

        // Parse medicines: one per line, also try splitting by common delimiters.
        final medicines = _parseMedicineText(text);
        for (final med in medicines) {
          final nameLower = med.toLowerCase();
          if (nameLower.contains(q) && seen.add(nameLower)) {
            result.add(MedicineSuggestion(
              name: med,
              visitDateLabel: dateLabel,
              isHistory: true,
            ));
          }
        }

        // Also check structured drugs list if present.
        final drugsRaw = row['drugs'];
        if (drugsRaw is List) {
          for (final d in drugsRaw) {
            if (d is! Map) continue;
            final gn = (d['generic_name'] ?? d['genericName'] ?? '') as String;
            final bn = (d['brand_name'] ?? d['brandName'] ?? '') as String;
            for (final name in [gn, bn]) {
              if (name.isEmpty) continue;
              final nl = name.toLowerCase();
              if (nl.contains(q) && seen.add(nl)) {
                result.add(MedicineSuggestion(
                  name: name,
                  visitDateLabel: dateLabel,
                  isHistory: true,
                ));
              }
            }
          }
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<List<MedicineSuggestion>> _masterSuggestions(
      String q, {required Set<String> exclude, int limit = 8}) async {
    if (kIsWeb) return _masterSuggestionsFromConst(q, exclude: exclude, limit: limit);
    try {
      final all = await _drugs.getAll();
      if (all.isEmpty) {
        // Fallback to in-memory list.
        return _masterSuggestionsFromConst(q, exclude: exclude, limit: limit);
      }
      final result = <MedicineSuggestion>[];
      for (final m in all) {
        if (result.length >= limit) break;
        final name = (m['genericName'] ?? m['generic_name'] ?? '') as String;
        if (name.isEmpty) continue;
        if (!name.toLowerCase().contains(q)) continue;
        if (exclude.contains(name.toLowerCase())) continue;
        result.add(MedicineSuggestion(
          name: name,
          defaultDose: m['defaultDose'] as String?,
          frequency: m['defaultFrequency'] as String?,
          category: m['category'] as String?,
          isHistory: false,
        ));
      }
      return result;
    } catch (_) {
      return _masterSuggestionsFromConst(q, exclude: exclude, limit: limit);
    }
  }

  List<MedicineSuggestion> _masterSuggestionsFromConst(
      String q, {required Set<String> exclude, int limit = 8}) {
    final result = <MedicineSuggestion>[];
    for (final m in kMedicineMasterList) {
      if (result.length >= limit) break;
      final name = m['genericName'] ?? '';
      if (!name.toLowerCase().contains(q)) continue;
      if (exclude.contains(name.toLowerCase())) continue;
      result.add(MedicineSuggestion(
        name: name,
        defaultDose: m['defaultDose'],
        frequency: m['defaultFrequency'],
        category: m['category'],
        isHistory: false,
      ));
    }
    return result;
  }

  List<String> _parseMedicineText(String text) {
    // Split on newlines first, then on common delimiters.
    final lines = text.split('\n');
    final result = <String>[];
    for (final line in lines) {
      final parts = line.split(RegExp(r'[·,;]+'));
      for (final part in parts) {
        final trimmed = part.trim();
        if (trimmed.isNotEmpty) result.add(trimmed);
      }
    }
    return result;
  }

  String _formatDateLabel(String rawDate) {
    if (rawDate.isEmpty) return '';
    try {
      final dt = DateTime.parse(rawDate);
      return DateFormat('d MMM yyyy').format(dt);
    } catch (_) {
      return rawDate.length > 10 ? rawDate.substring(0, 10) : rawDate;
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final medicineServiceProvider = Provider<MedicineService>((ref) {
  final svc = MedicineService(
    ref.watch(localPrescriptionCacheProvider),
    ref.watch(localDrugCacheProvider),
    ref.watch(apiClientProvider),
  );
  svc.seedMasterIfEmpty();
  return svc;
});

// Family provider: (patientId, query) → suggestions list.
final medicineSuggestionsProvider =
    FutureProvider.family<List<MedicineSuggestion>, ({String patientId, String query})>(
  (ref, args) => ref
      .read(medicineServiceProvider)
      .getSuggestions(patientId: args.patientId, query: args.query),
);

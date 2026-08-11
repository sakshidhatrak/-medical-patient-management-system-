import 'dart:convert';

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
  final LocalPatientCache _patients;
  final LocalDrugCache _drugs;
  final LocalVisitCache _visits;
  final ApiClient _api;

  MedicineService(this._prescriptions, this._patients, this._drugs, this._visits, this._api);

  // Seed master list into drugs_cache. Uses INSERT OR IGNORE so existing
  // API-synced entries are never overwritten, but the table always has at
  // least the built-in medicine list as a fallback after login.
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
      // Support both camelCase and snake_case keys from the backend.
      final drugs = data.whereType<Map<String, dynamic>>().map<Map<String, dynamic>>((d) => {
            'id': (d['id'] ?? '').toString(),
            'genericName': (d['genericName'] ?? d['generic_name'] ?? '') as String,
            'brandNames': (d['brandNames'] ?? d['brand_names'] ?? '') as String,
            'defaultDose': (d['defaultDose'] ?? d['default_dose'] ?? '') as String,
            'defaultFrequency': (d['defaultFrequency'] ?? d['default_frequency'] ?? '') as String,
            'defaultDuration': (d['defaultDuration'] ?? d['default_duration'] ?? '') as String,
            'category': (d['category'] ?? '') as String,
          }).toList();
      // Only replace the cache if there are drugs with valid names — prevents
      // a bad API response from wiping the seed data and breaking autocomplete.
      final hasValid = drugs.any((d) => (d['genericName'] as String).isNotEmpty);
      if (!hasValid) return;
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
      final seen = <String>{};
      final result = <MedicineSuggestion>[];

      // ── 1. Medicines from past visit prescriptions ────────────────
      final rows = await _prescriptions.getAllForPatient(patientId);
      for (final row in rows) {
        final text = row['text'] as String? ?? '';
        final visitDate = row['visitDate'] as String? ??
            row['_updatedAt'] as String? ?? '';
        final dateLabel = _formatDateLabel(visitDate);

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

      // ── 2. Medicines from OPD registration treatment fields ───────
      // These are stored as plain text in the patient record (treatment,
      // treatmentNotes fields) and never pass through savePrescription(),
      // so they won't appear in the prescriptions table above.
      try {
        final patientRow = await _patients.getById(patientId);
        if (patientRow != null) {
          final js = patientRow['data_json'] as String?;
          if (js != null) {
            final data = jsonDecode(js) as Map<String, dynamic>;
            final registrationDate = (data['createdAt'] as String? ?? '');
            final dateLabel = registrationDate.isNotEmpty
                ? _formatDateLabel(registrationDate)
                : 'Registration';
            // Collect text from all treatment-related fields.
            final textSources = <String>[
              data['treatment'] as String? ?? '',
              data['treatmentNotes'] as String? ?? '',
              data['plan'] as String? ?? '',
            ];
            for (final src in textSources) {
              for (final med in _parseMedicineText(src)) {
                final nl = med.toLowerCase();
                if (nl.contains(q) && seen.add(nl)) {
                  result.add(MedicineSuggestion(
                    name: med,
                    visitDateLabel: dateLabel,
                    isHistory: true,
                  ));
                }
              }
            }
          }
        }
      } catch (_) {}

      // ── 3. Medicines from visit examination data (direct SQLite) ──
      // This covers the common case where savePrescription() wasn't called
      // (e.g. medicines typed but not committed as chips) — reads the
      // examination JSON stored by createFullVisit() instead.
      try {
        if (!kIsWeb) {
          final visitRows = await _visits.getForPatient(patientId);
          for (final row in visitRows) {
            final examStr = row['examination'] as String?;
            if (examStr == null || examStr.isEmpty) continue;
            try {
              final examData = jsonDecode(examStr) as Map<String, dynamic>;
              final medsText = examData['medications'] as String? ?? '';
              if (medsText.isEmpty) continue;
              final visitDateStr =
                  row['visit_date'] as String? ?? row['created_at'] as String? ?? '';
              final dateLabel = _formatDateLabel(visitDateStr);
              for (final med in _parseMedicineText(medsText)) {
                final nl = med.toLowerCase();
                if (nl.contains(q) && seen.add(nl)) {
                  result.add(MedicineSuggestion(
                    name: med,
                    visitDateLabel: dateLabel,
                    isHistory: true,
                  ));
                }
              }
            } catch (_) {}
          }
        }
      } catch (_) {}

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
      // DB had drugs but none matched this query — fall back to the in-memory
      // constant master list so suggestions always appear for valid input.
      if (result.isEmpty) {
        return _masterSuggestionsFromConst(q, exclude: exclude, limit: limit);
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
    ref.watch(localPatientCacheProvider),
    ref.watch(localDrugCacheProvider),
    ref.watch(localVisitCacheProvider),
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

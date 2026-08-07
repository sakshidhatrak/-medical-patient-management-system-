import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/medicine_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MedicineAutocompleteField
//
// Chip-based medicine input with two-source autocomplete:
//   1. Patient history  (labelled with visit date)
//   2. Master list      (common medicines)
//
// Usage:
//   MedicineAutocompleteField(
//     patientId: patient.id,
//     initialText: _medicationsCtrl.text,
//     onChanged: (text) => _medicationsCtrl.text = text,
//     medicineService: ref.read(medicineServiceProvider),
//     cardColor: _kCard,
//     inputBgColor: _kInput,
//     textColor: _kNavy,
//     hintColor: _kMuted,
//     borderColor: _kBorder,
//     primaryColor: _kBlue,
//   )
// ─────────────────────────────────────────────────────────────────────────────

class MedicineAutocompleteField extends StatefulWidget {
  final String patientId;
  final String initialText;
  final ValueChanged<String> onChanged;
  final MedicineService medicineService;

  // Theme tokens — caller passes its own const colors
  final Color cardColor;
  final Color inputBgColor;
  final Color textColor;
  final Color hintColor;
  final Color borderColor;
  final Color primaryColor;
  final Color historyColor;

  const MedicineAutocompleteField({
    super.key,
    required this.patientId,
    required this.initialText,
    required this.onChanged,
    required this.medicineService,
    required this.cardColor,
    required this.inputBgColor,
    required this.textColor,
    required this.hintColor,
    required this.borderColor,
    required this.primaryColor,
    this.historyColor = const Color(0xFF4EC080),
  });

  @override
  State<MedicineAutocompleteField> createState() =>
      _MedicineAutocompleteFieldState();
}

class _MedicineAutocompleteFieldState
    extends State<MedicineAutocompleteField> {
  final _inputCtrl = TextEditingController();
  final _inputFocus = FocusNode();
  final _containerKey = GlobalKey();
  OverlayEntry? _overlay;

  List<String> _medicines = [];
  List<MedicineSuggestion> _suggestions = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _medicines = _parse(widget.initialText);
    _inputFocus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _inputFocus.removeListener(_onFocusChange);
    _inputCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  // ── Parsing / serialisation ───────────────────────────────────────

  List<String> _parse(String text) {
    if (text.trim().isEmpty) return [];
    return text
        .split('\n')
        .expand((line) => line.split(RegExp(r'[·,;]+')))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  String _serialise(List<String> meds) => meds.join('\n');

  void _notify() => widget.onChanged(_serialise(_medicines));

  // ── Chip management ───────────────────────────────────────────────

  void _addMedicine(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    if (_medicines.any((m) => m.toLowerCase() == trimmed.toLowerCase())) return;
    setState(() => _medicines.add(trimmed));
    _inputCtrl.clear();
    _removeOverlay();
    _notify();
  }

  void _removeMedicine(int idx) {
    setState(() => _medicines.removeAt(idx));
    _notify();
  }

  // ── Autocomplete logic ────────────────────────────────────────────

  void _onFocusChange() {
    if (!_inputFocus.hasFocus) {
      Future.delayed(const Duration(milliseconds: 150), _removeOverlay);
    }
  }

  void _onInputChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () async {
      final q = value.trim();
      if (q.length < 2) {
        setState(() => _suggestions = []);
        _removeOverlay();
        return;
      }
      final results = await widget.medicineService.getSuggestions(
        query: q,
        patientId: widget.patientId,
      );
      if (!mounted) return;
      setState(() => _suggestions = results);
      if (results.isNotEmpty) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    });
  }

  // ── Overlay management ────────────────────────────────────────────

  void _showOverlay() {
    _removeOverlay();
    final renderBox = _containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    final overlay = Overlay.of(context);
    _overlay = OverlayEntry(builder: (_) => _SuggestionDropdown(
      left: offset.dx,
      top: offset.dy + size.height + 4,
      width: size.width,
      suggestions: _suggestions,
      onSelect: _addMedicine,
      cardColor: widget.cardColor,
      textColor: widget.textColor,
      hintColor: widget.hintColor,
      borderColor: widget.borderColor,
      primaryColor: widget.primaryColor,
      historyColor: widget.historyColor,
    ));
    overlay.insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Treatment / Medications',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: widget.hintColor)),
        const SizedBox(height: 6),
        Container(
            key: _containerKey,
            decoration: BoxDecoration(
              color: widget.inputBgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _inputFocus.hasFocus
                    ? widget.primaryColor
                    : widget.borderColor,
                width: _inputFocus.hasFocus ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Chips ─────────────────────────────────────────
                if (_medicines.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: List.generate(_medicines.length, (i) {
                      return _MedicineChip(
                        label: _medicines[i],
                        onRemove: () => _removeMedicine(i),
                        bgColor:
                            widget.primaryColor.withValues(alpha: 0.15),
                        textColor: widget.primaryColor,
                        borderColor:
                            widget.primaryColor.withValues(alpha: 0.3),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                ],
                // ── Input row ─────────────────────────────────────
                Row(children: [
                  Icon(Icons.medication_outlined,
                      size: 16, color: widget.hintColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      focusNode: _inputFocus,
                      onChanged: _onInputChanged,
                      onSubmitted: (v) {
                        if (v.trim().isNotEmpty) _addMedicine(v);
                      },
                      style: TextStyle(
                          color: widget.textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                      cursorColor: widget.primaryColor,
                      decoration: InputDecoration(
                        hintText: 'Type medicine name…',
                        hintStyle: TextStyle(
                            color: widget.hintColor, fontSize: 13),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_inputCtrl.text.trim().isNotEmpty)
                    GestureDetector(
                      onTap: () => _addMedicine(_inputCtrl.text),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.primaryColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Add',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                ]),
              ],
            ),
          ),
        if (_medicines.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(
              'Press Enter or tap Add after typing each medicine',
              style: TextStyle(fontSize: 10, color: widget.hintColor),
            ),
          ),
      ],
    );
  }
}

// ── Chip widget ───────────────────────────────────────────────────────────────

class _MedicineChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  final Color bgColor;
  final Color textColor;
  final Color borderColor;

  const _MedicineChip({
    required this.label,
    required this.onRemove,
    required this.bgColor,
    required this.textColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label,
              style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child:
                Icon(Icons.close_rounded, size: 13, color: textColor),
          ),
        ]),
      );
}

// ── Suggestion dropdown overlay ───────────────────────────────────────────────

class _SuggestionDropdown extends StatelessWidget {
  final double left;
  final double top;
  final double width;
  final List<MedicineSuggestion> suggestions;
  final ValueChanged<String> onSelect;
  final Color cardColor;
  final Color textColor;
  final Color hintColor;
  final Color borderColor;
  final Color primaryColor;
  final Color historyColor;

  const _SuggestionDropdown({
    required this.left,
    required this.top,
    required this.width,
    required this.suggestions,
    required this.onSelect,
    required this.cardColor,
    required this.textColor,
    required this.hintColor,
    required this.borderColor,
    required this.primaryColor,
    required this.historyColor,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 240),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              shrinkWrap: true,
              itemCount: suggestions.length,
              separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: borderColor.withValues(alpha: 0.5)),
              itemBuilder: (_, i) {
                final s = suggestions[i];
                return InkWell(
                  onTap: () => onSelect(s.name),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    child: Row(children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: (s.isHistory ? historyColor : primaryColor)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Icon(
                          s.isHistory
                              ? Icons.history_rounded
                              : Icons.medication_rounded,
                          size: 15,
                          color: s.isHistory ? historyColor : primaryColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textColor),
                                overflow: TextOverflow.ellipsis),
                            if (s.subtitle.isNotEmpty)
                              Text(s.subtitle,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: s.isHistory
                                          ? historyColor
                                          : hintColor),
                                  overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

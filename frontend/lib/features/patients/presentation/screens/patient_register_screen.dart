// ─────────────────────────────────────────────────────────────────────────────
// patient_register_screen.dart  –  Smart 30-second registration (Premium)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/patient_entity.dart';
import '../providers/patient_provider.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kP1    = Color(0xFF7C3AED);
const _kP2    = Color(0xFF3B82F6);
const _kRed   = Color(0xFFEF4444);
const _kAmber = Color(0xFFF59E0B);
const _kGreen = Color(0xFF10B981);
const _kBg    = Color(0xFFF8FAFC);
const _kCard  = Colors.white;
const _kNavy  = Color(0xFF0F172A);
const _kSlate = Color(0xFF475569);
const _kMuted = Color(0xFF94A3B8);
const _kBorder= Color(0xFFE2E8F0);

class PatientRegisterScreen extends ConsumerStatefulWidget {
  const PatientRegisterScreen({super.key});
  @override
  ConsumerState<PatientRegisterScreen> createState() => _PatientRegisterScreenState();
}

class _PatientRegisterScreenState extends ConsumerState<PatientRegisterScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _firstCtrl    = TextEditingController();
  final _lastCtrl     = TextEditingController();
  final _ageCtrl      = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _altCtrl      = TextEditingController();
  final _addressCtrl  = TextEditingController();
  final _notesCtrl    = TextEditingController();

  String? _sex;
  DateTime? _dob;
  String _source = 'Walk-in';
  bool _saving = false;
  List<PatientEntity> _duplicates = [];

  static const _sexOptions    = ['Male', 'Female', 'Other'];
  static const _sourceOptions = ['Walk-in', 'OPD', 'Appointment', 'Referral'];
  static const _sourceIcons   = [Icons.directions_walk, Icons.local_hospital_rounded,
                                  Icons.event_available, Icons.share_rounded];
  static const _sourceColors  = [_kP1, _kP2, _kGreen, _kAmber];

  @override
  void dispose() {
    for (final c in [_firstCtrl, _lastCtrl, _ageCtrl, _phoneCtrl, _altCtrl, _addressCtrl, _notesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _checkDuplicates() async {
    final name = _firstCtrl.text.trim();
    if (name.length < 3) { setState(() => _duplicates = []); return; }
    final dupes = await ref.read(patientsProvider.notifier)
        .searchDuplicates(name, _phoneCtrl.text.trim());
    setState(() => _duplicates = dupes);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final patient = await ref.read(patientsProvider.notifier).createPatient(
      firstName: _firstCtrl.text.trim(),
      lastName:  _lastCtrl.text.trim(),
      age:       _ageCtrl.text.isNotEmpty ? int.tryParse(_ageCtrl.text.trim()) : null,
      dob:       _dob,
      sex:       _sex?.toLowerCase(),
      phone:     _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      address:   _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      notes:     _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    setState(() => _saving = false);
    if (!mounted) return;

    if (patient != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Registered  ·  PRN: ${patient.prn}'),
        backgroundColor: _kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      context.go('/patients/${patient.id}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Registration failed. Try again.'),
        backgroundColor: _kRed,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(children: [
        // ── Gradient header ──────────────────────────────────────
        _GradientHeader(onBack: () => context.pop()),

        // ── Form body ────────────────────────────────────────────
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                // ── Source selection ─────────────────────────────
                _FormSection(
                  title: 'Visit Source',
                  icon: Icons.input_rounded,
                  child: Row(children: List.generate(4, (i) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
                      child: GestureDetector(
                        onTap: () => setState(() => _source = _sourceOptions[i]),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _source == _sourceOptions[i]
                                ? _sourceColors[i].withValues(alpha: 0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _source == _sourceOptions[i]
                                  ? _sourceColors[i]
                                  : _kBorder,
                              width: _source == _sourceOptions[i] ? 1.5 : 1,
                            ),
                          ),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(_sourceIcons[i],
                                color: _source == _sourceOptions[i]
                                    ? _sourceColors[i] : _kMuted,
                                size: 18),
                            const SizedBox(height: 4),
                            Text(_sourceOptions[i],
                                style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w700,
                                  color: _source == _sourceOptions[i]
                                      ? _sourceColors[i] : _kMuted,
                                ),
                                textAlign: TextAlign.center),
                          ]),
                        ),
                      ),
                    ),
                  ))),
                ),

                // ── Duplicate warning ─────────────────────────────
                if (_duplicates.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _DuplicateWarning(duplicates: _duplicates, onTap: (p) => context.go('/patients/${p.id}')),
                ],

                // ── Basic info ────────────────────────────────────
                _FormSection(
                  title: 'Basic Information',
                  icon: Icons.person_outline_rounded,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: _RegField(
                        label: 'First Name *',
                        controller: _firstCtrl,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                        onEditingComplete: _checkDuplicates,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _RegField(
                        label: 'Last Name',
                        controller: _lastCtrl,
                        textCapitalization: TextCapitalization.words,
                      )),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _RegField(
                        label: 'Age (years)',
                        controller: _ageCtrl,
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v?.isEmpty == true) return null;
                          final n = int.tryParse(v ?? '');
                          if (n == null || n < 0 || n > 120) return 'Invalid';
                          return null;
                        },
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _SexDropdown(
                        value: _sex,
                        options: _sexOptions,
                        onChanged: (v) => setState(() => _sex = v),
                      )),
                    ]),
                    const SizedBox(height: 12),
                    // DOB
                    _DateField(
                      label: 'Date of Birth (optional)',
                      value: _dob,
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                          builder: (c, w) => Theme(
                            data: Theme.of(c).copyWith(
                              colorScheme: const ColorScheme.light(primary: _kP1),
                            ),
                            child: w!,
                          ),
                        );
                        if (d != null) {
                          setState(() => _dob = d);
                          if (_ageCtrl.text.isEmpty) {
                            _ageCtrl.text = '${DateTime.now().difference(d).inDays ~/ 365}';
                          }
                        }
                      },
                    ),
                  ]),
                ),

                // ── Contact ───────────────────────────────────────
                _FormSection(
                  title: 'Contact Details',
                  icon: Icons.contact_phone_outlined,
                  child: Column(children: [
                    _RegField(
                      label: 'Phone Number',
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_outlined,
                      onEditingComplete: _checkDuplicates,
                    ),
                    const SizedBox(height: 12),
                    _RegField(
                      label: 'Alternate Phone',
                      controller: _altCtrl,
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_callback_outlined,
                    ),
                    const SizedBox(height: 12),
                    _RegField(
                      label: 'Address',
                      controller: _addressCtrl,
                      maxLines: 2,
                      prefixIcon: Icons.location_on_outlined,
                    ),
                  ]),
                ),

                // ── Clinical notes ────────────────────────────────
                _FormSection(
                  title: 'Clinical Snapshot',
                  icon: Icons.note_alt_outlined,
                  badge: 'Optional',
                  child: _RegField(
                    label: 'Allergies, conditions, medications, notes…',
                    controller: _notesCtrl,
                    maxLines: 4,
                  ),
                ),

                const SizedBox(height: 8),

                // ── Bottom actions ────────────────────────────────
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => context.pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kSlate,
                        side: const BorderSide(color: _kBorder, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _saving ? null : _save,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_kP1, _kP2]),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: _kP1.withValues(alpha: 0.3),
                              blurRadius: 16, offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: _saving
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('Register Patient',
                                    style: TextStyle(color: Colors.white,
                                        fontWeight: FontWeight.w700, fontSize: 15)),
                              ]),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Gradient header ───────────────────────────────────────────────────────────
class _GradientHeader extends StatelessWidget {
  final VoidCallback onBack;
  const _GradientHeader({required this.onBack});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF6D28D9), Color(0xFF3B82F6)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 8,
      left: 4, right: 16, bottom: 16,
    ),
    child: Row(children: [
      IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
        onPressed: onBack,
      ),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Register Patient',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
          Text('Complete in under 30 seconds',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
        ]),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.mic_none_rounded, color: Colors.white, size: 14),
          SizedBox(width: 5),
          Text('Voice', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    ]),
  );
}

// ── Form section ──────────────────────────────────────────────────────────────
class _FormSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final String? badge;

  const _FormSection({
    required this.title, required this.icon, required this.child, this.badge,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kP1, _kP2]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 15),
            ),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kNavy)),
            if (badge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _kMuted.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(badge!, style: const TextStyle(fontSize: 9, color: _kMuted, fontWeight: FontWeight.w600)),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: _kBorder),
        Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ]),
    ),
  );
}

// ── Duplicate warning ─────────────────────────────────────────────────────────
class _DuplicateWarning extends StatelessWidget {
  final List<PatientEntity> duplicates;
  final void Function(PatientEntity) onTap;
  const _DuplicateWarning({required this.duplicates, required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _kAmber.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _kAmber.withValues(alpha: 0.3)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.warning_amber_rounded, color: _kAmber, size: 18),
        const SizedBox(width: 8),
        Text('Similar patients found',
            style: TextStyle(fontWeight: FontWeight.w700, color: _kAmber.withValues(alpha: 1), fontSize: 13)),
      ]),
      const SizedBox(height: 10),
      ...duplicates.map((p) => GestureDetector(
        onTap: () => onTap(p),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kAmber.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _kAmber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(p.initials,
                  style: TextStyle(color: _kAmber.withValues(alpha: 1), fontWeight: FontWeight.w800, fontSize: 12)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _kNavy)),
                Text('${p.ageSex}  ·  PRN: ${p.prn}',
                    style: const TextStyle(fontSize: 11, color: _kMuted)),
              ]),
            ),
            const Icon(Icons.arrow_forward_ios, size: 12, color: _kMuted),
          ]),
        ),
      )),
      Text('You can still continue registering a new patient.',
          style: TextStyle(fontSize: 11, color: _kMuted)),
    ]),
  );
}

// ── Form field ────────────────────────────────────────────────────────────────
class _RegField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final VoidCallback? onEditingComplete;
  final int? maxLines;
  final TextCapitalization textCapitalization;
  final IconData? prefixIcon;

  const _RegField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.validator,
    this.onEditingComplete,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kSlate)),
    const SizedBox(height: 6),
    TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      onEditingComplete: onEditingComplete,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      style: const TextStyle(fontSize: 14, color: _kNavy, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: _kMuted) : null,
        filled: true,
        fillColor: _kBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kP1, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kRed)),
      ),
    ),
  ]);
}

// ── Sex dropdown ──────────────────────────────────────────────────────────────
class _SexDropdown extends StatelessWidget {
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  const _SexDropdown({required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Sex', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kSlate)),
    const SizedBox(height: 6),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        hint: const Text('Select', style: TextStyle(fontSize: 14, color: _kMuted)),
        icon: const Icon(Icons.keyboard_arrow_down, color: _kMuted),
        style: const TextStyle(fontSize: 14, color: _kNavy, fontWeight: FontWeight.w500),
        items: options.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: onChanged,
      ),
    ),
  ]);
}

// ── Date field ────────────────────────────────────────────────────────────────
class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  const _DateField({required this.label, this.value, required this.onTap});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kSlate)),
    const SizedBox(height: 6),
    InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 16, color: _kMuted),
          const SizedBox(width: 8),
          Text(
            value != null ? DateFormat('dd MMM yyyy').format(value!) : 'Tap to select',
            style: TextStyle(
              fontSize: 14,
              color: value != null ? _kNavy : _kMuted,
              fontWeight: value != null ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ]),
      ),
    ),
  ]);
}

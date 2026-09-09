import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/patient_entity.dart';
import '../providers/patient_provider.dart';

// ── Design tokens (matching patient_register_screen palette) ─────────────────
const _kBlue   = Color(0xFF5B5ECC);
const _kBg     = Color(0xFF171629);
const _kCard   = Color(0xFF252545);
const _kInput  = Color(0xFF1E1C35);
const _kNavy   = Color(0xFFEEECFF);
const _kSlate  = Color(0xFFCCCAE8);
const _kMuted  = Color(0xFF9896B8);
const _kBorder = Color(0xFF3A3865);

class PatientEditScreen extends ConsumerStatefulWidget {
  final String patientId;
  const PatientEditScreen({super.key, required this.patientId});

  @override
  ConsumerState<PatientEditScreen> createState() => _PatientEditScreenState();
}

class _PatientEditScreenState extends ConsumerState<PatientEditScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstCtrl    = TextEditingController();
  final _lastCtrl     = TextEditingController();
  final _ageCtrl      = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _altCtrl      = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _addressCtrl  = TextEditingController();
  final _idProofCtrl  = TextEditingController();

  String? _sex;
  String? _idProofType;
  DateTime? _dob;
  bool _saving = false;
  bool _loaded = false;

  static const _sexOptions     = ['Male', 'Female', 'Other'];
  static const _idProofOptions = ['Aadhaar Card', 'PAN Card'];

  @override
  void dispose() {
    for (final c in [
      _firstCtrl, _lastCtrl, _ageCtrl, _phoneCtrl,
      _altCtrl, _emailCtrl, _addressCtrl, _idProofCtrl,
    ]) c.dispose();
    super.dispose();
  }

  void _populate(PatientEntity p) {
    if (_loaded) return;
    _loaded = true;
    _firstCtrl.text   = p.firstName;
    _lastCtrl.text    = p.lastName;
    _ageCtrl.text     = p.age?.toString() ?? '';
    _phoneCtrl.text   = p.phone ?? '';
    _altCtrl.text     = p.altPhone ?? '';
    _emailCtrl.text   = p.email ?? '';
    _addressCtrl.text = p.address ?? '';
    _idProofCtrl.text = p.idProofNumber ?? '';
    _sex          = p.sex != null
        ? '${p.sex![0].toUpperCase()}${p.sex!.substring(1)}'
        : null;
    _idProofType  = p.idProofType;
    _dob          = p.dateOfBirth;
  }

  Future<void> _save(PatientEntity original) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final updated = original.copyWith(
      firstName:    _firstCtrl.text.trim(),
      lastName:     _lastCtrl.text.trim(),
      age:          _ageCtrl.text.trim().isEmpty ? null : int.tryParse(_ageCtrl.text.trim()),
      dateOfBirth:  _dob,
      sex:          _sex?.toLowerCase(),
      phone:        _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      altPhone:     _altCtrl.text.trim().isEmpty ? null : _altCtrl.text.trim(),
      email:        _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      address:      _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      idProofType:  _idProofType,
      idProofNumber: _idProofCtrl.text.trim().isEmpty ? null : _idProofCtrl.text.trim(),
    );

    await ref.read(patientsProvider.notifier).updatePatient(updated);

    // Force the detail screen to re-read from the updated local cache.
    ref.invalidate(patientByIdProvider(widget.patientId));

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient info updated'), backgroundColor: _kBlue),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientAsync = ref.watch(patientByIdProvider(widget.patientId));

    return patientAsync.when(
      loading: () => const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kBlue)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(backgroundColor: _kBg),
        body: Center(child: Text('Error: $e', style: const TextStyle(color: _kNavy))),
      ),
      data: (patient) {
        if (patient == null) {
          return Scaffold(
            backgroundColor: _kBg,
            appBar: AppBar(backgroundColor: _kBg),
            body: const Center(
                child: Text('Patient not found', style: TextStyle(color: _kNavy))),
          );
        }
        _populate(patient);

        return Scaffold(
          backgroundColor: _kBg,
          appBar: AppBar(
            backgroundColor: _kBg,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: _kNavy, size: 18),
              onPressed: () => context.pop(),
            ),
            title: const Text(
              'Edit Patient Info',
              style: TextStyle(color: _kNavy, fontWeight: FontWeight.w700, fontSize: 16),
            ),
            actions: [
              if (_saving)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: _kBlue, strokeWidth: 2),
                  ),
                )
              else
                TextButton(
                  onPressed: () => _save(patient),
                  child: const Text('Save',
                      style: TextStyle(
                          color: _kBlue, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionCard('Basic Information', [
                  _field('First Name *', _firstCtrl,
                      validator: (v) => v?.trim().isEmpty == true ? 'Required' : null),
                  _field('Last Name', _lastCtrl),
                  _field('Age', _ageCtrl,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final n = int.tryParse(v.trim());
                        if (n == null || n < 0 || n > 150) return 'Enter valid age';
                        return null;
                      }),
                  _dobField(),
                  _dropdownField('Sex', _sexOptions, _sex, (v) => setState(() => _sex = v)),
                ]),
                const SizedBox(height: 12),
                _sectionCard('Contact Details', [
                  _field('Phone Number', _phoneCtrl,
                      keyboardType: TextInputType.phone),
                  _field('Alternate Phone', _altCtrl,
                      keyboardType: TextInputType.phone),
                  _field('Email', _emailCtrl,
                      keyboardType: TextInputType.emailAddress),
                  _field('Address', _addressCtrl, maxLines: 3),
                ]),
                const SizedBox(height: 12),
                _sectionCard('ID Proof', [
                  _dropdownField('ID Proof Type', _idProofOptions, _idProofType,
                      (v) => setState(() => _idProofType = v)),
                  _field('ID Proof Number', _idProofCtrl),
                ]),
                const SizedBox(height: 80),
              ],
            ),
          ),
          floatingActionButton: _saving
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _save(patient),
                  backgroundColor: _kBlue,
                  icon: const Icon(Icons.save_outlined, color: Colors.white),
                  label: const Text('Save Changes',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
        );
      },
    );
  }

  Widget _sectionCard(String title, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: _kBlue, fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboardType,
      int maxLines = 1,
      String? Function(String?)? validator}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: _kMuted, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextFormField(
              controller: ctrl,
              keyboardType: keyboardType,
              maxLines: maxLines,
              style: const TextStyle(color: _kNavy, fontSize: 14),
              validator: validator,
              decoration: InputDecoration(
                filled: true,
                fillColor: _kInput,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _kBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _kBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _kBlue, width: 1.5)),
                errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFFE07878), width: 1.5)),
              ),
            ),
          ],
        ),
      );

  Widget _dropdownField(String label, List<String> options, String? value,
      ValueChanged<String?> onChanged) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: _kMuted, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: value,
              dropdownColor: _kCard,
              style: const TextStyle(color: _kNavy, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: _kInput,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _kBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _kBorder)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _kBlue, width: 1.5)),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('— Select —',
                    style: TextStyle(color: _kMuted))),
                ...options.map((o) => DropdownMenuItem(value: o, child: Text(o))),
              ],
              onChanged: onChanged,
            ),
          ],
        ),
      );

  Widget _dobField() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Date of Birth',
                style: TextStyle(
                    color: _kMuted, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dob ?? DateTime.now().subtract(const Duration(days: 365 * 30)),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                  builder: (ctx, child) => Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(primary: _kBlue),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) setState(() => _dob = picked);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                decoration: BoxDecoration(
                  color: _kInput,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kBorder),
                ),
                child: Text(
                  _dob != null
                      ? '${_dob!.day.toString().padLeft(2, '0')}/'
                          '${_dob!.month.toString().padLeft(2, '0')}/'
                          '${_dob!.year}'
                      : 'Select date',
                  style: TextStyle(
                      color: _dob != null ? _kNavy : _kMuted, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      );
}

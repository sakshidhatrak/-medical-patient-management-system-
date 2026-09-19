import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/patient_entity.dart';
import '../providers/patient_provider.dart';

const _kBlue  = Color(0xFF4B55CC);
const _kGreen = Color(0xFF4EC080);

bool  _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
Color _kBg    (BuildContext c) => _isDark(c) ? const Color(0xFF171629) : const Color(0xFFF8F6F2);
Color _kCard  (BuildContext c) => _isDark(c) ? const Color(0xFF252545) : Colors.white;
Color _kNavy  (BuildContext c) => _isDark(c) ? const Color(0xFFEEECFF) : const Color(0xFF302D28);
Color _kSlate (BuildContext c) => _isDark(c) ? const Color(0xFFCCCAE8) : const Color(0xFF6E6A63);
Color _kMuted (BuildContext c) => _isDark(c) ? const Color(0xFF9896B8) : const Color(0xFF979088);
Color _kBorder(BuildContext c) => _isDark(c) ? const Color(0xFF3A3865) : const Color(0xFFE0DDD7);
Color _kInput (BuildContext c) => _isDark(c) ? const Color(0xFF1E1C35) : const Color(0xFFF8F6F2);

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
  final _allergyCtrl  = TextEditingController();

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
      _altCtrl, _emailCtrl, _addressCtrl, _idProofCtrl, _allergyCtrl,
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
    _idProofCtrl.text  = p.idProofNumber ?? '';
    _allergyCtrl.text  = p.allergies ?? '';
    _sex         = p.sex != null
        ? '${p.sex![0].toUpperCase()}${p.sex!.substring(1)}'
        : null;
    _idProofType = p.idProofType;
    _dob         = p.dateOfBirth;
  }

  Future<void> _save(PatientEntity original) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final updated = original.copyWith(
      firstName:     _firstCtrl.text.trim(),
      lastName:      _lastCtrl.text.trim(),
      age:           _ageCtrl.text.trim().isEmpty ? null : int.tryParse(_ageCtrl.text.trim()),
      dateOfBirth:   _dob,
      sex:           _sex?.toLowerCase(),
      phone:         _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      altPhone:      _altCtrl.text.trim().isEmpty ? null : _altCtrl.text.trim(),
      email:         _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      address:       _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      idProofType:   _idProofType,
      idProofNumber: _idProofCtrl.text.trim().isEmpty ? null : _idProofCtrl.text.trim(),
      allergies:     _allergyCtrl.text.trim().isEmpty ? null : _allergyCtrl.text.trim(),
    );

    await ref.read(patientsProvider.notifier).updatePatient(updated);
    ref.invalidate(patientByIdProvider(widget.patientId));

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Text('Patient info updated', style: TextStyle(fontWeight: FontWeight.w600)),
        ]),
        backgroundColor: _kBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientAsync = ref.watch(patientByIdProvider(widget.patientId));
    final vp = MediaQuery.of(context).viewPadding;

    return patientAsync.when(
      loading: () => Scaffold(
        backgroundColor: _kBg(context),
        body: Center(child: CircularProgressIndicator(color: _kBlue)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: _kBg(context),
        appBar: AppBar(backgroundColor: _kBg(context)),
        body: Center(child: Text('Error: $e')),
      ),
      data: (patient) {
        if (patient == null) {
          return Scaffold(
            backgroundColor: _kBg(context),
            appBar: AppBar(backgroundColor: _kBg(context)),
            body: const Center(child: Text('Patient not found')),
          );
        }
        _populate(patient);

        return Scaffold(
          backgroundColor: _kBg(context),
          resizeToAvoidBottomInset: true,
          body: Column(children: [
            SizedBox(height: vp.top),
            _buildHeader(patient),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
                  children: [
                    _sCard(
                      title: 'Basic Information',
                      icon: Icons.person_outline_rounded,
                      color: _kBlue,
                      children: [
                        _field('First Name *', _firstCtrl,
                            validator: (v) =>
                                v?.trim().isEmpty == true ? 'Required' : null),
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
                        _dropdownField('Sex', _sexOptions, _sex,
                            (v) => setState(() => _sex = v)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _sCard(
                      title: 'Contact Details',
                      icon: Icons.phone_outlined,
                      color: _kBlue,
                      children: [
                        _field('Phone Number', _phoneCtrl,
                            keyboardType: TextInputType.phone),
                        _field('Alternate Phone', _altCtrl,
                            keyboardType: TextInputType.phone),
                        _field('Email', _emailCtrl,
                            keyboardType: TextInputType.emailAddress),
                        _field('Address', _addressCtrl, maxLines: 3),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _sCard(
                      title: 'ID Proof',
                      icon: Icons.badge_outlined,
                      color: _kBlue,
                      children: [
                        _dropdownField('ID Proof Type', _idProofOptions,
                            _idProofType, (v) => setState(() => _idProofType = v)),
                        _field('ID Proof Number', _idProofCtrl),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _sCard(
                      title: 'Clinical Snapshot',
                      icon: Icons.note_alt_outlined,
                      color: const Color(0xFFD4A855),
                      children: [
                        _field('Known Allergies', _allergyCtrl, maxLines: 3),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ]),
          floatingActionButton: SizedBox(
            width: MediaQuery.of(context).size.width - 28,
            height: 52,
            child: FloatingActionButton.extended(
              onPressed: _saving ? null : () => _save(patient),
              backgroundColor: _saving ? _kBlue.withValues(alpha: 0.5) : _kBlue,
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              icon: _saving
                  ? SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(Icons.save_outlined, color: Colors.white, size: 19),
              label: _saving
                  ? const SizedBox.shrink()
                  : Text('Save Changes',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        );
      },
    );
  }

  Widget _buildHeader(PatientEntity patient) => Container(
    color: _kCard(context),
    padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
    child: Row(children: [
      IconButton(
        icon: Icon(Icons.arrow_back_ios_new, size: 18, color: _kNavy(context)),
        onPressed: () => context.pop(),
      ),
      const SizedBox(width: 4),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Edit Patient',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: _kNavy(context), letterSpacing: -0.3)),
          Text(
            '${patient.firstName} ${patient.lastName}'.trim(),
            style: TextStyle(fontSize: 12, color: _kMuted(context)),
          ),
        ]),
      ),
      if (_saving)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(color: _kBlue, strokeWidth: 2),
          ),
        ),
    ]),
  );

  Widget _sCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) =>
      Container(
        decoration: BoxDecoration(
          color: _kCard(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder(context)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 8),
            child: Row(children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 15),
              ),
              const SizedBox(width: 9),
              Text(title,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: _kNavy(context))),
            ]),
          ),
          Divider(height: 1, color: _kBorder(context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ]),
      );

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboardType,
      int maxLines = 1,
      String? Function(String?)? validator}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: _kMuted(context))),
          const SizedBox(height: 4),
          TextFormField(
            controller: ctrl,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: TextStyle(
                fontSize: 14, color: _kNavy(context), fontWeight: FontWeight.w500),
            validator: validator,
            decoration: InputDecoration(
              filled: true,
              fillColor: _kInput(context),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _kBorder(context))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _kBorder(context))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBlue, width: 1.5)),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFFE07878), width: 1.5)),
            ),
          ),
        ]),
      );

  Widget _dropdownField(String label, List<String> options, String? value,
      ValueChanged<String?> onChanged) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: _kMuted(context))),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: value,
            dropdownColor: _kCard(context),
            iconEnabledColor: _kMuted(context),
            style: TextStyle(fontSize: 14, color: _kNavy(context)),
            decoration: InputDecoration(
              filled: true,
              fillColor: _kInput(context),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _kBorder(context))),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _kBorder(context))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBlue, width: 1.5)),
            ),
            items: [
              DropdownMenuItem(
                  value: null,
                  child: Text('— Select —',
                      style: TextStyle(color: _kMuted(context)))),
              ...options.map((o) => DropdownMenuItem(
                  value: o,
                  child: Text(o, style: TextStyle(color: _kNavy(context))))),
            ],
            onChanged: onChanged,
          ),
        ]),
      );

  Widget _dobField() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Date of Birth',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: _kMuted(context))),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _dob ??
                    DateTime.now().subtract(const Duration(days: 365 * 30)),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(primary: _kBlue),
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
                color: _kInput(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder(context)),
              ),
              child: Row(children: [
                Icon(Icons.calendar_today_outlined,
                    size: 16, color: _kMuted(context)),
                const SizedBox(width: 10),
                Text(
                  _dob != null
                      ? DateFormat('dd MMM yyyy').format(_dob!)
                      : 'Select date',
                  style: TextStyle(
                      fontSize: 14,
                      color: _dob != null ? _kNavy(context) : _kMuted(context),
                      fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Icon(Icons.edit_outlined, size: 14, color: _kMuted(context)),
              ]),
            ),
          ),
        ]),
      );
}

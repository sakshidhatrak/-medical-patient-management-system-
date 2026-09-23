import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/patient_entity.dart';
import '../../../photos/domain/entities/photo_entity.dart';
import '../../../photos/presentation/providers/photo_provider.dart';
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
                    const SizedBox(height: 10),
                    _PatientPhotosCard(patientId: widget.patientId),
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

// ── Patient Photos Card ───────────────────────────────────────────────────────
class _PatientPhotosCard extends ConsumerWidget {
  final String patientId;
  const _PatientPhotosCard({required this.patientId});

  static final _uuidPat = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-',
      caseSensitive: false);

  String _filename(PhotoEntity p) {
    final orig = p.originalFilename;
    if (orig != null && orig.isNotEmpty && !_uuidPat.hasMatch(orig)) return orig;
    final pathLast = p.storagePath.split('/').last;
    if (!_uuidPat.hasMatch(pathLast)) return pathLast;
    final ext = pathLast.contains('.') ? pathLast.split('.').last : 'jpg';
    final cap = (p.caption?.isNotEmpty == true ? p.caption! : 'Photo')
        .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '').trim().replaceAll(' ', '_');
    return '$cap.$ext';
  }

  IconData _icon(PhotoEntity p) {
    final n = _filename(p).toLowerCase();
    if (n.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (n.endsWith('.xls') || n.endsWith('.xlsx')) return Icons.table_chart_rounded;
    if (n.endsWith('.doc') || n.endsWith('.docx')) return Icons.description_rounded;
    return Icons.image_rounded;
  }

  Color _iconColor(PhotoEntity p) {
    final n = _filename(p).toLowerCase();
    if (n.endsWith('.pdf')) return const Color(0xFFEF4444);
    if (n.endsWith('.xls') || n.endsWith('.xlsx')) return const Color(0xFF16A34A);
    if (n.endsWith('.doc') || n.endsWith('.docx')) return const Color(0xFF2563EB);
    return const Color(0xFF4B55CC);
  }

  Future<void> _open(PhotoEntity p) async {
    if (p.url != null && p.url!.isNotEmpty) {
      try {
        await launchUrl(Uri.parse(p.url!), mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? const Color(0xFF252545) : Colors.white;
    final navy    = isDark ? const Color(0xFFEEECFF) : const Color(0xFF302D28);
    final muted   = isDark ? const Color(0xFF9896B8) : const Color(0xFF979088);
    final border  = isDark ? const Color(0xFF3A3865) : const Color(0xFFE0DDD7);

    final photoState = ref.watch(photoProvider(patientId));
    final photos = photoState.photos;

    if (photoState.isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue)),
          const SizedBox(width: 12),
          Text('Loading photos…', style: TextStyle(fontSize: 13, color: muted)),
        ]),
      );
    }

    if (photos.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 8),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: _kBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.photo_library_outlined,
                  color: _kBlue, size: 15),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text('Patient Photos',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: navy, letterSpacing: -0.1)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _kBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${photos.length} file${photos.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 11, color: _kBlue, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),

        Divider(height: 1, color: border),

        // Photo rows
        ...photos.asMap().entries.map((entry) {
          final p    = entry.value;
          final name = _filename(p);
          final ic   = _iconColor(p);
          final isLast = entry.key == photos.length - 1;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: bg,
              border: isLast
                  ? null
                  : Border(bottom: BorderSide(color: border)),
            ),
            child: Row(children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: ic,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(_icon(p), size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: navy),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (p.caption != null && p.caption!.isNotEmpty)
                      Text(p.caption!,
                          style: TextStyle(fontSize: 10, color: muted)),
                  ],
                ),
              ),
              if (p.url != null || p.localPath != null)
                InkWell(
                  onTap: () => _open(p),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.remove_red_eye_outlined,
                        size: 18, color: _kBlue),
                  ),
                ),
            ]),
          );
        }),
      ]),
    );
  }
}

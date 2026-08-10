import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../providers/auth_provider.dart';

const _kNavy   = Color(0xFF1A237E);
const _kBlue   = Color(0xFF283593);
const _kBg     = Color(0xFFE8EEF8);
const _kRed    = Color(0xFFEF4444);
const _kMuted  = Color(0xFF9E9E9E);
const _kLabel  = Color(0xFF212121);
const _kBorder = Color(0xFFE0E0E0);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure    = true;
  int  _roleIndex  = 0;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authProvider.notifier).login(_emailCtrl.text.trim(), _passCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (_, next) {
      if (next is AuthAuthenticated) context.go(RouteNames.dashboard);
      if (next is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message), backgroundColor: _kRed),
        );
      }
    });

    final isLoading = ref.watch(authProvider) is AuthLoading;
    final mq        = MediaQuery.of(context);
    final topPad    = mq.viewPadding.top;
    final h         = mq.size.height;

    return Scaffold(
      backgroundColor: _kBg,
      // Don't resize — the layout is fixed to the screen; fields are accessible
      // by tapping and the card is already in the lower half.
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Spine illustration — left edge ────────────────────────
          Positioned(
            left: 0, top: topPad + 60,
            child: Opacity(
              opacity: 0.30,
              child: SizedBox(
                width: 64, height: h * 0.55,
                child: CustomPaint(painter: _SpinePainter()),
              ),
            ),
          ),

          // ── Brain illustration — right edge ──────────────────────
          Positioned(
            right: 4, top: topPad + 140,
            child: Opacity(
              opacity: 0.28,
              child: SizedBox(
                width: 100, height: 120,
                child: CustomPaint(painter: _BrainPainter()),
              ),
            ),
          ),

          // ── Bottom wave ──────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SizedBox(
              height: 48,
              child: CustomPaint(painter: _WavePainter()),
            ),
          ),

          // ── Main fixed column ────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Dark navy top oval with logo
                  SizedBox(
                    height: h * 0.26,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.bottomCenter,
                      children: [
                        Positioned.fill(
                          child: ClipPath(
                            clipper: _OvalBottomClipper(),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: -20),
                              color: _kNavy,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -h * 0.07,
                          child: Image.asset(
                            'assets/images/app_logo.png',
                            width: h * 0.130,
                            height: h * 0.155,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: h * 0.068),

                  // Clinic name
                  const Text(
                    'The Brain &\nSpine Clinic',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: _kNavy,
                      height: 1.15,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ECG line + tagline
                  SizedBox(
                    width: 110, height: 20,
                    child: CustomPaint(painter: _EcgPainter()),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Excellence. Ethics. Efficiency',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF616161),
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Login card ────────────────────────────────────
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: _kNavy.withValues(alpha: 0.10),
                            blurRadius: 28,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Role toggle
                            Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F0F0),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(children: [
                                _RoleTab(
                                  label: 'Doctor',
                                  icon: Icons.medical_services_outlined,
                                  active: _roleIndex == 0,
                                  onTap: () => setState(() => _roleIndex = 0),
                                ),
                                _RoleTab(
                                  label: 'Front Desk',
                                  icon: Icons.support_agent_outlined,
                                  active: _roleIndex == 1,
                                  onTap: () => setState(() => _roleIndex = 1),
                                ),
                              ]),
                            ),

                            const SizedBox(height: 14),

                            // Email
                            _FieldLabel('Email'),
                            const SizedBox(height: 5),
                            _InputField(
                              controller: _emailCtrl,
                              hint: 'admin@medimanage.com',
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: (v) =>
                                  v?.trim().isEmpty == true ? 'Email is required' : null,
                            ),

                            const SizedBox(height: 12),

                            // Password
                            _FieldLabel('Password'),
                            const SizedBox(height: 5),
                            _InputField(
                              controller: _passCtrl,
                              hint: '••••••••••••',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscure,
                              textInputAction: TextInputAction.done,
                              onSubmit: _submit,
                              suffix: GestureDetector(
                                onTap: () => setState(() => _obscure = !_obscure),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 19,
                                    color: _kMuted,
                                  ),
                                ),
                              ),
                              validator: (v) {
                                if (v?.isEmpty == true) return 'Password is required';
                                if ((v?.length ?? 0) < 6) return 'Min 6 characters';
                                return null;
                              },
                            ),

                            // Forgot password
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(
                                  foregroundColor: _kBlue,
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 4),

                            // Login button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _kNavy,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        width: 22, height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Login',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Container(
                                            width: 32, height: 32,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 17, color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Secure badge
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                    Icon(Icons.shield_outlined, size: 13, color: _kMuted),
                    SizedBox(width: 4),
                    Text('Secure clinical access',
                        style: TextStyle(fontSize: 11, color: _kMuted)),
                  ]),

                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Oval top clipper ───────────────────────────────────────────────────────────
class _OvalBottomClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 50);
    path.quadraticBezierTo(
      size.width / 2, size.height + 55,
      size.width, size.height - 50,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_) => false;
}

// ── Role tab ───────────────────────────────────────────────────────────────────
class _RoleTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _RoleTab({
    required this.label, required this.icon,
    required this.active, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: active ? _kNavy : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active
              ? [BoxShadow(
                  color: _kNavy.withValues(alpha: 0.28),
                  blurRadius: 6, offset: const Offset(0, 3))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: active ? Colors.white : _kMuted),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: active ? Colors.white : _kMuted,
                )),
          ],
        ),
      ),
    ),
  );
}

// ── Field label ────────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(label,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: _kLabel)),
  );
}

// ── Input field ────────────────────────────────────────────────────────────────
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Widget? suffix;
  final VoidCallback? onSubmit;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller, required this.hint, required this.icon,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.suffix, this.onSubmit, this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    validator: validator,
    onFieldSubmitted: onSubmit != null ? (_) => onSubmit!() : null,
    style: const TextStyle(fontSize: 14, color: _kLabel),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _kMuted, fontSize: 14),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 14, right: 10),
        child: Icon(icon, color: _kMuted, size: 18),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      filled: true,
      fillColor: const Color(0xFFF7F7F7),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kNavy, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kRed)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kRed, width: 1.5)),
    ),
  );
}

// ── ECG divider ────────────────────────────────────────────────────────────────
class _EcgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kNavy.withValues(alpha: 0.55)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final h = size.height / 2;
    final path = Path()
      ..moveTo(0, h)
      ..lineTo(size.width * 0.28, h)
      ..lineTo(size.width * 0.36, h - size.height * 0.45)
      ..lineTo(size.width * 0.43, h + size.height * 0.45)
      ..lineTo(size.width * 0.50, h - size.height * 0.30)
      ..lineTo(size.width * 0.56, h)
      ..lineTo(size.width, h);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Bottom wave ────────────────────────────────────────────────────────────────
class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Paint()
      ..color = const Color(0xFFBBCEEC).withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    final p2 = Paint()
      ..color = const Color(0xFF90AEE0).withValues(alpha: 0.40)
      ..style = PaintingStyle.fill;
    final path1 = Path()
      ..moveTo(0, size.height * 0.45)
      ..quadraticBezierTo(size.width * 0.25, 0, size.width * 0.5, size.height * 0.45)
      ..quadraticBezierTo(size.width * 0.75, size.height * 0.9, size.width, size.height * 0.45)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final path2 = Path()
      ..moveTo(0, size.height * 0.6)
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.1, size.width * 0.6, size.height * 0.6)
      ..quadraticBezierTo(size.width * 0.8, size.height, size.width, size.height * 0.65)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path1, p1);
    canvas.drawPath(path2, p2);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Spine illustration ─────────────────────────────────────────────────────────
class _SpinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kNavy
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cx = size.width * 0.55;
    // Central canal
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), paint);

    // Vertebrae
    const count = 12;
    final segH = size.height / count;
    for (int i = 0; i < count; i++) {
      final cy = i * segH + segH * 0.5;
      // Vertebral body (rectangle)
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: 28, height: segH * 0.42),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, paint);
      // Left transverse process
      canvas.drawLine(Offset(cx - 14, cy), Offset(0, cy - 4), paint);
      // Right transverse process (short, clipped by edge)
      canvas.drawLine(Offset(cx + 14, cy), Offset(size.width, cy - 4), paint);
      // Spinous process
      if (i > 0) {
        canvas.drawLine(
          Offset(cx, cy - segH * 0.35),
          Offset(cx + 8, cy - segH * 0.55),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Brain illustration ─────────────────────────────────────────────────────────
class _BrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kNavy
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width * 0.46;
    final cy = size.height * 0.42;
    final rx = size.width * 0.38;
    final ry = size.height * 0.38;

    // Left hemisphere outline
    final leftPath = Path()
      ..moveTo(cx, cy - ry)
      ..cubicTo(cx - rx * 1.3, cy - ry * 0.8,
                cx - rx * 1.3, cy + ry * 0.5,
                cx, cy + ry * 0.6);
    canvas.drawPath(leftPath, paint);

    // Right hemisphere outline
    final rightPath = Path()
      ..moveTo(cx, cy - ry)
      ..cubicTo(cx + rx * 1.2, cy - ry * 0.8,
                cx + rx * 1.0, cy + ry * 0.45,
                cx, cy + ry * 0.6);
    canvas.drawPath(rightPath, paint);

    // Central fissure
    canvas.drawLine(Offset(cx, cy - ry), Offset(cx, cy + ry * 0.6), paint);

    // Brain stem
    canvas.drawLine(Offset(cx, cy + ry * 0.6), Offset(cx, size.height), paint);

    // Gyri — left hemisphere
    for (int i = 0; i < 3; i++) {
      final y = cy - ry * 0.5 + i * ry * 0.38;
      final gyrus = Path()
        ..moveTo(cx - 8, y)
        ..cubicTo(cx - rx * 0.7, y - ry * 0.18,
                  cx - rx * 1.0, y + ry * 0.18,
                  cx - rx * 0.55, y + ry * 0.08);
      canvas.drawPath(gyrus, paint);
    }

    // Gyri — right hemisphere
    for (int i = 0; i < 3; i++) {
      final y = cy - ry * 0.45 + i * ry * 0.35;
      final gyrus = Path()
        ..moveTo(cx + 8, y)
        ..cubicTo(cx + rx * 0.65, y - ry * 0.18,
                  cx + rx * 0.9, y + ry * 0.18,
                  cx + rx * 0.5, y + ry * 0.08);
      canvas.drawPath(gyrus, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ignore: unused_element
double _toRad(double deg) => deg * math.pi / 180;

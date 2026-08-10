import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../providers/auth_provider.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kNavy    = Color(0xFF1A237E);
const _kBlue    = Color(0xFF283593);
const _kBg      = Color(0xFFE8EEF8);
const _kCardBg  = Colors.white;
const _kRed     = Color(0xFFEF4444);
const _kMuted   = Color(0xFF9E9E9E);
const _kLabel   = Color(0xFF212121);
const _kBorder  = Color(0xFFE0E0E0);

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
  int  _roleIndex  = 0; // 0=Doctor, 1=Front Desk

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

    return Scaffold(
      backgroundColor: _kBg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Decorative anatomy illustrations ───────────────────────
          Positioned(
            left: -10, top: topPad + 80,
            child: Opacity(
              opacity: 0.18,
              child: _SpineIllustration(),
            ),
          ),
          Positioned(
            right: -8, top: topPad + 110,
            child: Opacity(
              opacity: 0.15,
              child: _BrainIllustration(),
            ),
          ),

          // ── Main scrollable content ────────────────────────────────
          SingleChildScrollView(
            child: Column(children: [
              // ── Dark blue top oval with logo ────────────────────────
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  ClipPath(
                    clipper: _OvalBottomClipper(),
                    child: Container(
                      width: double.infinity,
                      height: topPad + 180,
                      color: _kNavy,
                    ),
                  ),
                  // Logo badge — overlaps the oval
                  Positioned(
                    bottom: -90,
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      width: 155,
                      height: 195,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),

              // Space for logo overlap
              const SizedBox(height: 100),

              // ── Clinic name ─────────────────────────────────────────
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'The Brain &\nSpine Clinic',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: _kNavy,
                    height: 1.15,
                    letterSpacing: -0.5,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── ECG heartbeat line + tagline ────────────────────────
              const _EcgDivider(),
              const SizedBox(height: 8),
              const Text(
                'Excellence. Ethics. Efficiency',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF616161),
                  fontStyle: FontStyle.italic,
                  letterSpacing: 0.1,
                ),
              ),

              const SizedBox(height: 24),

              // ── Login card ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: _kCardBg,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: _kNavy.withValues(alpha: 0.10),
                        blurRadius: 32,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(children: [
                      // Role toggle
                      Container(
                        height: 52,
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

                      const SizedBox(height: 20),

                      // Email
                      _FieldLabel('Email'),
                      const SizedBox(height: 6),
                      _InputField(
                        controller: _emailCtrl,
                        hint: 'admin@medimanage.com',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            v?.trim().isEmpty == true ? 'Email is required' : null,
                      ),

                      const SizedBox(height: 16),

                      // Password
                      _FieldLabel('Password'),
                      const SizedBox(height: 6),
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
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
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
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Forgot password?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Login button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
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
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Login',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),

              // ── Secure badge ────────────────────────────────────────
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.shield_outlined, size: 14, color: _kMuted),
                const SizedBox(width: 5),
                const Text(
                  'Secure clinical access',
                  style: TextStyle(fontSize: 12, color: _kMuted),
                ),
              ]),

              const SizedBox(height: 16),

              // ── Bottom wave ─────────────────────────────────────────
              _BottomWave(),
            ]),
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
    path.lineTo(0, size.height - 60);
    path.quadraticBezierTo(
      size.width / 2, size.height + 60,
      size.width, size.height - 60,
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
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
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
              ? [
                  BoxShadow(
                    color: _kNavy.withValues(alpha: 0.30),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: active ? Colors.white : _kMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : _kMuted,
              ),
            ),
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
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: _kLabel,
      ),
    ),
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
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.suffix,
    this.onSubmit,
    this.validator,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
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
class _EcgDivider extends StatelessWidget {
  const _EcgDivider();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 120,
    height: 24,
    child: CustomPaint(painter: _EcgPainter()),
  );
}

class _EcgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kNavy.withValues(alpha: 0.6)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final h = size.height / 2;
    final path = Path();
    path.moveTo(0, h);
    path.lineTo(size.width * 0.28, h);
    path.lineTo(size.width * 0.35, h - size.height * 0.45);
    path.lineTo(size.width * 0.42, h + size.height * 0.45);
    path.lineTo(size.width * 0.50, h - size.height * 0.35);
    path.lineTo(size.width * 0.55, h);
    path.lineTo(size.width, h);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Bottom wave ────────────────────────────────────────────────────────────────
class _BottomWave extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 60,
    child: CustomPaint(painter: _WavePainter()),
  );
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = const Color(0xFFBBCEEC).withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;
    final paint2 = Paint()
      ..color = const Color(0xFF90AEE0).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final path1 = Path();
    path1.moveTo(0, size.height * 0.5);
    path1.quadraticBezierTo(
        size.width * 0.25, size.height * 0.1,
        size.width * 0.5, size.height * 0.5);
    path1.quadraticBezierTo(
        size.width * 0.75, size.height * 0.9,
        size.width, size.height * 0.5);
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();

    final path2 = Path();
    path2.moveTo(0, size.height * 0.65);
    path2.quadraticBezierTo(
        size.width * 0.3, size.height * 0.2,
        size.width * 0.6, size.height * 0.65);
    path2.quadraticBezierTo(
        size.width * 0.8, size.height * 0.95,
        size.width, size.height * 0.7);
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();

    canvas.drawPath(path1, paint1);
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Spine illustration (decorative) ───────────────────────────────────────────
class _SpineIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 52,
    height: 280,
    child: CustomPaint(painter: _SpinePainter()),
  );
}

class _SpinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kNavy
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    // Central canal line
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), paint);

    // Vertebrae segments
    const segments = 10;
    final segH = size.height / segments;
    for (int i = 0; i < segments; i++) {
      final y = i * segH + segH * 0.3;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, y + segH * 0.2),
          width: size.width * 0.85,
          height: segH * 0.38,
        ),
        const Radius.circular(3),
      );
      canvas.drawRRect(rect, paint);
      // Transverse processes
      canvas.drawLine(Offset(cx - size.width * 0.42, y + segH * 0.2),
          Offset(0, y + segH * 0.2 - 6), paint);
      canvas.drawLine(Offset(cx + size.width * 0.42, y + segH * 0.2),
          Offset(size.width, y + segH * 0.2 - 6), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Brain illustration (decorative) ───────────────────────────────────────────
class _BrainIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 90,
    height: 110,
    child: CustomPaint(painter: _BrainPainter()),
  );
}

class _BrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kNavy
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final cx = size.width * 0.5;
    final cy = size.height * 0.45;

    // Outer brain outline (two hemispheres)
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx - 10, cy), width: 68, height: 70),
      math.pi * 0.9, math.pi * 1.2, false, paint,
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx + 10, cy), width: 64, height: 68),
      math.pi * 1.85, math.pi * 1.2, false, paint,
    );
    // Central fissure
    canvas.drawLine(Offset(cx, cy - 33), Offset(cx, cy + 5), paint);
    // Brain stem
    canvas.drawLine(Offset(cx, cy + 32), Offset(cx, size.height), paint);
    // Gyri (folds) - simple curved lines
    for (int i = 0; i < 3; i++) {
      final y0 = cy - 18 + i * 14.0;
      final path = Path();
      path.moveTo(cx - 24, y0);
      path.cubicTo(cx - 16, y0 - 8, cx - 8, y0 + 8, cx, y0);
      canvas.drawPath(path, paint);
      final path2 = Path();
      path2.moveTo(cx, y0);
      path2.cubicTo(cx + 8, y0 - 8, cx + 16, y0 + 8, cx + 24, y0);
      canvas.drawPath(path2, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

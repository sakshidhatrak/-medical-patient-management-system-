// ─────────────────────────────────────────────────────────────────────────────
// login_screen.dart  –  MediManage Premium Login  (Linear × Stripe aesthetics)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../providers/auth_provider.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kP1     = Color(0xFF7C3AED);   // purple
const _kP2     = Color(0xFF3B82F6);   // blue
const _kRed    = Color(0xFFEF4444);
const _kNavy   = Color(0xFF0F172A);
const _kSlate  = Color(0xFF475569);
const _kMuted  = Color(0xFF94A3B8);
const _kBorder = Color(0xFFE2E8F0);
const _kBgSurf = Color(0xFFF8FAFC);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure  = true;
  bool _remember = false;

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
    final w         = MediaQuery.of(context).size.width;
    final wide      = w > 640;

    return Scaffold(
      backgroundColor: _kBgSurf,
      body: Stack(children: [
        // ── Gradient mesh background ──────────────────────────────
        Positioned.fill(child: _MeshBg()),

        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: wide ? 0 : 20, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(children: [
                  _LoginCard(
                    formKey: _formKey,
                    emailCtrl: _emailCtrl,
                    passCtrl: _passCtrl,
                    obscure: _obscure,
                    remember: _remember,
                    isLoading: isLoading,
                    onToggleObscure: () => setState(() => _obscure = !_obscure),
                    onToggleRemember: (v) => setState(() => _remember = v ?? false),
                    onSubmit: _submit,
                  ),
                  const SizedBox(height: 32),
                  _TrustRow(),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Gradient mesh background ──────────────────────────────────────────────────
class _MeshBg extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF5F3FF), Color(0xFFEFF6FF), Color(0xFFF8FAFC)],
        stops: [0.0, 0.5, 1.0],
      ),
    ),
    child: Stack(children: [
      Positioned(
        top: -80, left: -60,
        child: _Orb(220, _kP1, 0.08),
      ),
      Positioned(
        bottom: 40, right: -80,
        child: _Orb(260, _kP2, 0.07),
      ),
      Positioned(
        top: 200, right: -40,
        child: _Orb(140, _kP1, 0.05),
      ),
    ]),
  );
}

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  const _Orb(this.size, this.color, this.opacity);
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [
        color.withValues(alpha: opacity),
        color.withValues(alpha: 0),
      ]),
    ),
  );
}

// ── Login card ────────────────────────────────────────────────────────────────
class _LoginCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool obscure, remember, isLoading;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool?> onToggleRemember;
  final VoidCallback onSubmit;

  const _LoginCard({
    required this.formKey,
    required this.emailCtrl,
    required this.passCtrl,
    required this.obscure,
    required this.remember,
    required this.isLoading,
    required this.onToggleObscure,
    required this.onToggleRemember,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(32, 36, 32, 32),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _kBorder),
      boxShadow: [
        BoxShadow(
          color: _kP1.withValues(alpha: 0.06),
          blurRadius: 48,
          offset: const Offset(0, 16),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Form(
      key: formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── Logo + brand ─────────────────────────────────
        Center(
          child: Column(children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_kP1, _kP2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _kP1.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 14),
            ShaderMask(
              shaderCallback: (r) => const LinearGradient(
                colors: [_kP1, _kP2],
              ).createShader(r),
              child: const Text(
                'MediManage',
                style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800,
                  color: Colors.white, letterSpacing: -0.6,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Clinical workflow reimagined',
              style: TextStyle(fontSize: 12, color: _kMuted),
            ),
          ]),
        ),

        const SizedBox(height: 28),
        const _Divider(),
        const SizedBox(height: 24),

        // ── Welcome ──────────────────────────────────────
        const Text('Welcome back',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                color: _kNavy, letterSpacing: -0.4)),
        const SizedBox(height: 4),
        const Text('Sign in to access your clinic dashboard',
            style: TextStyle(fontSize: 13, color: _kSlate)),

        const SizedBox(height: 24),

        // ── Email ────────────────────────────────────────
        _PremiumField(
          controller: emailCtrl,
          hint: 'Email address',
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: (v) => v?.trim().isEmpty == true ? 'Email is required' : null,
        ),
        const SizedBox(height: 12),

        // ── Password ─────────────────────────────────────
        _PremiumField(
          controller: passCtrl,
          hint: 'Password',
          icon: Icons.lock_outline_rounded,
          obscure: obscure,
          textInputAction: TextInputAction.done,
          onSubmit: onSubmit,
          suffix: IconButton(
            icon: Icon(
              obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 20, color: _kMuted,
            ),
            onPressed: onToggleObscure,
          ),
          validator: (v) {
            if (v?.isEmpty == true) return 'Password is required';
            if ((v?.length ?? 0) < 6) return 'Minimum 6 characters';
            return null;
          },
        ),
        const SizedBox(height: 14),

        // ── Remember / Forgot ─────────────────────────────
        Row(children: [
          GestureDetector(
            onTap: () => onToggleRemember(!remember),
            child: Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                gradient: remember
                    ? const LinearGradient(colors: [_kP1, _kP2])
                    : null,
                color: remember ? null : Colors.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: remember ? Colors.transparent : _kBorder,
                  width: 1.5,
                ),
              ),
              child: remember
                  ? const Icon(Icons.check, color: Colors.white, size: 13)
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          const Text('Remember me', style: TextStyle(fontSize: 13, color: _kSlate)),
          const Spacer(),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              foregroundColor: _kP1,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Forgot password?',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),

        const SizedBox(height: 22),

        // ── Sign In button ────────────────────────────────
        _GradientButton(
          onPressed: isLoading ? null : onSubmit,
          child: isLoading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                  Text('Sign In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ]),
        ),

        const SizedBox(height: 20),

        // ── Divider ───────────────────────────────────────
        Row(children: [
          const Expanded(child: Divider(color: _kBorder)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('or continue with',
                style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          ),
          const Expanded(child: Divider(color: _kBorder)),
        ]),

        const SizedBox(height: 14),

        // ── Social buttons ────────────────────────────────
        Row(children: [
          Expanded(child: _SocialBtn(label: 'Google', icon: _GoogleIcon(), onTap: () {})),
          const SizedBox(width: 10),
          Expanded(child: _SocialBtn(label: 'Microsoft', icon: _MsIcon(), onTap: () {})),
        ]),

        const SizedBox(height: 20),

        Center(
          child: Wrap(alignment: WrapAlignment.center, children: [
            const Text("Don't have an account?  ",
                style: TextStyle(fontSize: 12, color: _kMuted)),
            GestureDetector(
              onTap: () {},
              child: ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [_kP1, _kP2],
                ).createShader(r),
                child: const Text('Contact Administrator',
                    style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ]),
    ),
  );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Container(height: 1, color: _kBorder);
}

// ── Gradient button ───────────────────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  const _GradientButton({required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onPressed,
    child: AnimatedOpacity(
      opacity: onPressed == null ? 0.6 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_kP1, _kP2]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _kP1.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
          child: IconTheme(data: const IconThemeData(color: Colors.white), child: child),
        ),
      ),
    ),
  );
}

// ── Premium field ─────────────────────────────────────────────────────────────
class _PremiumField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Widget? suffix;
  final VoidCallback? onSubmit;
  final String? Function(String?)? validator;

  const _PremiumField({
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
    style: const TextStyle(fontSize: 14, color: _kNavy, fontWeight: FontWeight.w500),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _kMuted, fontSize: 14),
      prefixIcon: Icon(icon, color: _kMuted, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: _kBgSurf,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kP1, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kRed)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kRed, width: 1.5)),
    ),
  );
}

// ── Social button ─────────────────────────────────────────────────────────────
class _SocialBtn extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onTap;
  const _SocialBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        icon,
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kNavy)),
      ]),
    ),
  );
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Text('G',
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF4285F4)));
}

class _MsIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 16, height: 16,
    child: GridView.count(
      crossAxisCount: 2, padding: EdgeInsets.zero,
      crossAxisSpacing: 1.5, mainAxisSpacing: 1.5,
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        ColoredBox(color: Color(0xFFF35325)),
        ColoredBox(color: Color(0xFF81BC06)),
        ColoredBox(color: Color(0xFF05A6F0)),
        ColoredBox(color: Color(0xFFFFBA08)),
      ],
    ),
  );
}

// ── Trust row ─────────────────────────────────────────────────────────────────
class _TrustRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(children: [
    _TrustBadge(
      icon: Icons.verified_user_outlined,
      label: 'HIPAA Compliant',
      sub: 'End-to-end encrypted',
      color: const Color(0xFF10B981),
    ),
    const SizedBox(width: 10),
    _TrustBadge(
      icon: Icons.bolt_rounded,
      label: '99.9% Uptime',
      sub: 'Always available',
      color: _kP2,
    ),
    const SizedBox(width: 10),
    _TrustBadge(
      icon: Icons.people_outline_rounded,
      label: '10K+ Patients',
      sub: 'Trusted by doctors',
      color: _kP1,
    ),
  ]);
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  const _TrustBadge({required this.icon, required this.label, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 7),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kNavy),
            textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(sub, style: const TextStyle(fontSize: 9, color: _kMuted), textAlign: TextAlign.center),
      ]),
    ),
  );
}

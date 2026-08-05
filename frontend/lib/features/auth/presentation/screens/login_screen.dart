import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../providers/auth_provider.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kPrimary  = Color(0xFF4B55CC);
const _kPrimSurf = Color(0xFFE8EBF8);
const _kPrimText = Color(0xFF3D47B4);
const _kBg       = Color(0xFFF8F6F2);
const _kBorder   = Color(0xFFE0DDD7);
const _kNavy     = Color(0xFF302D28);
const _kSlate    = Color(0xFF6E6A63);
const _kMuted    = Color(0xFF979088);
const _kRed      = Color(0xFFEF4444);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  bool _obscure     = true;
  int  _roleIndex   = 0; // 0=Doctor, 1=Front Desk (visual only)

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
    final vp = MediaQuery.of(context).viewPadding;

    return Scaffold(
      backgroundColor: _kBg,
      resizeToAvoidBottomInset: true,
      body: Column(children: [
        // ── Primary colored header ──────────────────────────────────
        _Header(topPadding: vp.top),

        // ── Scrollable form area ────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(children: [
              // Role tabs card
              Container(
                margin: const EdgeInsets.only(top: 0),
                transform: Matrix4.translationValues(0, -20, 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(children: [
                      // Role selector
                      Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFECEAE4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          _RoleTab(label: 'Doctor', active: _roleIndex == 0,
                              onTap: () => setState(() => _roleIndex = 0)),
                          _RoleTab(label: 'Front Desk', active: _roleIndex == 1,
                              onTap: () => setState(() => _roleIndex = 1)),
                        ]),
                      ),

                      const SizedBox(height: 18),

                      // Email
                      _FieldLabel(label: 'Email'),
                      const SizedBox(height: 6),
                      _InputField(
                        controller: _emailCtrl,
                        hint: 'you@clinic.com',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (v) => v?.trim().isEmpty == true ? 'Email is required' : null,
                      ),

                      const SizedBox(height: 14),

                      // Password
                      _FieldLabel(label: 'Password'),
                      const SizedBox(height: 6),
                      _InputField(
                        controller: _passCtrl,
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscure,
                        textInputAction: TextInputAction.done,
                        onSubmit: _submit,
                        suffix: GestureDetector(
                          onTap: () => setState(() => _obscure = !_obscure),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              _obscure ? 'Show' : 'Hide',
                              style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: _kPrimary,
                              ),
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v?.isEmpty == true) return 'Password is required';
                          if ((v?.length ?? 0) < 6) return 'Min 6 characters';
                          return null;
                        },
                      ),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            foregroundColor: _kPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Forgot password?',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Sign In button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kPrimary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: _kPrimary.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13)),
                            textStyle: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('Sign In'),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),

              // Secure badge
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                Icon(Icons.shield_outlined, size: 13, color: _kMuted),
                SizedBox(width: 5),
                Text('Secure clinical access',
                    style: TextStyle(fontSize: 11, color: _kMuted)),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final double topPadding;
  const _Header({required this.topPadding});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: const BoxDecoration(
      color: _kPrimary,
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(32),
        bottomRight: Radius.circular(32),
      ),
    ),
    padding: EdgeInsets.fromLTRB(26, topPadding + 36, 26, 48),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      // Logo icon
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(Icons.monitor_heart_outlined, color: Colors.white, size: 28),
      ),
      const SizedBox(height: 14),
      const Text('MediCare',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w700,
              color: Colors.white, letterSpacing: -0.3)),
      const SizedBox(height: 3),
      Text('Neurosurgery Care Platform',
          style: TextStyle(
              fontSize: 12.5, color: Colors.white.withValues(alpha: 0.75))),
    ]),
  );
}

// ── Role tab ───────────────────────────────────────────────────────────────────
class _RoleTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _RoleTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: active
              ? [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? _kNavy : _kSlate,
            )),
      ),
    ),
  );
}

// ── Field label ────────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(label,
        style: const TextStyle(
            fontSize: 11.5, fontWeight: FontWeight.w600, color: _kSlate)),
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
    style: const TextStyle(fontSize: 14, color: _kNavy),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _kMuted, fontSize: 14),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 14, right: 8),
        child: Icon(icon, color: _kMuted, size: 16),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kRed)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kRed, width: 1.5)),
    ),
  );
}

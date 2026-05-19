import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final String? errorText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool isPassword;
  final bool readOnly;
  final bool enabled;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final FormFieldValidator<String>? validator;
  final int? maxLines;
  final int? maxLength;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? prefixText;
  final AutovalidateMode autovalidateMode;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.errorText,
    this.controller,
    this.focusNode,
    this.isPassword = false,
    this.readOnly = false,
    this.enabled = true,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.inputFormatters,
    this.onChanged,
    this.onTap,
    this.validator,
    this.maxLines = 1,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.prefixText,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscured = true;

  // A field is multiline when it's not a password field and maxLines is either
  // null (unbounded) or explicitly greater than 1.
  bool get _isMultiline =>
      !widget.isPassword &&
      (widget.maxLines == null || widget.maxLines! > 1);

  // On web, multiline fields must use TextInputType.multiline so that the
  // browser creates a <textarea> and Enter inserts a newline instead of
  // submitting the form. Only override when the caller left the default.
  TextInputType get _effectiveKeyboardType {
    if (_isMultiline && widget.keyboardType == TextInputType.text) {
      return TextInputType.multiline;
    }
    return widget.keyboardType;
  }

  // Pair with multiline keyboard: swap TextInputAction.next → newline so that
  // the Enter key produces a newline instead of moving focus.
  TextInputAction get _effectiveTextInputAction {
    if (_isMultiline && widget.textInputAction == TextInputAction.next) {
      return TextInputAction.newline;
    }
    return widget.textInputAction;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: widget.isPassword && _obscured,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      keyboardType: _effectiveKeyboardType,
      textInputAction: _effectiveTextInputAction,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      onTap: widget.onTap,
      validator: widget.validator,
      maxLines: widget.isPassword ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      autovalidateMode: widget.autovalidateMode,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        errorText: widget.errorText,
        prefixIcon: widget.prefixIcon,
        prefixText: widget.prefixText,
        suffixIcon: widget.isPassword
            ? IconButton(
                onPressed: () => setState(() => _obscured = !_obscured),
                icon: Icon(
                  _obscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              )
            : widget.suffixIcon,
        counterText: '',
      ),
    );
  }
}

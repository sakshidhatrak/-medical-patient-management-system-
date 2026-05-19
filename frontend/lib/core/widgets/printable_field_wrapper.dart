import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// Wraps any form field with double-tap-to-print-select behaviour.
///
/// SELECTED state — highly visible:
///   • 2 px solid primary border
///   • Light purple background tint
///   • Left accent bar (3 px)
///   • Filled print badge (top-right, inside the field)
///   • "PRINT" micro-label under the badge
///
/// HOVER state (desktop/web):
///   • Outline badge appears as a hint
///   • Tooltip: "Double-click to add to print"
///
/// Both double-tap AND badge click toggle the selection.
class PrintableFieldWrapper extends StatefulWidget {
  final String fieldId;
  final bool isSelected;
  final VoidCallback onToggle;
  final Widget child;

  const PrintableFieldWrapper({
    super.key,
    required this.fieldId,
    required this.isSelected,
    required this.onToggle,
    required this.child,
  });

  @override
  State<PrintableFieldWrapper> createState() =>
      _PrintableFieldWrapperState();
}

class _PrintableFieldWrapperState extends State<PrintableFieldWrapper>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.015).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!widget.isSelected) {
      _scaleCtrl.forward().then((_) => _scaleCtrl.reverse());
    }
    widget.onToggle();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onDoubleTap: _toggle,
        behavior: HitTestBehavior.translucent,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Main container with selection styling ───────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                decoration: widget.isSelected
                    ? BoxDecoration(
                        color: AppColors.primary.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(
                            AppDimensions.radiusLg),
                        border: Border.all(
                          color: AppColors.primary,
                          width: 2.0,
                        ),
                      )
                    : BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(
                            AppDimensions.radiusLg),
                        border: Border.all(
                          color: Colors.transparent,
                          width: 2.0,
                        ),
                      ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left accent bar
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 3,
                      decoration: BoxDecoration(
                        color: widget.isSelected
                            ? AppColors.primary
                            : Colors.transparent,
                        borderRadius: const BorderRadius.only(
                          topLeft:
                              Radius.circular(AppDimensions.radiusLg),
                          bottomLeft:
                              Radius.circular(AppDimensions.radiusLg),
                        ),
                      ),
                    ),

                    // The actual field
                    Expanded(child: widget.child),
                  ],
                ),
              ),

              // ── Print badge (top-right, inside the field) ───────────
              Positioned(
                top: 6,
                right: 6,
                child: Tooltip(
                  message: widget.isSelected
                      ? 'Remove from print  (double-click)'
                      : 'Add to print  (double-click)',
                  waitDuration: const Duration(milliseconds: 500),
                  child: GestureDetector(
                    onTap: _toggle,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: (widget.isSelected || _hovered) ? 1.0 : 0.0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.isSelected
                              ? AppColors.primary
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(
                              AppDimensions.radiusMd),
                          border: Border.all(
                            color: widget.isSelected
                                ? AppColors.primary
                                : AppColors.border,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.isSelected
                                  ? Icons.print_rounded
                                  : Icons.print_outlined,
                              size: 12,
                              color: widget.isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.isSelected
                                  ? 'IN PRINT'
                                  : 'ADD TO PRINT',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: widget.isSelected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

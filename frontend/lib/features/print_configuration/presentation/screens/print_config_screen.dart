import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../widgets/config_left_panel.dart';
import '../widgets/preview_right_panel.dart';
import '../widgets/report_action_bar.dart';

// Breakpoints
const double _kDesktopBreak = 900;
const double _kTabletBreak = 600;

class PrintConfigScreen extends ConsumerStatefulWidget {
  const PrintConfigScreen({super.key});

  @override
  ConsumerState<PrintConfigScreen> createState() =>
      _PrintConfigScreenState();
}

class _PrintConfigScreenState
    extends ConsumerState<PrintConfigScreen> {
  bool _configPanelVisible = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= _kDesktopBreak) {
            return _DesktopLayout(
              configVisible: _configPanelVisible,
            );
          }
          if (constraints.maxWidth >= _kTabletBreak) {
            return _TabletLayout(
              configVisible: _configPanelVisible,
              onTogglePanel: () =>
                  setState(() => _configPanelVisible = !_configPanelVisible),
            );
          }
          return const _MobileLayout();
        },
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 18, color: AppColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius:
                  BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: const Icon(Icons.print_rounded,
                size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: AppDimensions.sm),
          const Text(
            'Report Generator',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      actions: [
        LayoutBuilder(
          builder: (ctx, constraints) {
            if (MediaQuery.of(context).size.width >= _kTabletBreak &&
                MediaQuery.of(context).size.width < _kDesktopBreak) {
              return IconButton(
                tooltip: _configPanelVisible
                    ? 'Hide configuration'
                    : 'Show configuration',
                icon: Icon(
                  _configPanelVisible
                      ? Icons.view_sidebar_rounded
                      : Icons.view_sidebar_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onPressed: () => setState(
                    () => _configPanelVisible = !_configPanelVisible),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        const SizedBox(width: AppDimensions.sm),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(48),
        child: ReportActionBar(),
      ),
    );
  }
}

// ── Desktop Layout — side-by-side 30/70 ──────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  final bool configVisible;

  const _DesktopLayout({required this.configVisible});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: SizedBox(
            width: configVisible ? 320 : 0,
            child: configVisible
                ? const ConfigLeftPanel()
                : const SizedBox.shrink(),
          ),
        ),
        const Expanded(child: PreviewRightPanel()),
      ],
    );
  }
}

// ── Tablet Layout — collapsible left panel ────────────────────────────────────

class _TabletLayout extends StatelessWidget {
  final bool configVisible;
  final VoidCallback onTogglePanel;

  const _TabletLayout({
    required this.configVisible,
    required this.onTogglePanel,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const PreviewRightPanel(),
        AnimatedSlide(
          offset: configVisible ? Offset.zero : const Offset(-1, 0),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          child: SizedBox(
            width: 300,
            child: const ConfigLeftPanel(),
          ),
        ),
      ],
    );
  }
}

// ── Mobile Layout — bottom sheet config ──────────────────────────────────────

class _MobileLayout extends ConsumerWidget {
  const _MobileLayout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        const PreviewRightPanel(),
        Positioned(
          bottom: AppDimensions.lg,
          right: AppDimensions.lg,
          child: FloatingActionButton.extended(
            onPressed: () => _showConfigSheet(context),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 4,
            icon: const Icon(Icons.tune_rounded),
            label: const Text(
              'Configure',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  void _showConfigSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppDimensions.radiusXl),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Expanded(child: ConfigLeftPanel()),
            ],
          ),
        ),
      ),
    );
  }
}

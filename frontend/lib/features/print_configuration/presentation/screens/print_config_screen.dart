import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../services/pdf_export_service.dart';
import '../providers/print_config_provider.dart';
import '../widgets/preview_right_panel.dart';

class PrintConfigScreen extends ConsumerWidget {
  const PrintConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0EDE6),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Color(0xFF1A2D5A)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Patient Report',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A2D5A),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded,
                size: 20, color: Color(0xFF1A2D5A)),
            tooltip: 'Print / Share',
            onPressed: () async {
              final config = ref.read(printConfigProvider);
              final patientData = ref.read(activePatientDataProvider);
              try {
                await PdfExportService.exportPdf(
                  config,
                  patientData: patientData,
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Export failed: $e')),
                  );
                }
              }
            },
          ),
          const SizedBox(width: AppDimensions.xs),
        ],
      ),
      body: const PreviewRightPanel(),
    );
  }
}

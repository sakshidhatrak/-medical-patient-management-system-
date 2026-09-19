import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../print_configuration/presentation/providers/print_config_provider.dart';
import '../../../print_configuration/services/pdf_export_service.dart';

const _secureChannel = MethodChannel('com.medimanage/window_secure');

class StaffReportPreviewScreen extends ConsumerStatefulWidget {
  final Map<String, String> patientData;

  const StaffReportPreviewScreen({super.key, required this.patientData});

  @override
  ConsumerState<StaffReportPreviewScreen> createState() =>
      _StaffReportPreviewScreenState();
}

class _StaffReportPreviewScreenState
    extends ConsumerState<StaffReportPreviewScreen> {
  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      _secureChannel.invokeMethod('addSecureFlag');
    }
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      _secureChannel.invokeMethod('clearSecureFlag');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(printConfigProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4B55CC),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 17),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Patient Report',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      body: PdfPreview(
        build: (_) =>
            PdfExportService.buildPdf(config, patientData: widget.patientData),
        allowSharing: false,
        allowPrinting: false,
        canChangePageFormat: false,
        canChangeOrientation: false,
        initialPageFormat: PdfPageFormat.a4,
      ),
    );
  }
}

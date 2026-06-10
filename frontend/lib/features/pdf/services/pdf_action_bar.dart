import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import 'pdf_service.dart';

/// Drop-in action bar: Print | Share PDF | WhatsApp
class PdfActionBar extends StatefulWidget {
  final Future<Uint8List> Function() buildPdf;
  final String filename;

  const PdfActionBar({
    super.key,
    required this.buildPdf,
    required this.filename,
  });

  @override
  State<PdfActionBar> createState() => _PdfActionBarState();
}

class _PdfActionBarState extends State<PdfActionBar> {
  bool _loading = false;

  Future<void> _run(Future<void> Function(Uint8List) action) async {
    setState(() => _loading = true);
    try {
      final bytes = await widget.buildPdf();
      await action(bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('PDF error: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(
            child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Row(
      children: [
        _Btn(
          icon: Icons.print_outlined,
          label: 'Print',
          color: AppColors.primary,
          onTap: () => _run((b) => PdfService.printPdf(b)),
        ),
        const SizedBox(width: 8),
        _Btn(
          icon: Icons.share_outlined,
          label: 'Share PDF',
          color: Colors.teal,
          onTap: () =>
              _run((b) => PdfService.sharePdf(b, widget.filename)),
        ),
        const SizedBox(width: 8),
        _Btn(
          icon: Icons.chat_outlined,
          label: 'WhatsApp',
          color: const Color(0xFF25D366),
          onTap: () =>
              _run((b) => PdfService.sharePdf(b, widget.filename)),
        ),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Btn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 16, color: color),
          label: Text(label,
              style:
                  TextStyle(fontSize: 12, color: color)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color.withOpacity(0.5)),
            padding:
                const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
}

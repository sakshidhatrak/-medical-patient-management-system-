import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../providers/print_config_provider.dart';
import '../widgets/preview_right_panel.dart';

class PrintConfigScreen extends ConsumerWidget {
  const PrintConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(effectivePatientDataProvider);
    return FieldConfigPage(patientData: data);
  }
}

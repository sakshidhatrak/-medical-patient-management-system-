// SQLite local datasource — mobile offline only.
// On web, all data flows through PatientSupabaseDataSource directly.
import 'package:flutter/foundation.dart';

abstract interface class PatientLocalDataSource {
  // Minimal interface kept for compile compatibility.
}

class PatientLocalDataSourceImpl implements PatientLocalDataSource {
  const PatientLocalDataSourceImpl();
}

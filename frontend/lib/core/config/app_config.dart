class AppConfig {
  static const String appName = 'MediManage';

  // Database
  static const String dbName = 'medimanage.db';
  static const int dbVersion = 3;

  // Pagination
  static const int pageSize = 20;

  // Secure storage keys
  static const String tokenKey = 'auth_access_token';
  static const String refreshTokenKey = 'auth_refresh_token';
  static const String userKey = 'current_user';

  // API endpoints
  static const String loginEndpoint = '/auth/login';
  static const String refreshEndpoint = '/auth/refresh';
  static const String logoutEndpoint = '/auth/logout';
  static const String patientsEndpoint = '/patients';
  static const String appointmentsEndpoint = '/appointments';
  static const String medicalRecordsEndpoint = '/medical-records';
}

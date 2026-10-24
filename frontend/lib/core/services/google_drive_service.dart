// Google Drive upload service.
//
// SETUP REQUIRED (one-time, before this works):
// 1. Go to https://console.cloud.google.com
// 2. Create / select a project and enable "Google Drive API"
// 3. Go to APIs & Services → Credentials → Create Credentials → OAuth 2.0 Client IDs
//    a. Create an "Android" client ID — enter your app's package name
//       (com.example.medical_patient_management) and the SHA-1 of your signing key.
//       Run: keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
//    b. Create a "Web application" client ID (needed as serverClientId below).
// 4. Paste the Web Client ID into the serverClientId field below.
// 5. (Optional) Set _kFixedEmail to your Gmail address so the account picker
//    always defaults to that account and never asks again after the first sign-in.
//
// No google-services.json is required for this approach.

import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

// Gmail address — app hamesha isi account ka Drive use karega.
const String _kFixedEmail = 'sangle.personal@gmail.com';

class GoogleDriveService {
  GoogleDriveService._();

  static final _signIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  /// Uploads [bytes] as a PDF named [fileName] to the configured Google Drive.
  ///
  /// Flow:
  ///   1. Reuse the in-memory signed-in account (same app session).
  ///   2. Try silent sign-in (previously authorised account — no prompt).
  ///   3. Fall back to interactive picker (first-time only).
  ///
  /// Returns the Drive file ID on success, null if the user cancelled.
  static Future<String?> uploadPdf(Uint8List bytes, String fileName) async {
    GoogleSignInAccount? account = _signIn.currentUser;

    // Silent sign-in reuses the previously authorised account without any UI.
    account ??= await _signIn.signInSilently();

    // If a fixed email is configured and a different account is signed in,
    // sign out and re-authenticate with the correct account.
    if (account != null &&
        account.email.toLowerCase() != _kFixedEmail.toLowerCase()) {
      await _signIn.signOut();
      account = null;
    }

    // Interactive sign-in only shown the very first time (or after sign-out).
    account ??= await _signIn.signIn();
    if (account == null) return null; // user dismissed the picker

    final auth = await account.authentication;
    final token = auth.accessToken;
    if (token == null) throw Exception('Could not get Google access token.');

    final client = _AuthClient({'Authorization': 'Bearer $token'});
    try {
      final api = drive.DriveApi(client);
      final meta = drive.File()
        ..name = fileName
        ..mimeType = 'application/pdf';
      final media = drive.Media(
        Stream.value(bytes),
        bytes.length,
        contentType: 'application/pdf',
      );
      final result = await api.files.create(meta, uploadMedia: media);
      return result.id;
    } finally {
      client.close();
    }
  }

  /// Upload without any sign-in UI.
  /// Used when PRINT is tapped — Drive upload is a silent bonus.
  /// Returns null silently if not signed in (never throws).
  static Future<String?> uploadSilently(Uint8List bytes, String fileName) async {
    try {
      // Only use already-authorised account — no interactive sign-in.
      GoogleSignInAccount? account = _signIn.currentUser;
      account ??= await _signIn.signInSilently();
      if (account == null) return null;

      if (_kFixedEmail.isNotEmpty &&
          account.email.toLowerCase() != _kFixedEmail.toLowerCase()) {
        return null; // wrong account — skip silently
      }

      final auth  = await account.authentication;
      final token = auth.accessToken;
      if (token == null) return null;

      final client = _AuthClient({'Authorization': 'Bearer $token'});
      try {
        final api   = drive.DriveApi(client);
        final meta  = drive.File()
          ..name     = fileName
          ..mimeType = 'application/pdf';
        final media = drive.Media(
          Stream.value(bytes),
          bytes.length,
          contentType: 'application/pdf',
        );
        final result = await api.files.create(meta, uploadMedia: media);
        return result.id;
      } finally {
        client.close();
      }
    } catch (_) {
      return null; // never surface errors — print must not be blocked
    }
  }

  static Future<void> signOut() => _signIn.signOut();
}

class _AuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final _inner = http.Client();

  _AuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../models/delivery.dart';

class DriveSyncService {
  static const _backupFileName = 'RentManBackup.zip';
  static const _lastSyncPrefKey = 'last_drive_sync';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<GoogleSignInAccount?> signInSilently() => _googleSignIn.signInSilently();

  Future<GoogleSignInAccount?> signIn() => _googleSignIn.signIn();

  Future<void> signOut() => _googleSignIn.signOut();

  Future<DateTime?> getLastLocalSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_lastSyncPrefKey);
    return iso != null ? DateTime.tryParse(iso) : null;
  }

  Future<void> _saveLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncPrefKey, DateTime.now().toIso8601String());
  }

  Future<drive.DriveApi> _driveApi() async {
    final account = _googleSignIn.currentUser ?? await _googleSignIn.signIn();
    if (account == null) {
      throw Exception('Google sign-in is required to sync with Drive');
    }
    final client = await _googleSignIn.authenticatedClient();
    if (client == null) {
      throw Exception('Could not authenticate with Google Drive');
    }
    return drive.DriveApi(client);
  }

  Future<String?> _findBackupFileId(drive.DriveApi api) async {
    final result = await api.files.list(
      q: "name = '$_backupFileName' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id, modifiedTime)',
    );
    if (result.files == null || result.files!.isEmpty) return null;
    return result.files!.first.id;
  }

  // Returns when the backup currently stored on Drive was last modified, or null if none exists.
  Future<DateTime?> getRemoteBackupTime() async {
    final api = await _driveApi();
    final result = await api.files.list(
      q: "name = '$_backupFileName' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id, modifiedTime)',
    );
    if (result.files == null || result.files!.isEmpty) return null;
    return result.files!.first.modifiedTime;
  }

  // Packs all booking/customer/delivery data plus packing photos into a zip and uploads it to Drive.
  Future<void> backup() async {
    final dbHelper = DatabaseHelper();
    final data = await dbHelper.getAllDataForSync();
    final deliveries = await dbHelper.getAllDeliveries();

    final archive = Archive();
    final jsonBytes = utf8.encode(jsonEncode(data));
    archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));

    for (final Delivery delivery in deliveries) {
      for (final path in delivery.packingPhotos) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final fileName = path.split(Platform.pathSeparator).last;
          archive.addFile(ArchiveFile('photos/$fileName', bytes.length, bytes));
        }
      }
    }

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw Exception('Failed to build the backup archive');
    }

    final api = await _driveApi();
    final existingId = await _findBackupFileId(api);
    final media = drive.Media(Stream.value(zipBytes), zipBytes.length);

    if (existingId != null) {
      await api.files.update(drive.File(), existingId, uploadMedia: media);
    } else {
      final metadata = drive.File()..name = _backupFileName;
      await api.files.create(metadata, uploadMedia: media);
    }

    await _saveLastSyncTime();
  }

  // Downloads the Drive backup and overwrites local data + packing photos with its contents.
  Future<void> restore() async {
    final api = await _driveApi();
    final fileId = await _findBackupFileId(api);
    if (fileId == null) {
      throw Exception('No backup was found on Google Drive yet');
    }

    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }

    final archive = ZipDecoder().decodeBytes(bytes);
    final jsonFile = archive.findFile('data.json');
    if (jsonFile == null) {
      throw Exception('The backup file on Drive is corrupted');
    }

    final data = jsonDecode(utf8.decode(jsonFile.content as List<int>)) as Map<String, dynamic>;

    final dir = await getApplicationDocumentsDirectory();
    for (final file in archive.files) {
      if (file.isFile && file.name.startsWith('photos/')) {
        final fileName = file.name.substring('photos/'.length);
        await File('${dir.path}/$fileName').writeAsBytes(file.content as List<int>);
      }
    }

    await DatabaseHelper().restoreFromBackup(data);
    await _saveLastSyncTime();
  }
}

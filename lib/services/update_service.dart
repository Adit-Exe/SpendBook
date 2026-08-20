import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  final int versionCode;
  final String versionName;
  final String url;
  final bool isForceUpdate;

  UpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.url,
    required this.isForceUpdate,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      versionCode: json['versionCode'] as int,
      versionName: json['versionName'] as String,
      url: json['url'] as String,
      isForceUpdate: json['isForceUpdate'] as bool? ?? false,
    );
  }
}

class UpdateService {
  static const String _updateUrl =
      'https://adit-exe.github.io/Portfolio/spendbook/spendbook.json';

  static const MethodChannel _installerChannel =
      MethodChannel('com.example.spend_book/installer');

  /// Checks the remote JSON for a newer version.
  /// Returns [UpdateInfo] if an update is available, null otherwise.
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http
          .get(Uri.parse(_updateUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final Map<String, dynamic> json = jsonDecode(response.body);
      final updateInfo = UpdateInfo.fromJson(json);

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      if (updateInfo.versionCode > currentVersionCode) {
        return updateInfo;
      }
      return null;
    } catch (e) {
      // Silently fail — don't block app usage if update check fails
      return null;
    }
  }

  /// Downloads the APK from [url], reporting progress via [onProgress].
  /// [onProgress] receives (bytesReceived, totalBytes).
  /// Returns the local file path of the downloaded APK.
  static Future<String> downloadApk(
    String url,
    void Function(int received, int total) onProgress,
  ) async {
    // Clean up any previously downloaded APKs first
    await _cleanOldApks();

    final dir = await getExternalStorageDirectory();
    if (dir == null) {
      throw Exception('Cannot access external storage directory');
    }

    final filePath = '${dir.path}/SpendBook_update.apk';
    final file = File(filePath);

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final streamedResponse = await client.send(request);

      final totalBytes = streamedResponse.contentLength ?? -1;
      int receivedBytes = 0;

      final sink = file.openWrite();
      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        onProgress(receivedBytes, totalBytes);
      }
      await sink.close();
    } finally {
      client.close();
    }

    return filePath;
  }

  /// Triggers the Android system package installer via platform channel.
  static Future<void> installApk(String filePath) async {
    await _installerChannel.invokeMethod('installApk', {
      'filePath': filePath,
    });
  }

  /// Deletes any previously downloaded APK files from the download directory.
  static Future<void> _cleanOldApks() async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return;

      final files = dir.listSync();
      for (final file in files) {
        if (file is File && file.path.endsWith('.apk')) {
          await file.delete();
        }
      }
    } catch (_) {
      // Ignore cleanup errors
    }
  }
}

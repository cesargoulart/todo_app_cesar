import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AutoUpdateService {
  static final AutoUpdateService _instance = AutoUpdateService._internal();
  factory AutoUpdateService() => _instance;
  AutoUpdateService._internal();

  final Dio _dio = Dio();
  
  // Google Drive configuration
  static const String _versionFileUrl = 'https://drive.google.com/uc?export=download&id=YOUR_VERSION_FILE_ID';
  static const String _apkBaseUrl = 'https://drive.google.com/uc?export=download&id=';
  
  // Update configuration
  static const String _versionPrefsKey = 'last_update_check';
  static const Duration _checkInterval = Duration(hours: 6); // Check every 6 hours

  Future<void> initialize() async {
    print('🔄 AutoUpdateService initialized');
    // Check for updates on app start (with rate limiting)
    await _checkForUpdatesWithRateLimit();
  }

  Future<void> _checkForUpdatesWithRateLimit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_versionPrefsKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Only check if enough time has passed
      if (now - lastCheck > _checkInterval.inMilliseconds) {
        await checkForUpdates(showNoUpdateDialog: false);
        await prefs.setInt(_versionPrefsKey, now);
      }
    } catch (e) {
      print('❌ Error in rate-limited update check: $e');
    }
  }

  Future<void> checkForUpdates({bool showNoUpdateDialog = true}) async {
    try {
      print('🔍 Checking for app updates...');
      
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      print('📱 Current app version: $currentVersion');

      // Get latest version from Google Drive
      final latestVersionInfo = await _getLatestVersionInfo();
      if (latestVersionInfo == null) {
        print('❌ Could not fetch version information');
        return;
      }

      final latestVersion = latestVersionInfo['version'] as String;
      final apkFileId = latestVersionInfo['apk_file_id'] as String;
      final changelog = latestVersionInfo['changelog'] as String?;

      print('☁️ Latest version available: $latestVersion');

      // Compare versions
      if (_isNewerVersion(currentVersion, latestVersion)) {
        print('🆕 New version available: $latestVersion');
        await _showUpdateDialog(currentVersion, latestVersion, apkFileId, changelog);
      } else {
        print('✅ App is up to date');
        if (showNoUpdateDialog) {
          await _showNoUpdateDialog();
        }
      }
    } catch (e) {
      print('❌ Error checking for updates: $e');
    }
  }

  Future<Map<String, dynamic>?> _getLatestVersionInfo() async {
    try {
      final response = await _dio.get(_versionFileUrl);
      final versionData = response.data as String;
      
      // Parse version file (JSON format)
      // Expected format: {"version": "1.0.1", "apk_file_id": "GOOGLE_DRIVE_APK_FILE_ID", "changelog": "Bug fixes"}
      final lines = versionData.trim().split('\n');
      final versionLine = lines.firstWhere((line) => line.contains('version'), orElse: () => '');
      final apkIdLine = lines.firstWhere((line) => line.contains('apk_file_id'), orElse: () => '');
      final changelogLine = lines.firstWhere((line) => line.contains('changelog'), orElse: () => '');

      if (versionLine.isEmpty || apkIdLine.isEmpty) {
        return null;
      }

      // Simple parsing (you can use json.decode for proper JSON)
      final version = versionLine.split(':')[1].trim().replaceAll('"', '').replaceAll(',', '');
      final apkFileId = apkIdLine.split(':')[1].trim().replaceAll('"', '').replaceAll(',', '');
      final changelog = changelogLine.isNotEmpty 
          ? changelogLine.split(':')[1].trim().replaceAll('"', '') 
          : 'No changelog available';

      return {
        'version': version,
        'apk_file_id': apkFileId,
        'changelog': changelog,
      };
    } catch (e) {
      print('❌ Error fetching version info: $e');
      return null;
    }
  }

  bool _isNewerVersion(String currentVersion, String latestVersion) {
    final current = currentVersion.split('.').map(int.parse).toList();
    final latest = latestVersion.split('.').map(int.parse).toList();

    for (int i = 0; i < current.length && i < latest.length; i++) {
      if (latest[i] > current[i]) return true;
      if (latest[i] < current[i]) return false;
    }
    return latest.length > current.length;
  }

  Future<void> _showUpdateDialog(String currentVersion, String latestVersion, String apkFileId, String? changelog) async {
    final context = _getContext();
    if (context == null) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.system_update, color: Colors.blue),
              SizedBox(width: 8),
              Text('Update Available'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Version: $currentVersion'),
              Text('Latest Version: $latestVersion', 
                   style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (changelog != null) ...[
                const Text('What\'s New:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(changelog),
                const SizedBox(height: 16),
              ],
              const Text('Would you like to download and install the update?'),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Later'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Update Now'),
              onPressed: () {
                Navigator.of(context).pop();
                _downloadAndInstallUpdate(apkFileId, latestVersion);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showNoUpdateDialog() async {
    final context = _getContext();
    if (context == null) return;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('App Up to Date'),
            ],
          ),
          content: const Text('You are using the latest version of the app!'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadAndInstallUpdate(String apkFileId, String version) async {
    try {
      // Request permissions
      final hasPermission = await _requestPermissions();
      if (!hasPermission) {
        print('❌ Storage permissions not granted');
        return;
      }

      // Show download progress dialog
      await _showDownloadDialog(apkFileId, version);
    } catch (e) {
      print('❌ Error downloading update: $e');
    }
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      final installStatus = await Permission.requestInstallPackages.request();
      return status.isGranted && installStatus.isGranted;
    }
    return true;
  }

  Future<void> _showDownloadDialog(String apkFileId, String version) async {
    final context = _getContext();
    if (context == null) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Downloading Update'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Downloading version $version...'),
                  const SizedBox(height: 8),
                  const Text('Please wait while the update is downloaded.'),
                ],
              ),
            );
          },
        );
      },
    );

    // Start download in background
    _performDownload(apkFileId, version);
  }

  Future<void> _performDownload(String apkFileId, String version) async {
    try {
      final context = _getContext();
      if (context == null) return;

      // Get downloads directory
      final directory = await getExternalStorageDirectory();
      final downloadPath = '${directory!.path}/todo_app_$version.apk';

      // Download APK
      final apkUrl = '$_apkBaseUrl$apkFileId';
      await _dio.download(
        apkUrl,
        downloadPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(1);
            print('📥 Download progress: $progress%');
          }
        },
      );

      // Close download dialog
      Navigator.of(context).pop();

      // Show install dialog
      await _showInstallDialog(downloadPath);
    } catch (e) {
      print('❌ Download failed: $e');
      final context = _getContext();
      if (context != null) {
        Navigator.of(context).pop();
        _showErrorDialog('Download failed. Please try again.');
      }
    }
  }

  Future<void> _showInstallDialog(String apkPath) async {
    final context = _getContext();
    if (context == null) return;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Install Update'),
          content: const Text('Update downloaded successfully! Tap "Install" to install the new version.'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Install'),
              onPressed: () {
                Navigator.of(context).pop();
                _installApk(apkPath);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _installApk(String apkPath) async {
    try {
      final result = await OpenFile.open(apkPath);
      if (result.type == ResultType.done) {
        print('✅ APK installation initiated');
      } else {
        print('❌ Failed to open APK: ${result.message}');
      }
    } catch (e) {
      print('❌ Error installing APK: $e');
    }
  }

  Future<void> _showErrorDialog(String message) async {
    final context = _getContext();
    if (context == null) return;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  BuildContext? _getContext() {
    // This is a simplified way to get context. In a real app, you'd pass context properly.
    // For now, we'll assume the current context is available.
    return null; // You'll need to implement proper context management
  }

  // Manual update check method for UI button
  Future<void> manualUpdateCheck() async {
    print('🔍 Manual update check initiated');
    await checkForUpdates(showNoUpdateDialog: true);
  }
}
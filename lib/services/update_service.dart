import 'dart:io';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../models/app_version.dart';
import '../utils/constants.dart';
import 'package:logger/logger.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  final _logger = Logger();
  final Dio _dio = Dio();
  
  // Download progress callback
  void Function(double progress)? onDownloadProgress;
  
  Future<AppVersion?> checkForUpdate() async {
    try {
      // Get current app version
      PackageInfo packageInfo;
      try {
        packageInfo = await PackageInfo.fromPlatform();
      } catch (e) {
        _logger.w('PackageInfo not available (likely in development): $e');
        // In development, use default version 1
        packageInfo = PackageInfo(
          appName: 'Al-Tijwal',
          packageName: 'com.altijwal.app',
          version: '1.0.0',
          buildNumber: '1',
        );
      }
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 1;
      
      // Determine platform
      final platform = Platform.isAndroid ? 'android' : 'ios';
      
      // Query Supabase for latest version
      final response = await supabase
          .from('app_versions')
          .select()
          .eq('platform', platform)
          .eq('is_active', true)
          .order('version_code', ascending: false)
          .limit(1)
          .single();
      
      final appVersion = AppVersion.fromJson(response);
      
      // Check if update is required
      if (appVersion.isUpdateRequired(currentVersionCode) || 
          appVersion.isUpdateAvailable(currentVersionCode)) {
        return appVersion;
      }
      
      return null;
    } catch (e) {
      _logger.e('Error checking for update: $e');
      return null;
    }
  }
  
  Future<String?> downloadUpdate(AppVersion appVersion) async {
    if (!Platform.isAndroid) {
      // For iOS, open App Store instead
      final appStoreUrl = 'https://apps.apple.com/app/id-YOUR-APP-ID'; // Replace with actual App Store URL
      if (await canLaunchUrl(Uri.parse(appStoreUrl))) {
        await launchUrl(Uri.parse(appStoreUrl), mode: LaunchMode.externalApplication);
      }
      return null;
    }
    
    try {
      // Use external files directory for easier FileProvider access
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw Exception('External storage not available');
      }
      _logger.i('External storage directory: ${externalDir.path}');
      final updateDir = Directory('${externalDir.path}/updates');
      
      // Create updates directory if it doesn't exist
      if (!await updateDir.exists()) {
        await updateDir.create(recursive: true);
      }
      
      // Clean up old APK files
      await _cleanupOldApks(updateDir);
      
      // Check if APK already exists
      final apkPath = '${updateDir.path}/al-tijwal-v${appVersion.versionName}.apk';
      final apkFile = File(apkPath);
      
      if (await apkFile.exists()) {
        _logger.i('APK already downloaded: $apkPath');
        return apkPath;
      }
      
      // Download APK
      _logger.i('Downloading APK from: ${appVersion.downloadUrl}');
      
      await _dio.download(
        appVersion.downloadUrl,
        apkPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onDownloadProgress?.call(progress);
          }
        },
        options: Options(
          headers: {
            'Accept': '*/*',
          },
        ),
      );
      
      _logger.i('APK downloaded successfully: $apkPath');
      
      // Also copy to external storage for easier access
      try {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          final externalPath = '${externalDir.path}/al-tijwal-update.apk';
          final apkFile = File(apkPath);
          await apkFile.copy(externalPath);
          _logger.i('APK also copied to: $externalPath');
        }
      } catch (e) {
        _logger.w('Failed to copy APK to external storage: $e');
      }
      
      return apkPath;
    } catch (e) {
      _logger.e('Error downloading update: $e');
      return null;
    }
  }
  
  Future<bool> installUpdate(String apkPath) async {
    if (!Platform.isAndroid) return false;
    
    _logger.i('Starting APK installation process for: $apkPath');
    
    // First try: Android platform channel (most reliable)
    try {
      _logger.i('Attempting APK installation via platform channel');
      const platform = MethodChannel('com.altijwal.app/installer');
      _logger.i('Platform channel created, invoking installApk method');
      final result = await platform.invokeMethod('installApk', {'path': apkPath});
      _logger.i('Platform channel result: $result');
      _logger.i('Platform channel installation successful');
      return true;
    } catch (e) {
      _logger.w('Platform channel failed: $e');
      _logger.w('Platform channel error type: ${e.runtimeType}');
    }
    
    // Second try: open_file plugin
    try {
      _logger.i('Attempting APK installation via open_file plugin');
      final result = await OpenFile.open(apkPath);
      if (result.type == ResultType.done) {
        _logger.i('open_file installation successful');
        return true;
      }
    } catch (e) {
      _logger.w('open_file plugin failed: $e');
    }
    
    // All methods failed - inform user to install manually
    _logger.e('All automatic installation methods failed');
    return false;
  }
  
  Future<void> _cleanupOldApks(Directory updateDir) async {
    try {
      final files = updateDir.listSync();
      for (final file in files) {
        if (file is File && file.path.endsWith('.apk')) {
          // Delete APK files older than 7 days
          final stat = await file.stat();
          final age = DateTime.now().difference(stat.modified);
          if (age.inDays > 7) {
            await file.delete();
            _logger.i('Deleted old APK: ${file.path}');
          }
        }
      }
    } catch (e) {
      _logger.e('Error cleaning up old APKs: $e');
    }
  }
  
  Future<void> cleanupAllApks() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final updateDir = Directory('${appDocDir.path}/updates');
      
      if (await updateDir.exists()) {
        await updateDir.delete(recursive: true);
        _logger.i('Cleaned up all APKs');
      }
    } catch (e) {
      _logger.e('Error cleaning up all APKs: $e');
    }
  }
}
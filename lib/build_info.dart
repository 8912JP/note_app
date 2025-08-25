// Automatisch generierte Build-Informationen
// Nutzt package_info_plus um Version aus pubspec.yaml zu lesen

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class BuildInfo {
  static String? _version;
  static String? _buildNumber;
  static String? _appName;
  static String? _packageName;
  
  // Lade Build-Informationen asynchron
  static Future<void> initialize() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _version = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
      //_appName = packageInfo.appName;
      _packageName = packageInfo.packageName;
    } catch (e) {
      print("❌ Fehler beim Laden der Build-Info: $e");
      // Fallback-Werte
      _version = '1.0.0';
      _buildNumber = '2';
      _appName = 'iQM App';
      _packageName = 'iqm_app';
    }
  }
  
  // Getter für Build-Informationen
  static String get version => _version ?? '1.0.0';
  static String get buildNumber => _buildNumber ?? '2';
  static String get appName => _appName ?? 'iQM App';
  static String get packageName => _packageName ?? 'note_app';
  static String get fullVersion => '$version+$buildNumber';
  static String get buildDate => DateTime.now().toString().split('.')[0];
  
  // Plattform-Info
  static String get platform {
    if (kIsWeb) {
      return 'Web';
    } else {
      return 'Native';
    }
  }
  
    // Build-Zeitstempel
  static String get buildTimestamp {
    const buildTime = String.fromEnvironment('BUILD_TIME', defaultValue: '');
    if (buildTime.isNotEmpty) {
      return buildTime;
    }
    return '0000-00-00 00:00'; // Fallback-Wert
  }
}
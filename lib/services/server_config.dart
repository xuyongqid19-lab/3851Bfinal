import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runtime-configurable backend host, so the mobile app can point at any PC
/// that runs the Docker stack (Settings on the login page). One host drives
/// all four services on their fixed ports:
/// community 3000, auth 3002, family 3003, chat 3004.
class ServerConfig {
  ServerConfig._();

  static const String _prefKey = 'server_base_host';
  static String? _cachedHost;

  static const Map<String, int> _servicePorts = {
    'community': 3000,
    'auth': 3002,
    'family': 3003,
    'chat': 3004,
  };

  static String? normalize(String? raw) {
    if (raw == null) return null;
    var value = raw.trim();
    if (value.isEmpty) return null;
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  /// Warms the in-memory cache at app start so the sync getters below work.
  static Future<void> load() async {
    if (_cachedHost != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedHost = normalize(prefs.getString(_prefKey));
    } catch (_) {}
  }

  /// Current host as entered by the user (e.g. http://192.168.1.50), or null.
  static String? get host => _cachedHost;

  /// True when the user has picked a server in settings.
  static bool get isConfigured => _cachedHost != null;

  static Future<void> setHost(String raw) async {
    final value = normalize(raw);
    _cachedHost = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove(_prefKey);
      } else {
        await prefs.setString(_prefKey, value);
      }
    } catch (_) {}
  }

  static Future<void> clear() async {
    _cachedHost = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
    } catch (_) {}
  }

  /// Base URL for [service] ('auth' | 'community' | 'family' | 'chat'),
  /// or null when no host has been configured.
  static String? baseUrlFor(String service) {
    final hostValue = _cachedHost;
    if (hostValue == null) return null;
    final port = _servicePorts[service];
    if (port == null) return null;
    return '$hostValue:$port';
  }

  /// Default base URL used when nothing is configured: localhost on web,
  /// the Android emulator loopback on Android, localhost elsewhere.
  static String defaultNativeBase(String service) {
    final port = _servicePorts[service] ?? 3000;
    if (kIsWeb) return 'http://localhost:$port';
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:$port';
    }
    return 'http://localhost:$port';
  }
}

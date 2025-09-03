import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppSettings {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _settingsKey = 'app_settings';
  
  // Default values
  static const int _defaultDuration = 5;
  static const int _defaultImageCacheSize = 10;
  
  static int _duration = _defaultDuration;
  static int _imageCacheSize = _defaultImageCacheSize;
  
  // Getters
  static int get duration => _duration;
  static int get imageCacheSize => _imageCacheSize;
  
  // Initialize settings from storage
  static Future<void> initialize() async {
    await _loadSettings();
  }
  
  // Load settings from secure storage
  static Future<void> _loadSettings() async {
    try {
      final settingsString = await _secureStorage.read(key: _settingsKey);
      if (settingsString != null) {
        final Map<String, dynamic> settings = jsonDecode(settingsString);
        _duration = settings['duration'] ?? _defaultDuration;
        _imageCacheSize = settings['imageCacheSize'] ?? _defaultImageCacheSize;
      }
    } catch (e) {
      // If there's an error loading, use defaults
      _duration = _defaultDuration;
      _imageCacheSize = _defaultImageCacheSize;
    }
  }
  
  // Save settings to secure storage
  static Future<void> _saveSettings() async {
    final Map<String, dynamic> settings = {
      'duration': _duration,
      'imageCacheSize': _imageCacheSize,
    };
    await _secureStorage.write(
      key: _settingsKey,
      value: jsonEncode(settings),
    );
  }
  
  // Update duration
  static Future<void> setDuration(int duration) async {
    if (duration > 0) {
      _duration = duration;
      await _saveSettings();
    }
  }
  
  // Update image cache size
  static Future<void> setImageCacheSize(int cacheSize) async {
    if (cacheSize > 0) {
      _imageCacheSize = cacheSize;
      await _saveSettings();
    }
  }
  
  // Update both settings at once
  static Future<void> updateSettings({
    required int duration,
    required int imageCacheSize,
  }) async {
    if (duration > 0 && imageCacheSize > 0) {
      _duration = duration;
      _imageCacheSize = imageCacheSize;
      await _saveSettings();
    }
  }
  
  // Reset to defaults
  static Future<void> resetToDefaults() async {
    _duration = _defaultDuration;
    _imageCacheSize = _defaultImageCacheSize;
    await _saveSettings();
  }
}
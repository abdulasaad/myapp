// lib/services/language_service.dart

import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

class LanguageService {
  static const String _languageKey = 'app_language';
  static final Logger _logger = Logger();
  
  static LanguageService? _instance;
  static LanguageService get instance {
    _instance ??= LanguageService._();
    return _instance!;
  }
  
  LanguageService._();
  
  SharedPreferences? _prefs;
  
  // Supported locales
  static const List<Locale> supportedLocales = [
    Locale('en'), // English
    Locale('ar'), // Arabic
  ];
  
  // Initialize the service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _logger.i('Language service initialized');
    } catch (e) {
      _logger.e('Failed to initialize language service: $e');
    }
  }
  
  // Get current language code
  String getCurrentLanguageCode() {
    if (_prefs == null) return 'en'; // Default to English
    return _prefs!.getString(_languageKey) ?? 'en';
  }
  
  // Get current locale
  Locale getCurrentLocale() {
    final languageCode = getCurrentLanguageCode();
    return Locale(languageCode);
  }
  
  // Set language
  Future<bool> setLanguage(String languageCode) async {
    try {
      if (_prefs == null) {
        _logger.w('SharedPreferences not initialized');
        return false;
      }
      
      // Validate language code
      if (!isLanguageSupported(languageCode)) {
        _logger.w('Unsupported language code: $languageCode');
        return false;
      }
      
      await _prefs!.setString(_languageKey, languageCode);
      _logger.i('Language set to: $languageCode');
      return true;
    } catch (e) {
      _logger.e('Failed to set language: $e');
      return false;
    }
  }
  
  // Check if language is supported
  bool isLanguageSupported(String languageCode) {
    return supportedLocales.any((locale) => locale.languageCode == languageCode);
  }
  
  // Get language name for display
  String getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'ar':
        return 'العربية';
      default:
        return languageCode;
    }
  }
  
  // Get system language if supported, otherwise return default
  String getSystemLanguageOrDefault() {
    final systemLocale = PlatformDispatcher.instance.locale;
    final systemLanguageCode = systemLocale.languageCode;
    
    if (isLanguageSupported(systemLanguageCode)) {
      return systemLanguageCode;
    }
    
    return 'en'; // Default to English
  }
  
  // Reset to system language or default
  Future<bool> resetToSystemLanguage() async {
    final systemLanguage = getSystemLanguageOrDefault();
    return await setLanguage(systemLanguage);
  }
  
  // Clear language preference (will use system default)
  Future<bool> clearLanguagePreference() async {
    try {
      if (_prefs == null) return false;
      await _prefs!.remove(_languageKey);
      _logger.i('Language preference cleared');
      return true;
    } catch (e) {
      _logger.e('Failed to clear language preference: $e');
      return false;
    }
  }
}
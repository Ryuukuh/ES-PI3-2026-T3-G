// PROJETO INTEGRADOR 3 - MESCLAINVEST
// Autor Principal: Rafael Elias Correa | RA: 18726497
// Componente: SessionService — gerenciamento de sessão local via shared_preferences

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _userKey = 'mesclainvest_user';

  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final data = jsonDecode(raw);
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
    } catch (_) {
      // ignore invalid saved data
    }
    return null;
  }

  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }
}

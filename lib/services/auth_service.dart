import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  static const _keyToken = 'auth_token';
  static const _keyNama = 'auth_nama';
  static const _keyRole = 'auth_role';

  // Login, simpan token & data user ke device
  static Future<void> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('${ApiService.baseUrl}/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      final pesan = body['message'] ?? 'Email atau password salah.';
      throw Exception(pesan);
    }

    final body = jsonDecode(res.body);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, body['token']);
    await prefs.setString(_keyNama, body['user']['name']);
    await prefs.setString(_keyRole, body['user']['role']);
  }

  static Future<void> logout() async {
    final token = await getToken();
    if (token != null) {
      try {
        await http.post(
          Uri.parse('${ApiService.baseUrl}/logout'),
          headers: {'Authorization': 'Bearer $token'},
        );
      } catch (_) {
        // abaikan error koneksi, tetap hapus sesi lokal
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyNama);
    await prefs.remove(_keyRole);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<String?> getNama() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyNama);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRole);
  }

  static Future<bool> isAdmin() async {
    final role = await getRole();
    return role == 'admin';
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Konfigurasi backend.
/// Saat running di Linux desktop/emulator, backend lokal di host ini.
/// Saat running di Android emulator, gunakan 10.0.2.2 (alias host loopback).
/// Saat running di Android device fisik, ganti dengan IP LAN host (mis. 192.168.x.x).
class ApiConfig {
  static const String _envBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://43.156.113.106',
  );

  /// Base URL backend. Bisa di-override via `--dart-define=API_BASE_URL=...`.
  static String get baseUrl => _envBaseUrl;

  /// SharedPreferences key untuk simpan JWT.
  static const String tokenKey = 'auth_token';
  static const String userKey = 'auth_user';
}

/// HTTP client sederhana yang otomatis melampirkan header `Authorization: Bearer <jwt>`
/// dari token yang disimpan di SharedPreferences.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? _cachedToken;

  /// Ambil token JWT dari memory cache atau SharedPreferences.
  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(ApiConfig.tokenKey);
    return _cachedToken;
  }

  /// Simpan token JWT (setelah login sukses).
  Future<void> saveToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiConfig.tokenKey, token);
  }

  /// Simpan data user (JSON string) untuk ditampilkan di UI.
  Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiConfig.userKey, jsonEncode(user));
  }

  /// Ambil data user tersimpan (atau null jika belum login).
  Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(ApiConfig.userKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Hapus token & user (logout).
  Future<void> clearAuth() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConfig.tokenKey);
    await prefs.remove(ApiConfig.userKey);
  }

  /// Apakah user sudah login (token tersimpan)?
  Future<bool> isLoggedIn() async => (await getToken()) != null;

  Map<String, String> _headers({Map<String, String>? extra, String? token}) {
    final h = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?extra,
    };
    return h;
  }

  /// Kirim request dengan retry untuk error transient (DNS/jaringan/TLS).
  /// Retry untuk error transient (DNS/jaringan/TLS bisa sesekali blip).
  Future<http.Response> _sendWithRetry(
    Future<http.Response> Function() send,
  ) async {
    const maxAttempts = 3;
    const delays = [
      Duration(milliseconds: 900),
      Duration(milliseconds: 1800),
    ];
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await send().timeout(const Duration(seconds: 15));
      } on SocketException {
        // retry
      } on HandshakeException {
        // retry
      } on TimeoutException {
        // retry
      } on http.ClientException {
        // retry (membungkus socket/DNS error)
      }
      if (attempt < maxAttempts - 1) {
        await Future.delayed(delays[attempt]);
      }
    }
    throw ApiException(
      'Tidak dapat terhubung ke server. Periksa koneksi internet lalu coba lagi.',
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path').replace(
      queryParameters: queryParams?.map((k, v) => MapEntry(k, v.toString())),
    );
    final token = await getToken();

    final headers = _headers(extra: null, token: token);
    Future<http.Response> send() async {
      switch (method) {
        case 'GET':
          return http.get(uri, headers: headers);
        case 'POST':
          return http.post(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
        case 'PATCH':
          return http.patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
        case 'DELETE':
          return http.delete(uri, headers: headers);
        default:
          throw ApiException('Method HTTP tidak didukung: $method');
      }
    }

    final http.Response res = await _sendWithRetry(send);

    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Respons server tidak valid (status ${res.statusCode})');
    }

    if (res.statusCode >= 400 || json['success'] == false) {
      throw ApiException(json['message']?.toString() ?? 'Permintaan gagal', res.statusCode);
    }
    return json;
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? q}) =>
      _request('GET', path, queryParams: q);
  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) =>
      _request('POST', path, body: body);
  Future<Map<String, dynamic>> patch(String path, {Map<String, dynamic>? body}) =>
      _request('PATCH', path, body: body);
  Future<Map<String, dynamic>> delete(String path) => _request('DELETE', path);
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

/// Service autentikasi: login & logout via backend.
class AuthService {
  static final ApiClient _api = ApiClient.instance;

  /// Login dengan username + password. Return data user bila sukses.
  static Future<Map<String, dynamic>> login({
    required String login,
    required String password,
  }) async {
    final res = await _api.post('/api/auth/login', body: {
      'login': login,
      'password': password,
    });
    final data = res['data'] as Map<String, dynamic>;
    await _api.saveToken(data['token'] as String);
    await _api.saveUser(data['user'] as Map<String, dynamic>);
    return data['user'] as Map<String, dynamic>;
  }

  static Future<void> logout() async {
    await _api.clearAuth();
  }

  static Future<Map<String, dynamic>?> currentUser() async {
    if (!await _api.isLoggedIn()) return null;
    return _api.getUser();
  }
}

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/agent_response.dart';
import '../models/booking.dart';

/// Base URL of the FastAPI backend.
String get _kBaseUrl {
  return 'http://192.168.100.158:8000';
}

const _kTokenKey = 'ez_access_token';
const _kUserIdKey = 'ez_user_id';
const _kEmailKey = 'ez_email';
const _kDisplayNameKey = 'ez_display_name';

/// Exception thrown when the API returns an error response.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Singleton HTTP client that handles auth token management and all API calls.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  // ── Token helpers ──────────────────────────────────────────────

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kTokenKey);
  }

  Future<void> _saveSession({
    required String token,
    required String userId,
    String? email,
    String? displayName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTokenKey, token);
    await prefs.setString(_kUserIdKey, userId);
    if (email != null) await prefs.setString(_kEmailKey, email);
    if (displayName != null) {
      await prefs.setString(_kDisplayNameKey, displayName);
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTokenKey);
    await prefs.remove(_kUserIdKey);
    await prefs.remove(_kEmailKey);
    await prefs.remove(_kDisplayNameKey);
  }

  Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kEmailKey);
  }

  Future<String?> getSavedDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kDisplayNameKey);
  }

  // ── HTTP helpers ───────────────────────────────────────────────

  Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  void _checkStatus(http.Response res) {
    if (res.statusCode >= 400) {
      String msg;
      try {
        final body = json.decode(res.body);
        msg = body['detail']?.toString() ?? res.body;
      } catch (_) {
        msg = res.body;
      }
      throw ApiException(res.statusCode, msg);
    }
  }

  // ── Auth endpoints ──────────────────────────────────────────────

  /// POST /api/auth/signup  →  saves session, returns display_name
  Future<String?> signup({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final res = await http.post(
      Uri.parse('$_kBaseUrl/api/auth/signup'),
      headers: const {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'password': password,
        if (displayName != null && displayName.isNotEmpty)
          'display_name': displayName,
      }),
    );
    _checkStatus(res);
    final body = json.decode(res.body) as Map<String, dynamic>;
    await _saveSession(
      token: body['access_token'],
      userId: body['user_id'],
      email: body['email'] ?? email,
      displayName: displayName,
    );
    return displayName;
  }

  /// POST /api/auth/login  →  saves session, returns email
  Future<String> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$_kBaseUrl/api/auth/login'),
      headers: const {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 10));
    _checkStatus(res);
    final body = json.decode(res.body) as Map<String, dynamic>;
    await _saveSession(
      token: body['access_token'],
      userId: body['user_id'],
      email: body['email'] ?? email,
    );
    return email;
  }

  /// GET /api/auth/me  →  validate token, fetch display_name
  Future<Map<String, dynamic>?> me() async {
    final token = await getToken();
    if (token == null) return null;
    try {
      final res = await http.get(
        Uri.parse('$_kBaseUrl/api/auth/me'),
        headers: await _authHeaders(),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 401) {
        await clearSession();
        return null;
      }
      _checkStatus(res);
      final body = json.decode(res.body) as Map<String, dynamic>;
      // Cache display_name locally
      final dn = body['display_name'];
      if (dn != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kDisplayNameKey, dn.toString());
      }
      return body;
    } catch (_) {
      return null;
    }
  }

  // ── Service-request endpoint ────────────────────────────────────

  /// POST /api/service-requests
  /// [text]  — user's message
  /// [conversationId] — pass on follow-up clarification replies
  Future<AgentRunOut> sendServiceRequest({
    required String text,
    String? conversationId,
    int? demoOffsetSeconds,
  }) async {
    final res = await http.post(
      Uri.parse('$_kBaseUrl/api/service-requests'),
      headers: await _authHeaders(),
      body: json.encode({
        'text': text,
        if (conversationId != null) 'conversation_id': conversationId,
        if (demoOffsetSeconds != null)
          'demo_offset_seconds': demoOffsetSeconds,
      }),
    );
    _checkStatus(res);
    return AgentRunOut.fromJson(
        json.decode(res.body) as Map<String, dynamic>);
  }

  /// POST /api/service-requests/transcribe  →  {text: "..."}
  Future<String> transcribeAudio(File audioFile) async {
    final uri = Uri.parse('$_kBaseUrl/api/service-requests/transcribe');
    final token = await getToken();
    final req = http.MultipartRequest('POST', uri);
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.files.add(await http.MultipartFile.fromPath('file', audioFile.path));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    _checkStatus(res);
    final body = json.decode(res.body) as Map<String, dynamic>;
    return body['text']?.toString() ?? '';
  }

  // ── Bookings endpoint ───────────────────────────────────────────

  /// GET /api/bookings
  Future<List<BookingOut>> listBookings() async {
    final res = await http.get(
      Uri.parse('$_kBaseUrl/api/bookings'),
      headers: await _authHeaders(),
    );
    _checkStatus(res);
    final list = json.decode(res.body) as List<dynamic>;
    return list
        .map((e) => BookingOut.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/bookings/{id}
  Future<BookingOut> getBooking(String bookingId) async {
    final res = await http.get(
      Uri.parse('$_kBaseUrl/api/bookings/$bookingId'),
      headers: await _authHeaders(),
    );
    _checkStatus(res);
    return BookingOut.fromJson(
        json.decode(res.body) as Map<String, dynamic>);
  }

  /// POST /api/bookings/{id}/cancel
  Future<BookingOut> cancelBooking(String bookingId) async {
    final res = await http.post(
      Uri.parse('$_kBaseUrl/api/bookings/$bookingId/cancel'),
      headers: await _authHeaders(),
    );
    _checkStatus(res);
    return BookingOut.fromJson(
        json.decode(res.body) as Map<String, dynamic>);
  }
}

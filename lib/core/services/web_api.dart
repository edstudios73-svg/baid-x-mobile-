import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../errors/app_exception.dart';

/// Calls the BAID X website's server (phone codes, phone sign-in, checkout).
/// The server holds every secret; the app only sends what the member typed and,
/// when needed, their own session token.
class WebApi {
  WebApi({http.Client? client, String? base})
      : _client = client ?? http.Client(),
        _base = base ?? AppConfig.apiBase;

  final http.Client _client;
  final String _base;

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('$_base$path'),
            headers: {
              'content-type': 'application/json',
              if (token != null) 'authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const NetworkException('BAID X is taking too long to answer. Check your connection and try again.');
    } catch (e) {
      // the cause (offline, DNS, TLS, a browser blocking the call) only shows in the dev console
      debugPrint('website api $path failed: ${e.runtimeType}: $e');
      throw const NetworkException('Couldn\'t reach BAID X. Check your connection and try again.');
    }
    Map<String, dynamic> json = const {};
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {
      // not JSON
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return json;
    final message = json['error'];
    throw AuthFlowException(
      message is String && message.isNotEmpty ? message : 'Something went wrong. Try again.',
    );
  }
}

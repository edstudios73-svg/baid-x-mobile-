import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../errors/app_exception.dart';

/// Calls the BAID X website's server (phone codes, phone sign-in, checkout).
/// The server holds every secret; the app only sends what the member typed and,
/// when needed, their own session token.
class WebApi {
  WebApi({http.Client? client, String? base})
      : _client = client ?? http.Client(),
        _base = base ?? AppConfig.webBase;

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
    } catch (_) {
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

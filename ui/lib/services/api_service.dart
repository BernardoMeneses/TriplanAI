import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  // TODO: Configurar URL base da API

  static const String baseUrl =
      'https://triplanai-backend.triplanai.eupasoft.com/api'; // Para iOS simulator/web

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _authToken;

  // Timeout configurável
  static const Duration timeoutDuration = Duration(seconds: 30);

  // Define o token de autenticação
  void setAuthToken(String? token) {
    _authToken = token;
    if (kDebugMode) {
      print('🔑 API Token set: ${token != null ? "Yes" : "No"}');
    }
  }

  // Headers padrão com token se disponível
  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  // GET request genérico
  Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl$endpoint',
      ).replace(queryParameters: queryParams);
      if (kDebugMode) {
        print('📡 GET: $uri');
      }
      final response = await http
          .get(uri, headers: _headers)
          .timeout(timeoutDuration);
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('❌ GET Error: $e');
      }
      throw ApiException('Erro de conexão: $e');
    }
  }

  // POST request genérico
  Future<dynamic> post(String endpoint, {dynamic body}) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      if (kDebugMode) {
        print('📡 POST: $uri');
      }
      final response = await http
          .post(
            uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeoutDuration);
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('❌ POST Error: $e');
      }
      throw ApiException('Erro de conexão: $e');
    }
  }

  // PUT request genérico
  Future<dynamic> put(String endpoint, {dynamic body}) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http
          .put(
            uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeoutDuration);
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Erro de conexão: $e');
    }
  }

  // DELETE request genérico
  Future<dynamic> delete(String endpoint) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http
          .delete(uri, headers: _headers)
          .timeout(timeoutDuration);
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Erro de conexão: $e');
    }
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      if (response.statusCode == 429) {
        // Silent fail for throttled requests.
        throw ApiException('');
      }
      final error = response.body.isNotEmpty
          ? jsonDecode(response.body)['error'] ?? 'Erro desconhecido'
          : 'Erro ${response.statusCode}';
      throw ApiException(error);
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

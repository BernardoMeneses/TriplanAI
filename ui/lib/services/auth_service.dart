import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:convert';
import 'api_service.dart';

class User {
  final String id;
  final String email;
  final String username;
  final String fullName;
  final String? phone;
  final String? profilePictureUrl;
  final String? authProvider;

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    this.phone,
    this.profilePictureUrl,
    this.authProvider,
  });

  bool get isAppleAccount {
    final provider = authProvider?.toLowerCase();
    if (provider == 'apple') return true;

    // Fallback for older cached sessions that may not include auth_provider.
    return email.toLowerCase().endsWith('privaterelay.appleid.com');
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      fullName: json['full_name'] ?? '',
      phone: json['phone'],
      profilePictureUrl: json['profile_picture_url'],
      authProvider: json['auth_provider']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'full_name': fullName,
      'phone': phone,
      'profile_picture_url': profilePictureUrl,
      'auth_provider': authProvider,
    };
  }
}

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';
  static const String _lastAuthKey = 'auth_last_validated';
  static const int _offlineCacheHours = 72; // 72 horas de cache offline

  final ApiService _api = ApiService();

  User? _currentUser;
  String? _token;

  User? get currentUser => _currentUser;
  String? get token => _token;
  bool get isAuthenticated => _token != null;

  // Singleton
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  /// Inicializa o serviço de auth - verifica se há token guardado
  /// Suporta modo offline até 72h após última validação
  Future<bool> init() async {
    try {
      if (kDebugMode) {
        print('🔐 AuthService: Iniciando...');
      }

      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);
      final cachedUserJson = prefs.getString(_userKey);
      final lastAuthTimestamp = prefs.getInt(_lastAuthKey);

      if (_token != null) {
        if (kDebugMode) {
          print('🔐 AuthService: Token encontrado');
        }
        _api.setAuthToken(_token);

        // Tentar obter dados do utilizador online
        try {
          final userData = await _api
              .get('/auth/me')
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  if (kDebugMode) {
                    print('⏱️ AuthService: Timeout ao validar token');
                  }
                  throw Exception('errors.timeout'.tr());
                },
              );
          _currentUser = User.fromJson(userData);

          // Guardar dados do utilizador e timestamp em cache
          await _saveUserToCache(prefs);

          if (kDebugMode) {
            print(
              '✅ AuthService: User autenticado online: ${_currentUser?.email}',
            );
          }
          return true;
        } catch (e) {
          // Verificar se podemos usar cache offline
          if (cachedUserJson != null && lastAuthTimestamp != null) {
            final lastAuth = DateTime.fromMillisecondsSinceEpoch(
              lastAuthTimestamp,
            );
            final hoursSinceLastAuth = DateTime.now()
                .difference(lastAuth)
                .inHours;

            if (hoursSinceLastAuth < _offlineCacheHours) {
              // Usar dados em cache - ainda válido
              try {
                final cachedUserData = jsonDecode(cachedUserJson);
                _currentUser = User.fromJson(cachedUserData);
                if (kDebugMode) {
                  print(
                    '📴 AuthService: Modo offline - usando cache (${hoursSinceLastAuth}h desde última validação)',
                  );
                  print('✅ AuthService: User em cache: ${_currentUser?.email}');
                }
                return true;
              } catch (parseError) {
                if (kDebugMode) {
                  print('❌ AuthService: Erro ao parsear cache: $parseError');
                }
              }
            } else {
              if (kDebugMode) {
                print(
                  '⚠️ AuthService: Cache expirado (${hoursSinceLastAuth}h > ${_offlineCacheHours}h)',
                );
              }
            }
          }

          // Token inválido ou cache expirado, limpar
          if (kDebugMode) {
            print(
              '❌ AuthService: Erro ao validar token e sem cache válido: $e',
            );
          }
          await logout();
          return false;
        }
      }

      if (kDebugMode) {
        print('🔐 AuthService: Nenhum token encontrado');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ AuthService Init Error: $e');
      }
      return false;
    }
  }

  /// Guarda dados do utilizador e timestamp em cache para modo offline
  Future<void> _saveUserToCache(SharedPreferences prefs) async {
    if (_currentUser != null) {
      await prefs.setString(_userKey, jsonEncode(_currentUser!.toJson()));
      await prefs.setInt(_lastAuthKey, DateTime.now().millisecondsSinceEpoch);
      if (kDebugMode) {
        print('💾 AuthService: Dados do utilizador guardados em cache');
      }
    }
  }

  /// Login com email e password
  Future<User> login(String email, String password) async {
    try {
      final response = await _api.post(
        '/auth/login',
        body: {'email': email, 'password': password},
      );

      _token = response['token'];
      _currentUser = User.fromJson(response['user']);

      // Guardar token e cache localmente
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, _token!);
      await _saveUserToCache(prefs);

      // Configurar token no API service
      _api.setAuthToken(_token);

      return _currentUser!;
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  /// Registar novo utilizador
  Future<User> register(
    String email,
    String password,
    String fullName,
    String username, {
    String? phone,
  }) async {
    try {
      final response = await _api.post(
        '/auth/register',
        body: {
          'email': email,
          'username': username,
          'password': password,
          'full_name': fullName,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        },
      );

      if (response == null) {
        throw AuthException('errors.generic'.tr());
      }

      final userData = response['user'];
      if (userData == null) {
        throw AuthException('errors.generic'.tr());
      }

      _token = response['token'];
      _currentUser = User.fromJson(userData as Map<String, dynamic>);

      // Guardar token e cache localmente
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, _token!);
      await _saveUserToCache(prefs);

      // Configurar token no API service
      _api.setAuthToken(_token);

      return _currentUser!;
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  /// Registar novo utilizador sem fazer login automático
  Future<Map<String, dynamic>> registerWithoutLogin(
    String email,
    String password,
    String fullName,
    String username, {
    String? phone,
  }) async {
    try {
      final response = await _api.post(
        '/auth/register',
        body: {
          'email': email,
          'username': username,
          'password': password,
          'full_name': fullName,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        },
      );

      if (response == null) {
        throw AuthException('errors.generic'.tr());
      }

      return response;
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  /// Request password reset email
  Future<void> requestPasswordReset(String email) async {
    try {
      await _api.post('/auth/forgot-password', body: {'email': email});
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  /// Login/Register with Google OAuth
  Future<Map<String, dynamic>> googleLogin({
    required String googleId,
    required String email,
    required String name,
    required String idToken,
    String? picture,
    String? accessToken,
  }) async {
    try {
      final response = await _api.post(
        '/auth/google',
        body: {
          'googleId': googleId,
          'email': email,
          'name': name,
          'idToken': idToken,
          if (picture != null) 'picture': picture,
          if (accessToken != null) 'accessToken': accessToken,
        },
      );

      _token = response['token'];
      _currentUser = User.fromJson(response['user']);

      // Guardar token e cache localmente
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, _token!);
      await _saveUserToCache(prefs);

      // Configurar token no API service
      _api.setAuthToken(_token);

      return response;
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  /// Login/Register with Apple OAuth
  Future<Map<String, dynamic>> appleLogin({
    required String appleId,
    required String identityToken,
    String? email,
    String? name,
    String? authorizationCode,
  }) async {
    try {
      final response = await _api.post(
        '/auth/apple',
        body: {
          'appleId': appleId,
          'identityToken': identityToken,
          if (email != null && email.isNotEmpty) 'email': email,
          if (name != null && name.isNotEmpty) 'name': name,
          if (authorizationCode != null && authorizationCode.isNotEmpty)
            'authorizationCode': authorizationCode,
        },
      );

      _token = response['token'];
      _currentUser = User.fromJson(response['user']);

      // Guardar token e cache localmente
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, _token!);
      await _saveUserToCache(prefs);

      // Configurar token no API service
      _api.setAuthToken(_token);

      return response;
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  /// Logout - limpar dados de sessão e cache
  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    _api.setAuthToken(null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.remove(_lastAuthKey);

    if (kDebugMode) {
      print('🔐 AuthService: Logout - cache limpo');
    }
  }

  /// Verifica se estamos em modo offline
  bool get isOfflineMode => _token != null && _currentUser != null;

  /// Retorna quanto tempo falta para o cache expirar (em horas)
  Future<int?> getCacheRemainingHours() async {
    final prefs = await SharedPreferences.getInstance();
    final lastAuthTimestamp = prefs.getInt(_lastAuthKey);
    if (lastAuthTimestamp == null) return null;

    final lastAuth = DateTime.fromMillisecondsSinceEpoch(lastAuthTimestamp);
    final hoursSinceLastAuth = DateTime.now().difference(lastAuth).inHours;
    final remaining = _offlineCacheHours - hoursSinceLastAuth;
    return remaining > 0 ? remaining : 0;
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import '../models/tennis_models.dart';

/// TennisApiClient — Dio-based HTTP client matching Kotlin TennisApi.kt
/// Supports cookies (PersistentCookieJar), Bearer tokens, and CSRF headers.
class TennisApiClient {
  static const String baseUrl = 'https://hungsanity.com/tennis/api/';

  late final Dio _dio;
  late final Dio _sseDio; // Long-lived SSE connection client
  CookieJar? _cookieJar;

  String? _bearerToken;
  String? _csrfToken;

  String? get csrfToken => _csrfToken;

  TennisApiClient() {
    if (!kIsWeb) {
      _cookieJar = CookieJar();
    }

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
    ));

    if (!kIsWeb && _cookieJar != null) {
      _dio.interceptors.add(CookieManager(_cookieJar!));
    }
    
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_bearerToken != null) {
          options.headers['Authorization'] = 'Bearer $_bearerToken';
        }
        if (_csrfToken != null) {
          options.headers['X-CSRF-Token'] = _csrfToken;
        }
        handler.next(options);
      },
    ));

    // SSE client with no read timeout
    _sseDio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: Duration.zero,
      headers: {
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
      },
    ));
    
    if (!kIsWeb && _cookieJar != null) {
      _sseDio.interceptors.add(CookieManager(_cookieJar!));
    }
    
    _sseDio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_bearerToken != null) {
          options.headers['Authorization'] = 'Bearer $_bearerToken';
        }
        handler.next(options);
      },
    ));
  }

  void setBearerToken(String? token) => _bearerToken = token;
  void setCsrfToken(String? token) => _csrfToken = token;

  void clearCookies() {
    if (!kIsWeb) {
      _cookieJar?.deleteAll();
    }
  }

  // ─── Auth ──────────────────────────────────────────────────────────────────

  Future<LoginResponse?> login(LoginRequest request) async {
    final resp = await _dio.post('auth/login', data: request.toJson());
    return LoginResponse.fromJson(resp.data);
  }

  Future<LoginResponse?> checkAuthStatus() async {
    final resp = await _dio.get('auth/status');
    return LoginResponse.fromJson(resp.data);
  }

  Future<GeneralResponse?> logout() async {
    final resp = await _dio.post('auth/logout');
    return GeneralResponse.fromJson(resp.data);
  }

  Future<LoginResponse?> refreshAuth() async {
    final resp = await _dio.post('auth/refresh');
    return LoginResponse.fromJson(resp.data);
  }

  // ─── System ────────────────────────────────────────────────────────────────

  Future<InitResponse?> getInitData() async {
    final resp = await _dio.get('init');
    return InitResponse.fromJson(resp.data);
  }

  Future<DataVersionResponse?> getDataVersion() async {
    final resp = await _dio.get('data-version');
    return DataVersionResponse.fromJson(resp.data);
  }

  Future<CSRFResponse?> getCsrfToken() async {
    final resp = await _dio.post('csrf-token');
    return CSRFResponse.fromJson(resp.data);
  }

  // ─── Players ───────────────────────────────────────────────────────────────

  Future<List<Player>> getPlayers() async {
    final resp = await _dio.get('players');
    return (resp.data as List).map((e) => Player.fromJson(e)).toList();
  }

  Future<GeneralResponse?> createPlayer(CreatePlayerRequest request) async {
    final resp = await _dio.post('players', data: request.toJson());
    return GeneralResponse.fromJson(resp.data);
  }

  Future<GeneralResponse?> deletePlayer(int id) async {
    final resp = await _dio.delete('players/$id');
    return GeneralResponse.fromJson(resp.data);
  }

  // ─── Seasons ───────────────────────────────────────────────────────────────

  Future<List<Season>> getSeasons() async {
    final resp = await _dio.get('seasons');
    return (resp.data as List).map((e) => Season.fromJson(e)).toList();
  }

  Future<List<Season>> getActiveSeasons() async {
    final resp = await _dio.get('seasons/active');
    return (resp.data as List).map((e) => Season.fromJson(e)).toList();
  }

  Future<GeneralResponse?> createSeason(CreateSeasonRequest request) async {
    final resp = await _dio.post('seasons', data: request.toJson());
    return GeneralResponse.fromJson(resp.data);
  }

  Future<GeneralResponse?> updateSeason(int id, CreateSeasonRequest request) async {
    final resp = await _dio.put('seasons/$id', data: request.toJson());
    return GeneralResponse.fromJson(resp.data);
  }

  Future<GeneralResponse?> deleteSeason(int id) async {
    final resp = await _dio.delete('seasons/$id');
    return GeneralResponse.fromJson(resp.data);
  }

  Future<List<Player>> getSeasonPlayers(int id) async {
    final resp = await _dio.get('seasons/$id/players');
    return (resp.data as List).map((e) => Player.fromJson(e)).toList();
  }

  Future<GeneralResponse?> replaceSeasonPlayers(int id, SeasonPlayersRequest request) async {
    final resp = await _dio.post('seasons/$id/players', data: request.toJson());
    return GeneralResponse.fromJson(resp.data);
  }

  Future<GeneralResponse?> endSeason(int id, EndSeasonRequest request) async {
    final resp = await _dio.post('seasons/$id/end', data: request.toJson());
    return GeneralResponse.fromJson(resp.data);
  }

  Future<GeneralResponse?> reactivateSeason(int id) async {
    final resp = await _dio.post('seasons/$id/reactivate');
    return GeneralResponse.fromJson(resp.data);
  }

  // ─── Matches ───────────────────────────────────────────────────────────────

  Future<List<Match>> getMatches({int? limit = 100}) async {
    final resp = await _dio.get('matches', queryParameters: {'limit': limit});
    return (resp.data as List).map((e) => Match.fromJson(e)).toList();
  }

  Future<List<Match>> getMatchesByDate(String date) async {
    final resp = await _dio.get('matches/by-date/$date');
    return (resp.data as List).map((e) => Match.fromJson(e)).toList();
  }

  Future<List<Match>> getMatchesBySeason(int seasonId) async {
    final resp = await _dio.get('matches/by-season/$seasonId');
    return (resp.data as List).map((e) => Match.fromJson(e)).toList();
  }

  Future<GeneralResponse?> createMatch(CreateMatchRequest request) async {
    final resp = await _dio.post('matches', data: request.toJson());
    return GeneralResponse.fromJson(resp.data);
  }

  Future<GeneralResponse?> updateMatch(int id, CreateMatchRequest request) async {
    final resp = await _dio.put('matches/$id', data: request.toJson());
    return GeneralResponse.fromJson(resp.data);
  }

  Future<GeneralResponse?> deleteMatch(int id) async {
    final resp = await _dio.delete('matches/$id');
    return GeneralResponse.fromJson(resp.data);
  }

  // ─── Rankings ──────────────────────────────────────────────────────────────

  Future<List<RankingEntry>> getLifetimeRankings() async {
    final resp = await _dio.get('rankings/lifetime');
    return (resp.data as List).map((e) => RankingEntry.fromJson(e)).toList();
  }

  Future<List<RankingEntry>> getSeasonRankings(int seasonId) async {
    final resp = await _dio.get('rankings/season/$seasonId');
    return (resp.data as List).map((e) => RankingEntry.fromJson(e)).toList();
  }

  Future<List<RankingEntry>> getDateRankings(String date) async {
    final resp = await _dio.get('rankings/date/$date');
    return (resp.data as List).map((e) => RankingEntry.fromJson(e)).toList();
  }

  // ─── SSE ───────────────────────────────────────────────────────────────────

  /// Returns a Response stream for SSE. Caller is responsible for reading lines.
  Future<Response<ResponseBody>> connectSseStream() async {
    return _sseDio.get<ResponseBody>(
      'events',
      options: Options(responseType: ResponseType.stream),
    );
  }

  /// Parse error body from DioException
  String parseError(DioException e) {
    if (e.response?.data is Map) {
      final map = e.response!.data as Map;
      return (map['error'] ?? map['message'] ?? 'Server error: ${e.response?.statusCode}').toString();
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Network error. Please check your connection.';
    }
    return 'Unexpected error occurred.';
  }
}

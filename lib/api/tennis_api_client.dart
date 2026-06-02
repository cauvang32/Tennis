import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:brotli/brotli.dart';
import 'package:flutter/foundation.dart';
import '../models/tennis_models.dart';

/// Custom dio [Transformer] that decodes compressed response bodies
/// (Content-Encoding: br / gzip / deflate) before the JSON parser sees them.
/// The backend now serves every API response compressed, but dio has no
/// built-in decoder for any of these. Without this transformer, dio hands
/// raw compressed bytes to `LoginResponse.fromJson(...)`, throws a type
/// error, and the user sees "Unexpected error occurred." for every call.
class CompressionTransformer implements Transformer {
  final Transformer _inner;
  CompressionTransformer(this._inner);

  @override
  Future<String> transformRequest(RequestOptions options) =>
      _inner.transformRequest(options);

  @override
  Future<dynamic> transformResponse(RequestOptions options, ResponseBody response) async {
    final headerEncoding = response.headers['content-encoding']?.firstOrNull?.toLowerCase();

    // Read the body once. `.asBroadcastStream()` is required because dio's
    // internal `response_stream_handler.dart` wraps the raw HTTP stream in a
    // single-subscription StreamController; the wrapper's own subscription is
    // the first listener. We rebroadcast so we can read it here even when the
    // wrapper is mid-teardown (e.g. on a dropped connection).
    late final List<int> compressed;
    try {
      final source = response.stream.asBroadcastStream();
      compressed = await source.fold<List<int>>(
        <int>[],
        (List<int> acc, List<int> chunk) => acc..addAll(chunk),
      );
    } catch (e, st) {
      debugPrint('[CompressionTransformer] body read FAILED for ${options.uri}: $e');
      debugPrint(st.toString());
      return Future<dynamic>.error(_dioExceptionFrom(options, response, e));
    }

    // debugPrint (not developer.log) — the latter does not appear in `adb logcat`.
    debugPrint('[CompressionTransformer] ${response.statusCode} ${options.uri} '
          'header-encoding=$headerEncoding compressedBytes=${compressed.length}');

    if (headerEncoding != null && headerEncoding != 'identity' && compressed.isNotEmpty) {
      final List<int> decompressed;
      try {
        decompressed = _decompress(compressed, headerEncoding);
      } catch (e, st) {
        debugPrint('[CompressionTransformer] decode FAILED for ${options.uri} '
              'header-encoding=$headerEncoding: $e');
        debugPrint(st.toString());
        return Future<dynamic>.error(_dioExceptionFrom(options, response, e));
      }
      debugPrint('[CompressionTransformer] decompressedBytes=${decompressed.length}');
      final newHeaders = Map<String, List<String>>.from(response.headers);
      newHeaders['content-encoding'] = ['identity'];
      newHeaders['content-length'] = [decompressed.length.toString()];
      final newResponse = ResponseBody(
        Stream.value(Uint8List.fromList(decompressed)),
        response.statusCode,
        headers: newHeaders,
        statusMessage: response.statusMessage,
        isRedirect: response.isRedirect,
      );
      return _inner.transformResponse(options, newResponse);
    }

    // No compression claimed, or identity — pass the original (possibly empty)
    // body through to the inner transformer.
    return _inner.transformResponse(options, response);
  }

  /// Try multiple decoders in a sensible order. Returns the first one that
  /// succeeds, or throws [FormatException] with the chain of failures.
  ///
  /// Order:
  ///   1. Magic-byte sniff (gzip 0x1f 0x8b / deflate 0x78 ?? / JSON 0x7b|0x5b).
  ///   2. Header-declared encoding (server's claim, as a hint).
  ///   3. Brotli (no magic bytes — must be probed; known to be the actual
  ///      format hungsanity.com sends even when the header says gzip).
  ///   4. The other classic encoding (last-resort safety net).
  List<int> _decompress(List<int> compressed, String headerEncoding) {
    // 1. Magic-byte sniff — fastest and most reliable for gzip/deflate.
    if (compressed.length >= 2 && compressed[0] == 0x1f && compressed[1] == 0x8b) {
      debugPrint('[CompressionTransformer] magic-bytes: gzip');
      return gzip.decode(compressed);
    }
    if (compressed.isNotEmpty &&
        compressed[0] == 0x78 &&
        compressed.length >= 2 &&
        const {0x01, 0x5e, 0x9c, 0xda}.contains(compressed[1])) {
      debugPrint('[CompressionTransformer] magic-bytes: deflate');
      return zlib.decode(compressed);
    }
    // Body is already plain text (JSON object/array) — server lied about encoding.
    if (compressed.isNotEmpty && (compressed[0] == 0x7b || compressed[0] == 0x5b)) {
      debugPrint('[CompressionTransformer] magic-bytes: identity (JSON)');
      return compressed;
    }

    // 2. Build the fallback chain. Header is the server's claim, brotli is the
    //    most likely alternative based on observed server behaviour, and the
    //    other classic encoding is the final safety net.
    final candidates = <String>[];
    void addCandidate(String c) {
      if (!candidates.contains(c)) candidates.add(c);
    }

    addCandidate(headerEncoding);
    addCandidate('br');
    if (headerEncoding == 'gzip') addCandidate('deflate');
    if (headerEncoding == 'deflate') addCandidate('gzip');

    final failures = <String>[];
    for (final enc in candidates) {
      try {
        switch (enc) {
          case 'br':
            final out = const BrotliDecoder().convert(compressed);
            debugPrint('[CompressionTransformer] fallback matched: brotli');
            return out;
          case 'gzip':
            final out = gzip.decode(compressed);
            debugPrint('[CompressionTransformer] fallback matched: gzip');
            return out;
          case 'deflate':
            final out = zlib.decode(compressed);
            debugPrint('[CompressionTransformer] fallback matched: deflate');
            return out;
          default:
            continue;
        }
      } catch (e) {
        failures.add('$enc: $e');
      }
    }
    throw FormatException(
      'Unable to decompress response. Tried [${candidates.join(", ")}]. '
      'Failures: ${failures.join(" | ")}',
    );
  }

  DioException _dioExceptionFrom(RequestOptions options, ResponseBody response, Object error) {
    return DioException(
      requestOptions: options,
      response: Response<dynamic>(
        requestOptions: options,
        statusCode: response.statusCode,
        statusMessage: response.statusMessage,
      ),
      type: DioExceptionType.unknown,
      error: error,
    );
  }
}

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
      // Exclude `br` so servers that respect Accept-Encoding (nginx + ngx_brotli
      // does) will send gzip instead. Most servers still send brotli only when
      // the client advertises support; the transformer below is a safety net
      // for the ones that force-encode regardless.
      headers: {
        'Accept': 'application/json',
        'Accept-Encoding': 'gzip, deflate',
      },
    ));
    _dio.transformer = CompressionTransformer(_dio.transformer);

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
    final status = e.response?.statusCode;
    if (status == 429) {
      return 'Too many requests. Please wait a moment and try again.';
    }
    if (e.response?.data is Map) {
      final map = e.response!.data as Map;
      return (map['error'] ?? map['message'] ?? 'Server error: ${e.response?.statusCode}').toString();
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Network error. Please check your connection.';
      case DioExceptionType.connectionError:
        return 'Cannot reach server. Please check your connection.';
      case DioExceptionType.badCertificate:
        return 'Server certificate could not be verified.';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        // Surface the underlying exception (SocketException, HandshakeException,
        // CertificateException, …) so the user-visible error explains *why*
        // the request died — otherwise they only see "Unexpected error".
        final underlying = e.error?.toString();
        return underlying != null
            ? 'Unexpected error: $underlying'
            : 'Unexpected error occurred.';
    }
  }
}

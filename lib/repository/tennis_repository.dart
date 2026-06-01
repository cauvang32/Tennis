import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/tennis_api_client.dart';
import '../models/tennis_models.dart';

import '../utils/notification_helper.dart';

/// TennisRepository — Singleton state manager matching Kotlin TennisRepository.kt
/// Manages auth, data fetching, caching, SSE background sync, and polling.
class TennisRepository extends ChangeNotifier {
  final TennisApiClient _api = TennisApiClient();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // ─── State ──────────────────────────────────────────────────────────────────

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  User? _currentUser;
  User? get currentUser => _currentUser;

  String? _csrfToken;
  String? get csrfToken => _csrfToken;

  InitResponse? _initData;
  InitResponse? get initData => _initData;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Theme: null = system, false = light, true = dark
  bool? _themeOverride;
  bool? get themeOverride => _themeOverride;

  // ─── Initialization ────────────────────────────────────────────────────────

  Future<void> initialize() async {
    try {
      final token = await _secureStorage.read(key: 'bearer_token');
      if (token != null) {
        _api.setBearerToken(token);
      }
      final csrf = await _secureStorage.read(key: 'csrf_token');
      if (csrf != null) {
        _csrfToken = csrf;
        _api.setCsrfToken(csrf);
      }
      final userJson = await _secureStorage.read(key: 'user_json');
      if (userJson != null) {
        try {
          _currentUser = User.fromJson(jsonDecode(userJson));
          _isAuthenticated = true;
        } catch (e) {
          developer.log('Error reading stored user: $e', name: 'TennisRepository');
        }
      }
    } catch (e) {
      developer.log('Failed to load secure storage: $e', name: 'TennisRepository');
    }
  }

  void clearErrorMessage() {
    _errorMessage = null;
    notifyListeners();
  }

  void toggleThemeOption() {
    if (_themeOverride == null) {
      _themeOverride = false;
    } else if (_themeOverride == false) {
      _themeOverride = true;
    } else {
      _themeOverride = null;
    }
    notifyListeners();
  }

  void setTheme(bool? dark) {
    _themeOverride = dark;
    notifyListeners();
  }

  // ─── Safe API Call Wrapper ─────────────────────────────────────────────────

  Future<T?> _safeApiCall<T>(
    Future<T> Function() call, {
    bool showLoading = true,
  }) async {
    if (showLoading) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }
    try {
      final result = await call();
      if (showLoading) {
        _isLoading = false;
        notifyListeners();
      }
      return result;
    } on DioException catch (e) {
      final parsedError = _api.parseError(e);
      final statusCode = e.response?.statusCode;
      if (statusCode == 401 ||
          (statusCode == 403 && parsedError.toLowerCase().contains('csrf'))) {
        developer.log('Auth expired or CSRF error, clearing session', name: 'TennisRepository');
        await _clearSession();
      }
      if (showLoading) {
        _errorMessage = parsedError;
        _isLoading = false;
        notifyListeners();
      } else {
        developer.log('Background call error (suppressed): $parsedError', name: 'TennisRepository');
      }
      return null;
    } catch (e) {
      if (showLoading) {
        _errorMessage = 'Unexpected error occurred.';
        _isLoading = false;
        notifyListeners();
      }
      developer.log('API execution error: $e', name: 'TennisRepository');
      return null;
    }
  }

  // ─── Init Data ─────────────────────────────────────────────────────────────

  Future<InitResponse?> fetchInitData({bool showLoading = true}) async {
    final result = await _safeApiCall(() => _api.getInitData(), showLoading: showLoading);
    if (result != null) {
      _initData = result;
      if (result.csrfToken != null) {
        await _setCsrfToken(result.csrfToken!);
      }
      _currentUser = result.user;
      _isAuthenticated = result.isAuthenticated ?? false;
      if (result.user == null && _isAuthenticated) {
        await _clearSession();
      }
      notifyListeners();

      // Trigger notifications for new matches/seasons on mobile
      NotificationHelper().checkForNewMatches(result.defaultDateMatches ?? []);
      NotificationHelper().checkForNewSeasons(result.seasons ?? []);
    }
    return result;
  }

  // ─── Auth ──────────────────────────────────────────────────────────────────

  Future<bool> login(LoginRequest req) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final body = await _api.login(req);
      if (body != null && body.success) {
        await _saveSession(body);
        _isLoading = false;
        notifyListeners();
        await fetchInitData();
        return true;
      } else {
        _errorMessage = body?.message ?? 'Login failed';
      }
    } on DioException catch (e) {
      _errorMessage = _api.parseError(e);
    } catch (e) {
      _errorMessage = 'Login error: $e';
      developer.log('Login exception: $e', name: 'TennisRepository');
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> refreshSession() async {
    try {
      final body = await _api.refreshAuth();
      if (body != null && body.success) {
        await _saveSession(body);
        return true;
      }
    } catch (e) {
      developer.log('Session refresh failed: $e', name: 'TennisRepository');
    }
    return false;
  }

  Future<bool> logoutAction() async {
    try {
      await _api.logout();
    } catch (_) {}
    await _clearSession();
    notifyListeners();
    await fetchInitData();
    return true;
  }

  // ─── CSRF ──────────────────────────────────────────────────────────────────

  Future<String?> fetchCsrfToken() async {
    final result = await _safeApiCall(() => _api.getCsrfToken());
    if (result != null) {
      await _setCsrfToken(result.csrfToken);
      return result.csrfToken;
    }
    return null;
  }

  // ─── Data Version ──────────────────────────────────────────────────────────

  Future<int?> checkDataVersion({bool showLoading = false}) async {
    final result = await _safeApiCall(() => _api.getDataVersion(), showLoading: showLoading);
    return result?.version;
  }

  // ─── Players ───────────────────────────────────────────────────────────────

  Future<bool> createPlayer(String name) async {
    final res = await _safeApiCall(() => _api.createPlayer(CreatePlayerRequest(name: name)));
    if (res?.success == true) {
      await fetchInitData();
      return true;
    }
    return false;
  }

  Future<bool> deletePlayer(int id) async {
    final res = await _safeApiCall(() => _api.deletePlayer(id));
    if (res?.success == true) {
      await fetchInitData();
      return true;
    }
    return false;
  }

  Future<List<Player>?> fetchPlayers() async {
    return _safeApiCall(() => _api.getPlayers());
  }

  // ─── Seasons ───────────────────────────────────────────────────────────────

  Future<bool> createSeason(CreateSeasonRequest req) async {
    final res = await _safeApiCall(() => _api.createSeason(req));
    if (res?.success == true) {
      await fetchInitData();
      return true;
    }
    return false;
  }

  Future<bool> updateSeason(int id, CreateSeasonRequest req) async {
    final res = await _safeApiCall(() => _api.updateSeason(id, req));
    if (res?.success == true) {
      await fetchInitData();
      return true;
    }
    return false;
  }

  Future<bool> deleteSeason(int id) async {
    final res = await _safeApiCall(() => _api.deleteSeason(id));
    if (res?.success == true) {
      await fetchInitData();
      return true;
    }
    return false;
  }

  Future<bool> endSeason(int id, String endDate) async {
    final res = await _safeApiCall(() => _api.endSeason(id, EndSeasonRequest(endDate: endDate)));
    if (res?.success == true) {
      await fetchInitData();
      return true;
    }
    return false;
  }

  Future<bool> reactivateSeason(int id) async {
    final res = await _safeApiCall(() => _api.reactivateSeason(id));
    if (res?.success == true) {
      await fetchInitData();
      return true;
    }
    return false;
  }

  Future<bool> updateSeasonPlayers(int seasonId, List<int> playerIds) async {
    final res = await _safeApiCall(
        () => _api.replaceSeasonPlayers(seasonId, SeasonPlayersRequest(playerIds: playerIds)));
    if (res?.success == true) {
      await fetchInitData();
      return true;
    }
    return false;
  }

  Future<List<Player>> getSeasonPlayers(int seasonId) async {
    final res = await _safeApiCall(() => _api.getSeasonPlayers(seasonId), showLoading: false);
    return res ?? [];
  }

  // ─── Matches ───────────────────────────────────────────────────────────────

  Future<bool> createMatch(CreateMatchRequest req) async {
    final res = await _safeApiCall(() => _api.createMatch(req));
    if (res?.success == true) {
      await fetchInitData();
      return true;
    }
    return false;
  }

  Future<bool> updateMatch(int id, CreateMatchRequest req) async {
    final res = await _safeApiCall(() => _api.updateMatch(id, req));
    if (res?.success == true) {
      await fetchInitData();
      return true;
    }
    return false;
  }

  Future<bool> deleteMatch(int id) async {
    final res = await _safeApiCall(() => _api.deleteMatch(id));
    if (res?.success == true) {
      await fetchInitData();
      return true;
    }
    return false;
  }

  Future<List<Match>?> fetchMatchesByDate(String date) async {
    return _safeApiCall(() => _api.getMatchesByDate(date));
  }

  Future<List<Match>?> fetchMatchesBySeason(int seasonId) async {
    return _safeApiCall(() => _api.getMatchesBySeason(seasonId));
  }

  // ─── Rankings ──────────────────────────────────────────────────────────────

  Future<List<RankingEntry>?> fetchLifetimeRankings() async {
    return _safeApiCall(() => _api.getLifetimeRankings());
  }

  Future<List<RankingEntry>?> fetchSeasonRankings(int seasonId) async {
    return _safeApiCall(() => _api.getSeasonRankings(seasonId));
  }

  Future<List<RankingEntry>?> fetchDateRankings(String date) async {
    return _safeApiCall(() => _api.getDateRankings(date));
  }

  // ─── Session Management ────────────────────────────────────────────────────

  Future<void> _saveSession(LoginResponse loginResponse) async {
    if (loginResponse.token != null) {
      _api.setBearerToken(loginResponse.token);
      await _secureStorage.write(key: 'bearer_token', value: loginResponse.token);
    }
    if (loginResponse.csrfToken != null) {
      _csrfToken = loginResponse.csrfToken;
      _api.setCsrfToken(loginResponse.csrfToken);
      await _secureStorage.write(key: 'csrf_token', value: loginResponse.csrfToken);
    }
    if (loginResponse.user != null) {
      _currentUser = loginResponse.user;
      _isAuthenticated = true;
      await _secureStorage.write(key: 'user_json', value: jsonEncode(loginResponse.user!.toJson()));
    }
  }

  Future<void> _setCsrfToken(String csrf) async {
    _csrfToken = csrf;
    _api.setCsrfToken(csrf);
    await _secureStorage.write(key: 'csrf_token', value: csrf);
  }

  Future<void> _clearSession() async {
    _api.setBearerToken(null);
    _currentUser = null;
    _isAuthenticated = false;
    _csrfToken = null;
    _api.setCsrfToken(null);
    _api.clearCookies();
    await _secureStorage.delete(key: 'bearer_token');
    await _secureStorage.delete(key: 'csrf_token');
    await _secureStorage.delete(key: 'user_json');
  }

  // ─── Background Sync (SSE + Polling) ──────────────────────────────────────

  bool _isSyncRunning = false;
  Timer? _pollingTimer;
  CancelToken? _sseCancelToken;
  int _lastSseFetchTime = 0;

  void startBackgroundSync() {
    if (_isSyncRunning) return;
    _isSyncRunning = true;

    // 1. SSE stream
    _connectSse();

    // 2. Polling fallback every 15 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      try {
        final latestVersion = await checkDataVersion(showLoading: false);
        final currentVersion = _initData?.version ?? 0;
        if (latestVersion != null && latestVersion > currentVersion) {
          developer.log('Newer version detected via polling. Fetching init data...', name: 'TennisRepository');
          await fetchInitData(showLoading: false);
        }
      } catch (e) {
        developer.log('Polling fallback error: $e', name: 'TennisRepository');
      }
    });
  }

  void stopBackgroundSync() {
    if (!_isSyncRunning) return;
    _isSyncRunning = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _sseCancelToken?.cancel('Stopping sync');
    _sseCancelToken = null;
  }

  Future<void> _connectSse() async {
    while (_isSyncRunning) {
      _sseCancelToken = CancelToken();
      try {
        developer.log('Connecting to SSE stream...', name: 'TennisRepository');
        final response = await _api.connectSseStream();
        final stream = response.data?.stream;
        if (stream == null) continue;

        developer.log('SSE stream established', name: 'TennisRepository');
        await for (final chunk in stream) {
          if (!_isSyncRunning) break;
          final text = utf8.decode(chunk);
          for (final line in text.split('\n')) {
            if (line.trim().startsWith('data:')) {
              final now = DateTime.now().millisecondsSinceEpoch;
              if (now - _lastSseFetchTime > 2000) {
                _lastSseFetchTime = now;
                developer.log('SSE event received, triggering sync', name: 'TennisRepository');
                await fetchInitData(showLoading: false);
              }
            }
          }
        }
      } catch (e) {
        if (_isSyncRunning) {
          developer.log('SSE disconnect: $e', name: 'TennisRepository');
        }
      }
      // Retry after 3 seconds
      if (_isSyncRunning) {
        await Future.delayed(const Duration(seconds: 3));
      }
    }
  }
}

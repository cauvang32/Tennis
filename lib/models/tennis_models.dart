/// Data models matching the Kotlin TennisModels.kt
/// Using plain Dart classes with fromJson/toJson for simplicity and zero codegen.
library;

class User {
  final int? id;
  final String? username;
  final String? email;
  final String? role;
  final String? displayName;

  const User({this.id, this.username, this.email, this.role, this.displayName});

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int?,
        username: json['username'] as String?,
        email: json['email'] as String?,
        role: json['role'] as String?,
        displayName: json['displayName'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'email': email,
        'role': role,
        'displayName': displayName,
      };
}

class Player {
  final int id;
  final String name;
  final String? createdAt;

  const Player({required this.id, required this.name, this.createdAt});

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: _toInt(json['id'])!,
        name: json['name'] as String,
        createdAt: json['created_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'created_at': createdAt,
      };
}

class Season {
  final int id;
  final String name;
  final String startDate;
  final String? endDate;
  final bool isActive;
  final bool autoEnd;
  final String? description;
  final int? loseMoneyPerLoss;

  const Season({
    required this.id,
    required this.name,
    required this.startDate,
    this.endDate,
    required this.isActive,
    required this.autoEnd,
    this.description,
    this.loseMoneyPerLoss,
  });

  factory Season.fromJson(Map<String, dynamic> json) => Season(
        id: _toInt(json['id'])!,
        name: json['name'] as String,
        startDate: json['start_date'] as String,
        endDate: json['end_date'] as String?,
        isActive: json['is_active'] as bool? ?? false,
        autoEnd: json['auto_end'] as bool? ?? false,
        description: json['description'] as String?,
        loseMoneyPerLoss: _toInt(json['lose_money_per_loss']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'start_date': startDate,
        'end_date': endDate,
        'is_active': isActive,
        'auto_end': autoEnd,
        'description': description,
        'lose_money_per_loss': loseMoneyPerLoss,
      };
}

class Match {
  final int id;
  final int seasonId;
  final String playDate;
  final int player1Id;
  final int? player2Id;
  final int player3Id;
  final int? player4Id;
  final int team1Score;
  final int team2Score;
  final int winningTeam;
  final String matchType;
  final String? player1Name;
  final String? player2Name;
  final String? player3Name;
  final String? player4Name;

  const Match({
    required this.id,
    required this.seasonId,
    required this.playDate,
    required this.player1Id,
    this.player2Id,
    required this.player3Id,
    this.player4Id,
    required this.team1Score,
    required this.team2Score,
    required this.winningTeam,
    required this.matchType,
    this.player1Name,
    this.player2Name,
    this.player3Name,
    this.player4Name,
  });

  factory Match.fromJson(Map<String, dynamic> json) => Match(
        id: _toInt(json['id'])!,
        seasonId: _toInt(json['season_id'])!,
        playDate: json['play_date'] as String,
        player1Id: _toInt(json['player1_id'])!,
        player2Id: _toInt(json['player2_id']),
        player3Id: _toInt(json['player3_id'])!,
        player4Id: _toInt(json['player4_id']),
        team1Score: _toInt(json['team1_score'])!,
        team2Score: _toInt(json['team2_score'])!,
        winningTeam: _toInt(json['winning_team'])!,
        matchType: json['match_type'] as String,
        player1Name: json['player1_name'] as String?,
        player2Name: json['player2_name'] as String?,
        player3Name: json['player3_name'] as String?,
        player4Name: json['player4_name'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'season_id': seasonId,
        'play_date': playDate,
        'player1_id': player1Id,
        'player2_id': player2Id,
        'player3_id': player3Id,
        'player4_id': player4Id,
        'team1_score': team1Score,
        'team2_score': team2Score,
        'winning_team': winningTeam,
        'match_type': matchType,
        'player1_name': player1Name,
        'player2_name': player2Name,
        'player3_name': player3Name,
        'player4_name': player4Name,
      };
}

class FormEntry {
  final String? result;
  final String? playDate;

  const FormEntry({this.result, this.playDate});

  factory FormEntry.fromJson(Map<String, dynamic> json) => FormEntry(
        result: json['result'] as String?,
        playDate: json['play_date'] as String?,
      );
}

class RankingEntry {
  final int id;
  final String name;
  final int wins;
  final int losses;
  final int totalMatches;
  final int points;
  final double? winPercentage;
  final int? moneyLost;
  final List<FormEntry>? form;

  const RankingEntry({
    required this.id,
    required this.name,
    required this.wins,
    required this.losses,
    required this.totalMatches,
    required this.points,
    this.winPercentage,
    this.moneyLost,
    this.form,
  });

  List<String> get formStrings =>
      form?.map((f) => f.result?.toLowerCase() == 'win' ? 'W' : 'L').toList() ?? [];

  factory RankingEntry.fromJson(Map<String, dynamic> json) => RankingEntry(
        id: _toInt(json['id'])!,
        name: json['name'] as String,
        wins: _toInt(json['wins']) ?? 0,
        losses: _toInt(json['losses']) ?? 0,
        totalMatches: _toInt(json['total_matches']) ?? 0,
        points: _toInt(json['points']) ?? 0,
        winPercentage: _toDouble(json['win_percentage']),
        moneyLost: _toInt(json['money_lost']),
        form: (json['form'] as List<dynamic>?)
            ?.map((e) => FormEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class PlayDateEntry {
  final String playDate;

  const PlayDateEntry({required this.playDate});

  factory PlayDateEntry.fromJson(Map<String, dynamic> json) => PlayDateEntry(
        playDate: json['play_date'] as String,
      );
}

class InitResponse {
  final List<RankingEntry>? lifetimeRankings;
  final List<Player>? players;
  final List<Season>? seasons;
  final List<Season>? activeSeasons;
  final List<PlayDateEntry>? playDates;
  final Season? activeSeason;
  final String? defaultDate;
  final List<RankingEntry>? defaultDateRankings;
  final List<Match>? defaultDateMatches;
  final bool? isAuthenticated;
  final User? user;
  final String? csrfToken;
  final int? version;

  const InitResponse({
    this.lifetimeRankings,
    this.players,
    this.seasons,
    this.activeSeasons,
    this.playDates,
    this.activeSeason,
    this.defaultDate,
    this.defaultDateRankings,
    this.defaultDateMatches,
    this.isAuthenticated,
    this.user,
    this.csrfToken,
    this.version,
  });

  List<String> get playDateStrings =>
      playDates?.map((p) => p.playDate).toList() ?? [];

  factory InitResponse.fromJson(Map<String, dynamic> json) => InitResponse(
        lifetimeRankings: _parseList(json['lifetimeRankings'], RankingEntry.fromJson),
        players: _parseList(json['players'], Player.fromJson),
        seasons: _parseList(json['seasons'], Season.fromJson),
        activeSeasons: _parseList(json['activeSeasons'], Season.fromJson),
        playDates: _parseList(json['playDates'], PlayDateEntry.fromJson),
        activeSeason: json['activeSeason'] != null
            ? Season.fromJson(json['activeSeason'] as Map<String, dynamic>)
            : null,
        defaultDate: json['defaultDate'] as String?,
        defaultDateRankings:
            _parseList(json['defaultDateRankings'], RankingEntry.fromJson),
        defaultDateMatches:
            _parseList(json['defaultDateMatches'], Match.fromJson),
        isAuthenticated: json['isAuthenticated'] as bool?,
        user: json['user'] != null
            ? User.fromJson(json['user'] as Map<String, dynamic>)
            : null,
        csrfToken: json['csrfToken'] as String?,
        version: _toInt(json['version']),
      );
}

// Request payloads
class LoginRequest {
  final String username;
  final String password;

  const LoginRequest({required this.username, required this.password});

  Map<String, dynamic> toJson() => {'username': username, 'password': password};
}

class LoginResponse {
  final bool success;
  final String? message;
  final String? csrfToken;
  final User? user;
  final String? token;
  final String? authMethod;

  const LoginResponse({
    required this.success,
    this.message,
    this.csrfToken,
    this.user,
    this.token,
    this.authMethod,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
        success: json['success'] as bool? ?? false,
        message: json['message'] as String?,
        csrfToken: json['csrfToken'] as String?,
        user: json['user'] != null
            ? User.fromJson(json['user'] as Map<String, dynamic>)
            : null,
        token: json['token'] as String?,
        authMethod: json['authMethod'] as String?,
      );
}

class GeneralResponse {
  final bool success;
  final String? message;
  final int? id;
  final String? name;

  const GeneralResponse({required this.success, this.message, this.id, this.name});

  factory GeneralResponse.fromJson(Map<String, dynamic> json) => GeneralResponse(
        success: json['success'] as bool? ?? false,
        message: json['message'] as String?,
        id: _toInt(json['id']),
        name: json['name'] as String?,
      );
}

class CSRFResponse {
  final String csrfToken;

  const CSRFResponse({required this.csrfToken});

  factory CSRFResponse.fromJson(Map<String, dynamic> json) => CSRFResponse(
        csrfToken: json['csrfToken'] as String,
      );
}

class DataVersionResponse {
  final int version;

  const DataVersionResponse({required this.version});

  factory DataVersionResponse.fromJson(Map<String, dynamic> json) =>
      DataVersionResponse(version: _toInt(json['version'])!);
}

class CreatePlayerRequest {
  final String name;
  const CreatePlayerRequest({required this.name});
  Map<String, dynamic> toJson() => {'name': name};
}

class CreateSeasonRequest {
  final String name;
  final String startDate;
  final String? endDate;
  final bool autoEnd;
  final int loseMoneyPerLoss;
  final List<int> playerIds;
  final String? description;

  const CreateSeasonRequest({
    required this.name,
    required this.startDate,
    this.endDate,
    required this.autoEnd,
    required this.loseMoneyPerLoss,
    required this.playerIds,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'startDate': startDate,
        'endDate': endDate,
        'autoEnd': autoEnd,
        'loseMoneyPerLoss': loseMoneyPerLoss,
        'playerIds': playerIds,
        'description': description,
      };
}

class CreateMatchRequest {
  final int seasonId;
  final String playDate;
  final int player1Id;
  final int? player2Id;
  final int player3Id;
  final int? player4Id;
  final int team1Score;
  final int team2Score;
  final int winningTeam;
  final String matchType;

  const CreateMatchRequest({
    required this.seasonId,
    required this.playDate,
    required this.player1Id,
    this.player2Id,
    required this.player3Id,
    this.player4Id,
    required this.team1Score,
    required this.team2Score,
    required this.winningTeam,
    required this.matchType,
  });

  Map<String, dynamic> toJson() => {
        'seasonId': seasonId,
        'playDate': playDate,
        'player1Id': player1Id,
        'player2Id': player2Id,
        'player3Id': player3Id,
        'player4Id': player4Id,
        'team1Score': team1Score,
        'team2Score': team2Score,
        'winningTeam': winningTeam,
        'matchType': matchType,
      };
}

class EndSeasonRequest {
  final String endDate;
  const EndSeasonRequest({required this.endDate});
  Map<String, dynamic> toJson() => {'endDate': endDate};
}

class SeasonPlayersRequest {
  final List<int> playerIds;
  const SeasonPlayersRequest({required this.playerIds});
  Map<String, dynamic> toJson() => {'playerIds': playerIds};
}

class RegisterDeviceRequest {
  final String token;
  final String platform; // 'android' | 'ios'
  const RegisterDeviceRequest({required this.token, required this.platform});
  Map<String, dynamic> toJson() => {'token': token, 'platform': platform};
}

// ─── Coerce Helpers (match Kotlin CoerceIntAdapter / CoerceDoubleAdapter) ────

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return double.tryParse(value)?.toInt();
  return null;
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

List<T>? _parseList<T>(dynamic json, T Function(Map<String, dynamic>) fromJson) {
  if (json == null) return null;
  return (json as List<dynamic>)
      .map((e) => fromJson(e as Map<String, dynamic>))
      .toList();
}

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`tennis_pro` — a Flutter port of a Kotlin Android tennis ranking/tournament management app (Vietnamese UI). It talks to a backend at `https://hungsanity.com/tennis/api/` (see `TennisApiClient.baseUrl`) and supports auth, players, seasons, matches, rankings, local notifications, and a real-time SSE feed with polling fallback.

This is a **faithful port**: many `// Matches Kotlin ...kt` comments document the original source files. Preserve existing behavior unless explicitly asked to change it.

## Commands

All standard Flutter tooling. There is no Makefile, no Melos, no custom scripts.

- Install deps: `flutter pub get`
- Static analysis (uses `package:flutter_lints/flutter.yaml`): `flutter analyze`
- Run all tests: `flutter test`
- Run a single test file: `flutter test test/path/to/file_test.dart`
- Run a single test by name: `flutter test --plain-name "substring of test description"`
- Generate code (currently unused — see "Pubspec drift" below): `dart run build_runner build --delete-conflicting-outputs`
- Format: `dart format .`
- Run app (pick a device/simulator first): `flutter run -d <device-id>` or `flutter run` for default
- Build APK (matches the CI workflow in `.github/workflows/build-and-release.yml`):
  - Debug: `flutter build apk --debug`
  - Release: `flutter build apk --release`
- Web: `flutter run -d chrome` / `flutter build web`

The single existing test (`test/widget_test.dart`) is a placeholder; there is no real test infrastructure yet.

## Architecture

State is managed through a single `TennisRepository extends ChangeNotifier` that is constructed in `main.dart` and passed down to every screen. Screens register as listeners via `widget.repo.addListener(...)` and rebuild with `ListenableBuilder(listenable: widget.repo, ...)`. **This is intentionally a Riverpod-less design** — see "Pubspec drift" below.

### Layering

- `lib/main.dart` — entry point. Initializes the repo (loads tokens from secure storage), initializes `NotificationHelper`, then mounts `TennisProApp` → `MainAppShell`.
- `lib/api/tennis_api_client.dart` — `Dio` HTTP client. Two `Dio` instances: one for normal requests, one (`_sseDio`) with `receiveTimeout: Duration.zero` for the SSE event stream. Auth = `Authorization: Bearer <token>` + `X-CSRF-Token` + `cookie_jar` cookies. Public methods are 1:1 with backend endpoints (auth, init, players, seasons, matches, rankings, csrf-token, data-version, events).
- `lib/repository/tennis_repository.dart` — the only stateful class. Owns `_isAuthenticated`, `_currentUser`, `_csrfToken`, `_initData` (the big snapshot returned by `GET init`), loading/error flags, and theme override. All API calls go through `_safeApiCall`, which clears the session on 401 / CSRF 403. After every successful mutation it re-runs `fetchInitData()` so the whole UI reflects the new server state.
- `lib/models/tennis_models.dart` — hand-written `fromJson` / `toJson` for every model and request payload. Includes coerce helpers (`_toInt`, `_toDouble`, `_parseList`) that mirror the Kotlin `CoerceIntAdapter` / `CoerceDoubleAdapter`. The single big response is `InitResponse`, which carries players, seasons, rankings, default-date matches, auth state, and a `version` int used for change detection.
- `lib/utils/notification_helper.dart` — singleton wrapping `flutter_local_notifications`. Tracks `last_seen_match_id` / `last_seen_season_id` in secure storage and fires local notifications on first launch after a new match/season appears in the `InitResponse`.
- `lib/ui/theme/app_theme.dart` — Material 3 light/dark `ColorScheme` (hex values mirror the Kotlin `Theme.kt`), `Inter` font.
- `lib/ui/screens/` — `MainAppShell` switches between four tabs (Dashboard / BXH / Mùa giải / Người chơi) plus an overlay `LoginScreen`. Each tab screen is a `StatefulWidget` that:
  - subscribes to `repo` in `initState` and unsubscribes in `dispose`,
  - reads from `widget.repo.initData` for cached data,
  - calls `repo.fetchXxx()` for non-cached fetches,
  - gates write UI on `repo.currentUser?.role == 'admin' || 'editor'`.
- `lib/ui/widgets/shared_widgets.dart` — `ScreenHeader` (icon + title + login/logout button + theme toggle) and `AdminLoginBanner`. Note: the dashboard renders its own header inline rather than using `ScreenHeader` — be aware of the inconsistency before refactoring.

### Background sync (SSE + polling)

`TennisRepository.startBackgroundSync()` opens a long-lived GET on `events` (text/event-stream), debounces incoming `data:` lines to 2s, and re-fetches init data on each tick. A 15s `Timer.periodic` polls `GET data-version` and triggers a refetch when the version bumps — this is the fallback when SSE drops (the SSE loop auto-reconnects every 3s on disconnect). `MainAppShell.didChangeAppLifecycleState` pauses polling on `paused` and resumes on `resumed`.

### Auth flow

- `repository.initialize()` reads `bearer_token`, `csrf_token`, `user_json` from `FlutterSecureStorage` and configures the `Dio` client before the first request.
- `fetchInitData()` returns the full snapshot and is the canonical "refresh" call; the UI uses it to gate write access and to populate every screen.
- `LoginResponse.token` → `Authorization: Bearer`; `LoginResponse.csrfToken` → `X-CSRF-Token` header (only on the main `_dio`, not on `_sseDio`).

## Pubspec drift (important)

`pubspec.yaml` lists several packages that **are not actually used in the code today**. Don't add new code paths that depend on them until the project is migrated:

- `flutter_riverpod` — state management is `ChangeNotifier` + `ListenableBuilder`, not Riverpod providers.
- `go_router` — navigation is a hard-coded `NavigationBar` inside `MainAppShell`; `MaterialApp.home` points directly at the shell.
- `json_annotation` / `json_serializable` + `build_runner` (dev) — every model uses hand-written `fromJson`/`toJson`. If you switch to codegen, regenerate and remove the manual implementations.

If a future change wants to use these, the migration is its own task — don't half-adopt.

## Localization

All UI strings are hard-coded Vietnamese in widget builders. There is no `intl` `.arb` setup, no `gen-l10n` config. `package:intl` is used only for `DateFormat` and `NumberFormat` formatting. When changing copy, keep the existing Vietnamese tone; do not introduce English strings.

## Conventions

- File naming: `snake_case` for files, `PascalCase` for classes, `_camelCase` with leading underscore for private widgets (e.g. `_MatchCard`, `_RankingRow`) and private state classes.
- New screens extend `StatefulWidget` and accept `TennisRepository repo` + `VoidCallback onShowLogin` to match the existing four tabs.
- Always check `mounted` / `ctx.mounted` after `await` before calling `setState` or `Navigator.pop`.
- Admin/editor gating: `widget.repo.isAuthenticated && (widget.repo.currentUser?.role == 'admin' || widget.repo.currentUser?.role == 'editor')`. Viewer role is read-only.

## CI

`.github/workflows/build-and-release.yml` builds debug + release APKs on push/PR to `main` and tags `v*`, signs the release with secrets (`SIGNING_KEY_BASE64`, `KEY_ALIAS`, `KEY_STORE_PASSWORD`, `KEY_PASSWORD`), and uploads artifacts. JDK 17 + Flutter stable. There is no `flutter analyze` or `flutter test` step — adding one would be a reasonable improvement.

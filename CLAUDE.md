# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Debug build (fast iteration)
xcodebuild -project OpenClawMonitor.xcodeproj -scheme OpenClawMonitor -configuration Debug build

# Release build (ad-hoc signed, no sandbox)
xcodebuild -project OpenClawMonitor.xcodeproj -scheme OpenClawMonitor -configuration Release \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath .build build

# Package DMG (after release build)
mkdir -p dist/dmg
cp -R .build/Build/Products/Release/OpenClawMonitor.app dist/dmg/
create-dmg --volname "OpenClaw Monitor" --window-size 600 400 \
  --icon-size 100 --icon "OpenClawMonitor.app" 150 180 \
  --hide-extension "OpenClawMonitor.app" --app-drop-link 450 180 \
  "dist/OpenClawMonitor-1.0.dmg" "dist/dmg/"
```

There are no unit tests in this project.

## Adding a New Swift File

The `project.pbxproj` must be updated manually — Xcode does not auto-discover files. For each new `.swift` file, add four entries:

1. **PBXBuildFile** section — `<UUID> /* Foo.swift in Sources */ = {isa = PBXBuildFile; fileRef = <UUID2>; };`
2. **PBXFileReference** section — `<UUID2> /* Foo.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Foo.swift; sourceTree = "<group>"; };`
3. **PBXGroup** for the target folder — add `<UUID2> /* Foo.swift */,`
4. **PBXSourcesBuildPhase** — add `<UUID> /* Foo.swift in Sources */,`

Generate UUIDs with: `python3 -c "import secrets; print(secrets.token_hex(12).upper())"`

## Architecture

### Dual-Scene App

`OpenClawMonitorApp` declares three scenes simultaneously:
- `WindowGroup(id: "main")` — the main dashboard window
- `MenuBarExtra(.window style)` — always-visible menu bar icon + popover
- `Settings` — the Cmd+, preferences window

`AppDelegate.applicationShouldTerminateAfterLastWindowClosed` returns `false` so closing the window doesn't quit the app. The menu bar popover reopens the window via `openWindow(id: "main")` + `NSApp.activate`.

### State Flow

`AppViewModel` (`@MainActor`, `ObservableObject`) is the single source of truth. It is created as `@StateObject` in `OpenClawMonitorApp` and passed down via `.environmentObject()` to all scenes.

`loadData()` runs on app launch and decides between two modes:
- **Real mode**: `ConfigService` parses `~/.openclaw/openclaw.json` (or `$OPENCLAW_HOME/openclaw.json`), `FileWatcher` monitors the file for live reload, `StatsCollector` scans JSONL logs
- **Mock mode**: `MockData` is loaded and `isUsingMockData = true` shows the yellow Demo Mode banner

### Data Sources

| Data | Source |
|------|--------|
| Agents, Models, Config | `~/.openclaw/openclaw.json` via `ConfigService` |
| Agent runtime status | `AgentRuntime` structs (mock only; real polling via Gateway API planned) |
| Sessions, Skills, Alerts | Mock only for now |
| Statistics | `StatsCollector` scans `/tmp/openclaw/openclaw-YYYY-MM-DD.log` (JSONL) |
| Stats cache | `~/Library/Application Support/OpenClawMonitor/daily-stats.json` |

### Timers

Both timers are owned by `AppViewModel` and use `didSet` on their `@Published` interval properties to restart automatically when changed from Settings:
- **Refresh timer** (`refreshInterval`): calls `reload()` to re-parse config
- **Gateway poll timer** (`gatewayPollInterval`): calls `pollGateway()` which hits `http://localhost:{port}/api/health`

`StatsCollector` has its own 5-minute timer that re-scans only today's log file.

### Key Singletons

All are `@MainActor` and use `static let shared`:
- `ConfigService` — file parsing
- `NotificationService` — wraps `UNUserNotificationCenter`
- `StatsCollector` — log scanning + stats cache

### Alert Rules Engine

`AppViewModel.checkAlertRules()` runs after every gateway poll and reload. It checks:
1. Any `AgentRuntime` with `.offline` status → fires alert with deduplication via `UserDefaults` key `alert_active_agent_offline_{id}`
2. Gateway transitions to `.unhealthy` → `fireGatewayAlert()`; recovery → `resolveGatewayAlerts()`
3. Token anomaly: today's tokens > N% of historical average (threshold from `AppStorage("tokenAlertPercent")`)

### StatPoint Aggregation

`StatPoint` arrays have an `.aggregated(for: StatPeriod)` extension method (defined in `StatPoint.swift`) that handles daily (last 14), weekly (last 12 weeks), and monthly (last 12 months) grouping. `StatisticsView` calls this before passing points to the chart sub-views.

## UI Conventions

- Default color scheme: **Dark Mode** (`.preferredColorScheme(.dark)` on all scenes)
- Cards use `.regularMaterial` background with `RoundedRectangle(cornerRadius: 12)`
- Status dots (`StatusDot`) pulse when `.online` via `scaleEffect` + shadow animation
- No third-party UI frameworks — SwiftUI + Swift Charts only
- `@AppStorage` keys for settings: `colorSchemePreference`, `notificationsEnabled`, `agentOfflineThreshold`, `responseTimeoutSec`, `tokenAlertPercent`, `menuBarBadgeEnabled`, `autoRefreshInterval`, `gatewayPollInterval`

# OpenClaw Monitor

A native macOS menu bar app for monitoring your [OpenClaw](https://github.com/xmanrui/OpenClaw-bot-review) agent cluster — built with SwiftUI, zero dependencies.

## Features

- **Menu bar always-on** — quick status at a glance without opening the main window
- **Agent overview** — status cards for every agent with live connectivity testing
- **Model catalog** — sortable table of all configured LLM providers and models
- **Session management** — view active DM / group / cron sessions across all platforms
- **Statistics** — daily / weekly / monthly charts powered by Swift Charts, sourced from real OpenClaw JSONL logs
- **Alert center** — rule-based alerts (agent offline, gateway disconnect, token anomaly) with macOS system notifications
- **Skills browser** — searchable list of all installed builtin / extended / custom skills
- **Gateway control** — restart, stop, diagnose from within the app (no terminal needed)
- **Demo Mode** — runs fully with built-in mock data when no OpenClaw config is found

## Requirements

- macOS 14 Sonoma or later
- Xcode 15+ (to build from source)
- [OpenClaw](https://github.com/xmanrui/OpenClaw-bot-review) installed locally (optional — app runs in Demo Mode without it)

## Installation

### Build from source

```bash
git clone https://github.com/hveraus/OpenClawMonitor.git
cd OpenClawMonitor
xcodebuild -project OpenClawMonitor.xcodeproj -scheme OpenClawMonitor -configuration Debug build
```

Then open the built `.app` from `~/Library/Developer/Xcode/DerivedData/`.

Or open `OpenClawMonitor.xcodeproj` in Xcode and press **⌘R**.

## Configuration

The app reads your OpenClaw config automatically. Resolution order:

1. `$OPENCLAW_HOME/openclaw.json`
2. `~/.openclaw/openclaw.json`
3. No config found → **Demo Mode** (built-in sample data, yellow banner shown)

No setup needed if OpenClaw is already installed in the default location.

## Screenshots

> Coming soon

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI (macOS 14+) |
| Charts | Swift Charts |
| Persistence | UserDefaults + local JSON cache |
| Notifications | UNUserNotificationCenter |
| Login Item | SMAppService |
| File watching | DispatchSource |

No third-party libraries or package dependencies.

## Project Structure

```
OpenClawMonitor/
├── App/                   # Entry point, AppDelegate
├── Models/                # Codable data structs (config, sessions, alerts, stats)
├── Services/              # ConfigService, StatsCollector, NotificationService, FileWatcher
├── ViewModels/            # AppViewModel — single source of truth for all scenes
├── Views/
│   ├── Main/              # NavigationSplitView layout + sidebar
│   ├── MenuBar/           # Menu bar popover
│   ├── Pages/             # One file per sidebar page
│   ├── Components/        # Reusable views (AgentCard, StatusDot, PlatformBadge…)
│   └── Settings/          # Settings window (General, Alerts, About tabs)
└── Resources/             # MockData, Assets
```

## License

MIT

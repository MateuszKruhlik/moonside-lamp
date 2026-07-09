# Changelog

All notable changes to MoonsideBar are documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [SemVer](https://semver.org/).

## [1.0.0] — 2026-07-08

First public release.

### Added
- **BLE control for Moonside Lamp One** — Nordic UART Service (NUS), ON/OFF, brightness (0–120), custom RGB with hex input and color grid
- **20 built-in themes** — Flat Color plus 19 animated themes (BEAT, WAVE, GRADIENT, RAINBOW, FIRE, LAVA, TWINKLE, …) with customizable colors
- **AI agent integration** — the lamp acts as a physical status light for Claude Code (orange), Codex (purple), and Antigravity/Gemini (blue): BEAT2 pulse while processing, LAVA1 glow when waiting for input, warm white when idle
- **One-click setup wizard** — installs Claude Code hooks, Codex hooks, or Gemini `GEMINI.md` instructions automatically
- **Multi-session aggregation** — concurrent sessions of the same agent write per-session buckets; the lamp always shows the highest-priority state (`input > working > idle > off`), so a finishing tab never resets the lamp while another is still working
- **Frosted-glass side panel** — Notification Center-style NSPanel sliding from the right edge
- **Auto-reconnect** — saved device UUID for instant reconnect, exponential backoff, sleep/wake recovery
- **Agentic / Manual mode** — hooks drive the lamp, or take direct control (hooks are ignored in Manual mode; manual power-off is always respected)
- **Sleep prevention** while an agent is processing
- **Launch at Login** and persistent settings
- **"How it works" info window** explaining states, colors, and the file protocol

### Fixed
- Bluetooth entitlement (`com.apple.security.device.bluetooth`) embedded in the hardened-runtime Release build, so the standalone app can use CoreBluetooth outside Xcode
- Codex legend swatch color in the How It Works window (green → purple)
- **Setup wizard no longer overwrites existing Claude Code hooks** — moonside entries are merged per event into `~/.claude/settings.json` (appended to each event's array, duplicates skipped) instead of replacing the whole `hooks` key
- **Reconnect via saved device UUID can no longer dead-end** — the connect attempt gets a 10 s timeout with fallback to a normal scan, and a saved UUID that fails 3 times in a row is forgotten (re-saved on the next successful connect)
- **Sleep prevention watchdog** — if an agent crashes without its Stop/SessionEnd hook firing, the idle-sleep assertion is now released once no working agent's state file has changed for 30 minutes (checked every 60 s), so the Mac can sleep again
- **Offline command queue is bounded** — while disconnected only the last command per type (power/brightness/color/theme) is kept, and the replay after reconnect is staggered instead of bursting the lamp's BLE buffer
- **State-file monitor survives failed re-watch** — if re-opening a state file after delete/rename fails, the file is recreated and the watch retried instead of silently dying
- App icon: 256@2x and 512@2x slots contained 360×360 images; regenerated at proper 512/1024 px

### Known Issues
- **Offline replay is compacted, not eliminated** — after a reconnect the app still replays the last queued command per type, so the lamp may briefly re-apply a state from before the disconnect
- **Codex "Stop" maps to the input (attention) state** — Codex exposes no reliable "waiting for input" event, so a finished Codex turn shows the purple attention glow rather than idle; a genuinely idle Codex session can look like it needs you
- **Codex `config.toml` check can false-positive** — the wizard only checks that the file mentions `codex_hooks` and `true` somewhere, so e.g. a commented-out line can make the step pass without hooks actually enabled
- **No uninstaller** — the wizard has no uninstall path; to remove the integration, delete the moonside entries from `~/.claude/settings.json`, `~/.codex/hooks.json`, the moonside section from `~/.gemini/GEMINI.md`, and the `~/.claude/moonside_hooks/` directory
- **Sleep watchdog trade-off** — a single tool call running longer than 30 minutes without any hook activity stops holding the sleep assertion, so the Mac may sleep mid-task in that (rare) case

[1.0.0]: https://github.com/MateuszKruhlik/moonside-lamp/releases/tag/v1.0.0

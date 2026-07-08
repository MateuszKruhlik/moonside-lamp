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

[1.0.0]: https://github.com/matikkutik/moonside-bar/releases/tag/v1.0.0

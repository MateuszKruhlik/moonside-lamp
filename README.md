# MoonsideBar

Native macOS menu bar app for controlling the **Moonside Lamp One** via Bluetooth Low Energy.

Built as a companion for AI coding agents — the lamp changes color based on agent status (working, waiting for input, idle). Also works as a standalone lamp controller with 20 animated themes.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License MIT](https://img.shields.io/badge/license-MIT-green)
![AI Agents](https://img.shields.io/badge/AI%20Agents-3-blueviolet)

<!-- Screenshot placeholder: add screenshots/hero.png showing the side panel + lamp -->

## Features

- **Monocle-Style Side Panel** — frosted glass UI sliding from the right edge, inspired by macOS Notification Center
- **BLE Control** — ON/OFF, brightness (0–120), custom RGB color
- **20 Built-in Themes** — Flat Color, BEAT, WAVE, GRADIENT, RAINBOW, FIRE, LAVA, TWINKLE, and more
- **AI Agent Integration** — watches `/tmp/moonside_state` for status changes from Claude Code, Codex, Antigravity, or any tool
- **One-Click Setup Wizard** — configures Claude Code hooks, Codex hooks, or Gemini CLI instructions automatically
- **Sleep Prevention** — prevents macOS from sleeping while an agent is actively processing
- **Auto / Manual Mode** — in Agentic mode, agent hooks control the lamp; switch to Manual to override
- **Connection Status** — menu bar icon reflects BLE connection state
- **Auto-Reconnect** — exponential backoff retry + sleep/wake reconnect
- **Launch at Login** — optional, via system Settings
- **Persists Settings** — brightness, color, and mode survive restarts

## Requirements

- macOS 14.0 (Sonoma) or later
- Moonside Lamp One (`MOONSIDE-O101`)
- Bluetooth enabled

## Quick Start

1. Build and launch MoonsideBar (see [Build from Source](#build-from-source))
2. Allow Bluetooth when macOS asks — the app finds your lamp automatically
3. Find the **Claude Code**, **Codex**, or **Antigravity** card and click **Setup**

That's it. The lamp now reacts to your AI agent in real time.

## AI Agent Integration

### Supported Agents

| Agent | Color | Setup Method |
|-------|-------|-------------|
| **Claude Code** | Orange | Hook script + `settings.json` hooks |
| **Codex** (OpenAI) | Purple | Hook script + `hooks.json` + `config.toml` |
| **Antigravity** (Gemini) | Blue | Lamp instructions in `GEMINI.md` |

### One-Click Setup

Click **Setup** on any agent card. The wizard handles everything:

- **Claude Code** — installs `~/.claude/moonside_hooks/moonside_hook.sh` and merges hook configuration into `~/.claude/settings.json`. Every agent event (start, stop, waiting) triggers the lamp.
- **Codex** — installs `~/.claude/moonside_hooks/moonside_codex_hook.sh`, enables hooks in `~/.codex/config.toml`, and creates `~/.codex/hooks.json`. Codex events trigger the lamp via the hook system.
- **Antigravity** — appends lamp instructions to `~/.gemini/GEMINI.md`. Gemini reads these as system context and calls the hook script when asking you a question.

**Prerequisite:** Have the CLI tool installed first (Claude Code, Codex, or Gemini CLI). The wizard checks and tells you if it's missing.

### Lamp States

| State | File Content | Lamp Effect | When |
|-------|-------------|-------------|------|
| Idle | `idle` | Warm white solid | Agent ready, no active task |
| Working (Claude) | `working` | Orange BEAT2 pulse | Claude Code is processing |
| Working (Codex) | `working_cx` | Purple BEAT2 pulse | Codex is processing |
| Working (Gemini) | `working_ag` | Blue BEAT2 pulse | Antigravity is processing |
| Input (Claude) | `input_cc` | Orange LAVA1 glow | Claude Code needs your input |
| Input (Codex) | `input_cx` | Purple LAVA1 glow | Codex needs your input |
| Input (Gemini) | `input_ag` | Blue LAVA1 glow | Antigravity needs your input |
| Off | `off` | LED off | Session ended |

### Sleep Prevention

When an agent is actively processing (any `working` state), MoonsideBar prevents macOS from going to idle sleep. This keeps the BLE connection alive and the lamp feedback visible. The assertion is released as soon as the agent finishes or the lamp is turned off.

### Manual Mode

Switch to Manual to take full control:

- Pick any color from the grid or type a hex code
- Slide through 20 themes with animated light effects
- Adjust brightness from 0 to 120
- Customize theme colors with the color editor

In Manual mode, agent hooks are ignored — the lamp stays exactly as you set it.

### Custom Integration

Any tool can control the lamp by writing to `/tmp/moonside_state`:

```bash
printf 'working' > /tmp/moonside_state
```

MoonsideBar watches this file and reacts immediately. See the state table above for valid values.

## Build from Source

```bash
# Clone
git clone https://github.com/MateuszKruhlik/moonside-lamp.git
cd moonside-lamp

# Generate Xcode project (requires xcodegen)
brew install xcodegen
xcodegen generate

# Build
xcodebuild -scheme MoonsideBar -configuration Release build
```

Or open `MoonsideBar.xcodeproj` in Xcode and press Run.

## BLE Protocol

Moonside Lamp One uses Nordic UART Service (NUS) with ASCII commands:

| Command | Format | Example |
|---------|--------|---------|
| LED on/off | `LEDON` / `LEDOFF` | `LEDOFF` |
| Color | `COLORRRRGGGBBB` | `COLOR255140000` |
| Brightness | `BRIGHBBB` (0–120) | `BRIGH060` |
| Theme | `THEME.NAME.R,G,B,R,G,B,` | `THEME.BEAT2.255,255,255,0,0,140,` |

## Credits

### Special thanks

[**bobek-balinek/claude-lamp**](https://github.com/bobek-balinek/claude-lamp) — the original proof of concept that made this project possible. It cracked the BLE connection to Moonside Lamp One, figured out the Nordic UART command structure, and proved the core idea works. MoonsideBar is built on that foundation — the native macOS app, the multi-agent integration, and all the UI came after.

### Also

- BLE protocol reverse engineering: [TheGreyDiamond](https://thegreydiamond.de/blog/2022/10/10/reverse-engineering-moonside-lighthouse/)
- UI inspiration: [MacControlCenterUI](https://github.com/orchetect/MacControlCenterUI) by orchetect

## License

MIT — see [LICENSE](LICENSE).

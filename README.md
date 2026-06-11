# MoonsideBar

> **Native macOS menu bar app for the Moonside Lamp One**
> Built as a physical status indicator for AI coding agents. Also a really nice standalone lamp controller.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![BLE](https://img.shields.io/badge/transport-BLE%20NUS-purple)
![Agents](https://img.shields.io/badge/agents-3-blueviolet)
![License MIT](https://img.shields.io/badge/license-MIT-green)

---

## The Idea

Your Moonside lamp becomes the **out-of-screen status light** for whichever AI agent you're using. Orange pulse while Claude is working, purple while Codex is working, blue while Gemini is working, warm glow when anyone needs your input, solid white when idle. Works with three agents out of the box; extensible to anything that can write a file.

---

## Features

- **Monocle-style side panel** — frosted glass, slides from the right edge (Notification Center-inspired)
- **BLE control** — ON/OFF, brightness (0–120), custom RGB
- **20 built-in themes** — Flat, BEAT, WAVE, GRADIENT, RAINBOW, FIRE, LAVA, TWINKLE, …
- **AI agent integration** — watches `/tmp/moonside_state` and reacts in real time
- **One-click setup wizard** — Claude Code hooks, Codex hooks, or Gemini `GEMINI.md` instructions, installed automatically
- **Sleep prevention** — blocks idle sleep while an agent is processing (keeps BLE alive, keeps feedback visible)
- **Auto / Manual mode** — Agentic hooks drive the lamp, or override for direct control
- **Auto-reconnect** — exponential backoff + sleep/wake recovery
- **Launch at Login** + persistent settings

---

## Agents

| Agent | Color | Setup |
|:------|:------|:------|
| **Claude Code** | 🟠 Orange | Hook script + merge into `~/.claude/settings.json` |
| **Codex** (OpenAI) | 🟣 Purple | Hook script + `~/.codex/config.toml` + `hooks.json` |
| **Antigravity** (Gemini) | 🔵 Blue | Lamp instructions appended to `~/.gemini/GEMINI.md` |

**Prerequisite:** Have the CLI tool installed first. The wizard checks and tells you what's missing.

---

## Lamp States

| State | File content | Effect | When |
|:------|:-------------|:-------|:-----|
| Idle | `idle` | Warm white solid | Agent ready |
| Working (Claude) | `working` | Orange BEAT2 pulse | Claude processing |
| Working (Codex) | `working_cx` | Purple BEAT2 pulse | Codex processing |
| Working (Gemini) | `working_ag` | Blue BEAT2 pulse | Antigravity processing |
| Input (Claude) | `input_cc` | Orange LAVA1 glow | Claude needs input |
| Input (Codex) | `input_cx` | Purple LAVA1 glow | Codex needs input |
| Input (Gemini) | `input_ag` | Blue LAVA1 glow | Antigravity needs input |
| Off | `off` | LED off | Session ended |

---

## Requirements

| Requirement | Detail |
|:------------|:-------|
| macOS | 14.0 (Sonoma) or later |
| Lamp | Moonside Lamp One (`MOONSIDE-O101`) |
| Bluetooth | Enabled |

---

## Quick Start

1. Build and launch MoonsideBar (see [Build from source](#build-from-source))
2. Allow Bluetooth when macOS asks — the app finds your lamp automatically
3. Pick your agent card → click **Setup**

The lamp now reacts in real time.

---

## Manual Mode

- Hex input or color grid
- 20 animated themes with custom color editing
- Brightness 0–120
- Agent hooks are **ignored** in Manual mode — the lamp stays exactly as you set it

---

## Custom Integration

Any tool can drive the lamp by writing to `/tmp/moonside_state`:

```bash
printf 'working' > /tmp/moonside_state
printf 'input_cc' > /tmp/moonside_state
printf 'off' > /tmp/moonside_state
```

MoonsideBar watches the file and reacts immediately. Valid values are in the state table above.

---

## Build from Source

```bash
git clone https://github.com/MateuszKruhlik/moonside-lamp.git
cd moonside-lamp

# Requires xcodegen
brew install xcodegen
xcodegen generate

# Build
xcodebuild -scheme MoonsideBar -configuration Release build
```

Or just open `MoonsideBar.xcodeproj` in Xcode and press Run.

---

## BLE Protocol

Moonside Lamp One uses the **Nordic UART Service (NUS)** with ASCII commands:

| Command | Format | Example |
|:--------|:-------|:--------|
| LED on/off | `LEDON` / `LEDOFF` | `LEDOFF` |
| Color | `COLORRRRGGGBBB` | `COLOR255140000` |
| Brightness | `BRIGHBBB` (0–120) | `BRIGH060` |
| Theme | `THEME.NAME.R,G,B,…` | `THEME.BEAT2.255,255,255,0,0,140,` |

---

## Directory Structure

```
MoonsideBar/
├── MoonsideBar/                  # Swift app sources
│   ├── MoonsideBarApp.swift      # Entry point
│   ├── AppState.swift            # Observable app state
│   ├── BluetoothManager.swift    # BLE connection + reconnect
│   ├── StateFileMonitor.swift    # /tmp/moonside_state watcher
│   ├── MenuBarView.swift         # Status-bar popover
│   ├── SidePanelController.swift # Frosted-glass side panel
│   ├── SetupWizardView.swift     # One-click agent setup
│   └── HowItWorksView.swift
├── icons/                        # App icons
├── project.yml                   # xcodegen spec
└── MoonsideBar.xcodeproj         # Generated
```

---

## Credits

**Special thanks** — [`bobek-balinek/claude-lamp`](https://github.com/bobek-balinek/claude-lamp), the original proof of concept that cracked the BLE connection and figured out the Nordic UART command structure. MoonsideBar is built on that foundation — the native macOS app, multi-agent integration, and UI came after.

Also:
- BLE reverse engineering — [TheGreyDiamond](https://thegreydiamond.de/blog/2022/10/10/reverse-engineering-moonside-lighthouse/)
- UI inspiration — [`MacControlCenterUI`](https://github.com/orchetect/MacControlCenterUI) by orchetect

---

## License

MIT. See [LICENSE](LICENSE).

Built by [Mateusz Kruhlik](https://rabituza.studio) · Rabituza Studio

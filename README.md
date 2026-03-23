# MoonsideBar

Native macOS menu bar app for controlling the **Moonside Lamp One** via Bluetooth Low Energy.

Built as a companion for AI coding agents — the lamp changes color based on agent status (working, waiting for input, idle). Also works as a standalone lamp controller.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License MIT](https://img.shields.io/badge/license-MIT-green)

## Features

- **BLE Control** — ON/OFF, brightness (0–120), custom RGB color
- **19 Built-in Themes** — BEAT, WAVE, GRADIENT, RAINBOW, FIRE, LAVA, TWINKLE, and more
- **AI Agent Integration** — watches `/tmp/moonside_state` for status changes from Claude Code, Antigravity, or any tool that writes to the state file
- **Auto / Manual Mode** — in Auto mode, agent hooks control the lamp; switch to Manual to override
- **Connection Status** — menu bar icon reflects BLE connection state
- **Auto-Reconnect** — exponential backoff retry + sleep/wake reconnect
- **Launch at Login** — optional, via system Settings
- **Persists Settings** — brightness, color, and mode survive restarts

## Requirements

- macOS 14.0 (Sonoma) or later
- Moonside Lamp One (`MOONSIDE-O101`)
- Bluetooth enabled

## Installation

### Build from Source

```bash
# Clone
git clone https://github.com/your-username/MoonsideBar.git
cd MoonsideBar

# Generate Xcode project (requires xcodegen)
brew install xcodegen
xcodegen generate

# Build
xcodebuild -scheme MoonsideBar -configuration Release build
```

Or open `MoonsideBar.xcodeproj` in Xcode and press Run.

## AI Agent Integration

MoonsideBar watches the file `/tmp/moonside_state` for state changes. Write one of these values to trigger a lamp change:

| State | File Content | Lamp Effect |
|-------|-------------|-------------|
| Idle | `idle` | Warm white solid |
| Working | `working` | White + navy BEAT2 drift |
| Claude Code Input | `input_cc` | Orange + amber BEAT2 drift |
| Antigravity Input | `input_ag` | Blue + deep blue BEAT2 drift |
| Off | `off` | LED off |

Example hook (used by Claude Code):
```bash
printf 'input_cc' > /tmp/moonside_state
```

## BLE Protocol

Moonside Lamp One uses Nordic UART Service (NUS) with ASCII commands:

| Command | Format | Example |
|---------|--------|---------|
| LED on/off | `LEDON` / `LEDOFF` | `LEDOFF` |
| Color | `COLORRRRGGGBBB` | `COLOR255140000` |
| Brightness | `BRIGHBBB` (0–120) | `BRIGH060` |
| Theme | `THEME.NAME.R,G,B,R,G,B,` | `THEME.BEAT2.255,255,255,0,0,140,` |

## Credits

- BLE protocol reverse engineering: [TheGreyDiamond](https://thegreydiamond.de/blog/2022/10/10/reverse-engineering-moonside-lighthouse/)
- Original Claude lamp concept: [bobek-balinek/claude-lamp](https://github.com/bobek-balinek/claude-lamp)
- UI: [MacControlCenterUI](https://github.com/orchetect/MacControlCenterUI) by orchetect

## License

MIT — see [LICENSE](LICENSE).

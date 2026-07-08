# MoonsideBar v1.0.0

Native macOS menu bar app for the **Moonside Lamp One** — your lamp becomes an out-of-screen status light for AI coding agents (Claude Code 🟠, Codex 🟣, Antigravity/Gemini 🔵), and a really nice standalone lamp controller.

## Highlights

- **BLE lamp control** — ON/OFF, brightness, custom colors, 20 themes
- **Agent status light** — pulse while your agent works, glow when it needs you, warm white when idle
- **One-click setup wizard** for Claude Code, Codex, and Gemini
- **Multi-session aware** — several agent tabs at once never fight over the lamp
- **Frosted-glass side panel**, auto-reconnect, Launch at Login

## Requirements

| | |
|:--|:--|
| macOS | 14.0 (Sonoma) or later |
| Mac | Apple Silicon (arm64 build) |
| Lamp | Moonside Lamp One (`MOONSIDE-O101`) |
| Bluetooth | Enabled |

Intel Macs: build from source (see README) — the prebuilt binary is arm64-only.

## Install (unsigned build — read this!)

This build is **not notarized** (no Apple Developer account — it's a free, open-source app). macOS Gatekeeper will warn you on first launch. That's expected:

1. Download `MoonsideBar-v1.0.0.zip` below and unzip it
2. Move `MoonsideBar.app` to `/Applications`
3. **Right-click (or Ctrl-click) the app → Open → Open** on the first launch
   - On macOS 15+ you may instead need: **System Settings → Privacy & Security → scroll down → "Open Anyway"**
4. Allow Bluetooth access when macOS asks
5. The app finds your lamp automatically — then pick an agent card and click **Setup**

If you prefer, you can always build from source: `brew install xcodegen && xcodegen generate && xcodebuild -scheme MoonsideBar -configuration Release build`.

## Checksums

```
shasum -a 256 MoonsideBar-v1.0.0.zip
5bf3d09b7f5966e6dd25134521da6ad9ae889c9172f583db1c648d46159d738e
```

## Credits

Built on the BLE groundwork of [bobek-balinek/claude-lamp](https://github.com/bobek-balinek/claude-lamp) and [TheGreyDiamond's reverse engineering](https://thegreydiamond.de/blog/2022/10/10/reverse-engineering-moonside-lighthouse/). MIT licensed.

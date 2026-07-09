# Contributing to MoonsideBar

Thanks for your interest! MoonsideBar is a small, focused app — contributions are welcome, especially around new agent integrations, lamp models, and reliability.

## Getting started

```bash
git clone https://github.com/MateuszKruhlik/moonside-lamp.git
cd moonside-bar
brew install xcodegen
xcodegen generate
open MoonsideBar.xcodeproj
```

Requirements: macOS 14+, Xcode 16+, a Moonside Lamp One for end-to-end testing (BLE code paths can be reviewed without one, but please say so in your PR).

## Workflow

1. Fork the repo and create a branch from `main` (`feat/…`, `fix/…`).
2. Make your change. Keep PRs small and single-purpose.
3. Build the Release configuration before submitting:
   `xcodebuild -scheme MoonsideBar -configuration Release build`
4. Open a PR describing **what** changed and **how you tested it** (with or without a physical lamp).

## Code style

- Swift 5.9, SwiftUI + `@Observable` where possible
- Follow the existing file layout (one view/manager per file)
- Comments and identifiers in English
- No new dependencies without prior discussion in an issue

## Reporting bugs

Open an issue with: macOS version, lamp model, what you did, what happened, and Console.app output for `MoonsideBar` if relevant.

## License

By contributing you agree that your contributions are licensed under the [MIT License](LICENSE).

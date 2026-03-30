import Defaults
import Foundation
import LaunchAtLogin
import Observation
import SwiftUI

// MARK: - Enums

enum ControlMode: String, CaseIterable, Defaults.Serializable {
    case agenticLighting
    case manual
}

enum LampState: String, Defaults.Serializable {
    case idle
    case working
    case workingAG = "working_ag"
    case workingCX = "working_cx"
    case inputCC = "input_cc"
    case inputAG = "input_ag"
    case inputCX = "input_cx"
    case off
}

enum ConnectionStatus: String {
    case disconnected
    case connecting
    case connected
    case unauthorized
}

enum AgentType: String {
    case claudeCode
    case antigravity
    case codex
}

// MARK: - BLE Commands

enum BLECommand {
    static let ledOn = "LEDON"
    static let ledOff = "LEDOFF"

    static func brightness(_ value: Int) -> String {
        String(format: "BRIGH%03d", value)
    }

    static func color(_ r: Int, _ g: Int, _ b: Int) -> String {
        String(format: "COLOR%03d%03d%03d", r, g, b)
    }

    static func theme(_ id: String, _ r1: Int, _ g1: Int, _ b1: Int,
                      _ r2: Int, _ g2: Int, _ b2: Int) -> String {
        "THEME.\(id).\(r1),\(g1),\(b1),\(r2),\(g2),\(b2),"
    }
}

// MARK: - Moonside Themes

struct MoonsideTheme: Identifiable, Hashable {
    let id: String
    let name: String
    let baseColors: (r1: Int, g1: Int, b1: Int, r2: Int, g2: Int, b2: Int)
    let previewColor1: Color
    let previewColor2: Color

    var isFlat: Bool { id == "FLAT" }

    var command: String {
        if isFlat {
            return BLECommand.color(baseColors.r1, baseColors.g1, baseColors.b1)
        }
        return "THEME.\(id).\(baseColors.r1),\(baseColors.g1),\(baseColors.b1),\(baseColors.r2),\(baseColors.g2),\(baseColors.b2),"
    }

    func commandWith(color1: Color, color2: Color) -> String {
        let c1 = color1.rgbComponents
        if isFlat {
            return BLECommand.color(c1.r, c1.g, c1.b)
        }
        let c2 = color2.rgbComponents
        return "THEME.\(id).\(c1.r),\(c1.g),\(c1.b),\(c2.r),\(c2.g),\(c2.b),"
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: MoonsideTheme, rhs: MoonsideTheme) -> Bool { lhs.id == rhs.id }
}

extension Color {
    init(r: Int, g: Int, b: Int) {
        self.init(red: Double(r) / 255.0, green: Double(g) / 255.0, blue: Double(b) / 255.0)
    }

    var rgbComponents: (r: Int, g: Int, b: Int) {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        return (
            r: Int((nsColor.redComponent * 255).rounded()),
            g: Int((nsColor.greenComponent * 255).rounded()),
            b: Int((nsColor.blueComponent * 255).rounded())
        )
    }

    var hexString: String {
        let rgb = rgbComponents
        return String(format: "#%02X%02X%02X", rgb.r, rgb.g, rgb.b)
    }

    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        guard hexSanitized.count == 6,
              let hexNumber = UInt64(hexSanitized, radix: 16) else { return nil }
        let r = Double((hexNumber & 0xFF0000) >> 16) / 255.0
        let g = Double((hexNumber & 0x00FF00) >> 8) / 255.0
        let b = Double(hexNumber & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

extension MoonsideTheme {
    static let all: [MoonsideTheme] = [
        MoonsideTheme(id: "FLAT", name: "Flat Color",
                       baseColors: (255, 230, 200, 255, 230, 200),
                       previewColor1: Color(r: 255, g: 230, b: 200), previewColor2: Color(r: 255, g: 230, b: 200)),
        MoonsideTheme(id: "THEME1", name: "Warm Sunset",
                       baseColors: (255, 100, 0, 255, 50, 0),
                       previewColor1: .orange, previewColor2: .red),
        MoonsideTheme(id: "THEME2", name: "Cool Ocean",
                       baseColors: (0, 100, 255, 0, 200, 255),
                       previewColor1: .blue, previewColor2: .cyan),
        MoonsideTheme(id: "THEME3", name: "Forest",
                       baseColors: (0, 200, 50, 50, 255, 100),
                       previewColor1: .green, previewColor2: .mint),
        MoonsideTheme(id: "THEME4", name: "Lavender",
                       baseColors: (180, 100, 255, 255, 100, 200),
                       previewColor1: .purple, previewColor2: .pink),
        MoonsideTheme(id: "THEME5", name: "Fireplace",
                       baseColors: (255, 80, 0, 255, 40, 0),
                       previewColor1: .red, previewColor2: .orange),
        MoonsideTheme(id: "WAVE1", name: "Pink Ball",
                       baseColors: (255, 100, 200, 100, 0, 150),
                       previewColor1: .pink, previewColor2: .purple),
        MoonsideTheme(id: "BEAT1", name: "Dancing Beat",
                       baseColors: (255, 255, 255, 100, 100, 100),
                       previewColor1: .white, previewColor2: .gray),
        MoonsideTheme(id: "BEAT2", name: "Bouncing Stars",
                       baseColors: (255, 255, 255, 0, 0, 140),
                       previewColor1: .white, previewColor2: Color(red: 0, green: 0, blue: 0.55)),
        MoonsideTheme(id: "BEAT3", name: "Shining Beat",
                       baseColors: (255, 100, 200, 150, 0, 255),
                       previewColor1: .pink, previewColor2: .purple),
        MoonsideTheme(id: "GRADIENT1", name: "Green Land",
                       baseColors: (0, 200, 50, 50, 255, 100),
                       previewColor1: .green, previewColor2: .mint),
        MoonsideTheme(id: "GRADIENT2", name: "Summer Glow",
                       baseColors: (255, 200, 50, 255, 100, 0),
                       previewColor1: .yellow, previewColor2: .orange),
        MoonsideTheme(id: "RAINBOW1", name: "Rainbow One",
                       baseColors: (255, 0, 0, 0, 0, 255),
                       previewColor1: .red, previewColor2: .blue),
        MoonsideTheme(id: "RAINBOW2", name: "Rising Rainbow",
                       baseColors: (255, 100, 0, 100, 0, 255),
                       previewColor1: .orange, previewColor2: .purple),
        MoonsideTheme(id: "RAINBOW3", name: "Blending Rainbow",
                       baseColors: (0, 255, 0, 0, 0, 255),
                       previewColor1: .green, previewColor2: .blue),
        MoonsideTheme(id: "TWINKLE1", name: "Twinkle Star",
                       baseColors: (255, 200, 100, 100, 50, 0),
                       previewColor1: .white, previewColor2: .yellow),
        MoonsideTheme(id: "FIRE2", name: "Night Fire",
                       baseColors: (255, 50, 0, 255, 150, 0),
                       previewColor1: .red, previewColor2: .orange),
        MoonsideTheme(id: "COLORDROP1", name: "Raining Blue",
                       baseColors: (0, 100, 255, 0, 50, 200),
                       previewColor1: .blue, previewColor2: Color(red: 0, green: 0.2, blue: 0.8)),
        MoonsideTheme(id: "LAVA1", name: "Blue Lava",
                       baseColors: (0, 50, 255, 0, 0, 100),
                       previewColor1: .blue, previewColor2: Color(red: 0, green: 0, blue: 0.4)),
        MoonsideTheme(id: "PULSING1", name: "Pulsing",
                       baseColors: (0, 100, 255, 30, 60, 180),
                       previewColor1: .blue, previewColor2: Color(red: 0.12, green: 0.24, blue: 0.7)),
    ]
}

// MARK: - Defaults Keys

extension Defaults.Keys {
    static let brightness = Key<Int>("brightness", default: 50)
    static let controlMode = Key<ControlMode>("controlMode", default: .agenticLighting)
    static let lastColorR = Key<Int>("lastColorR", default: 255)
    static let lastColorG = Key<Int>("lastColorG", default: 230)
    static let lastColorB = Key<Int>("lastColorB", default: 200)
    static let deviceUUID = Key<String>("deviceUUID", default: "")
    static let themeColor1R = Key<Int>("themeColor1R", default: 255)
    static let themeColor1G = Key<Int>("themeColor1G", default: 255)
    static let themeColor1B = Key<Int>("themeColor1B", default: 255)
    static let themeColor2R = Key<Int>("themeColor2R", default: 0)
    static let themeColor2G = Key<Int>("themeColor2G", default: 0)
    static let themeColor2B = Key<Int>("themeColor2B", default: 140)
    static let recentColorsHex = Key<[String]>("recentColorsHex", default: [])
}

// MARK: - Integration Status

struct IntegrationStatus {
    var claudeCodeActive: Bool = false
    var antigravityActive: Bool = false
    var codexActive: Bool = false
}

// MARK: - AppState

@Observable
final class AppState {
    var connectionStatus: ConnectionStatus = .disconnected
    var isLedOn: Bool = false
    var brightness: Int = Defaults[.brightness]
    var controlMode: ControlMode = Defaults[.controlMode]
    var currentState: LampState = .idle
    var customColor: Color = Color(
        red: Double(Defaults[.lastColorR]) / 255.0,
        green: Double(Defaults[.lastColorG]) / 255.0,
        blue: Double(Defaults[.lastColorB]) / 255.0
    )

    var selectedTheme: MoonsideTheme?
    var themeColor1: Color = Color(
        red: Double(Defaults[.themeColor1R]) / 255.0,
        green: Double(Defaults[.themeColor1G]) / 255.0,
        blue: Double(Defaults[.themeColor1B]) / 255.0
    )
    var themeColor2: Color = Color(
        red: Double(Defaults[.themeColor2R]) / 255.0,
        green: Double(Defaults[.themeColor2G]) / 255.0,
        blue: Double(Defaults[.themeColor2B]) / 255.0
    )

    var launchAtLogin: Bool = LaunchAtLogin.isEnabled
    var isMoreSettingsExpanded: Bool = false
    var integrationStatus = IntegrationStatus()
    var isTestingFlash: Bool = false
    private var flashWorkItem: DispatchWorkItem?
    var recentColors: [Color] = Defaults[.recentColorsHex].compactMap { Color(hex: $0) }

    var isConnected: Bool { connectionStatus == .connected }
    private var isManuallyOff: Bool = false
    private var sleepPreventionActivity: NSObjectProtocol?

    // Managers
    var bluetoothManager: BluetoothManager?
    private var stateFileMonitor: StateFileMonitor?

    func setup() {
        let btManager = BluetoothManager()
        btManager.onConnectionStatusChanged = { [weak self] status in
            guard let self else { return }
            self.connectionStatus = status
            if status == .connected {
                self.applyState(self.currentState)
            }
        }
        bluetoothManager = btManager

        let monitor = StateFileMonitor()
        monitor.onStateChange = { [weak self] state in
            guard let self else { return }
            guard self.controlMode == .agenticLighting else { return }
            // User manually turned off — ignore hooks until they turn it back on
            guard !self.isManuallyOff else { return }
            // Don't override if same state (avoids echo from our own writes)
            guard state != self.currentState else { return }
            self.applyState(state)
        }
        monitor.start()
        stateFileMonitor = monitor

        checkIntegrations()
    }

    func applyState(_ state: LampState) {
        currentState = state
        if state == .idle {
            // Return to user's chosen flat color at current brightness
            let rgb = themeColor1.rgbComponents
            bluetoothManager?.send(BLECommand.ledOn)
            bluetoothManager?.send(BLECommand.color(rgb.r, rgb.g, rgb.b))
            bluetoothManager?.send(BLECommand.brightness(brightness))
        } else {
            guard let commands = Self.stateCommands[state] else { return }
            for command in commands { bluetoothManager?.send(command) }
        }
        isLedOn = state != .off
        updateSleepPrevention(for: state)
    }

    func setBrightness(_ value: Int) {
        let clamped = max(0, min(120, value))
        brightness = clamped
        Defaults[.brightness] = clamped
        bluetoothManager?.send(BLECommand.brightness(clamped))
    }

    func setColor(_ color: Color) {
        customColor = color
        let rgb = color.rgbComponents
        Defaults[.lastColorR] = rgb.r
        Defaults[.lastColorG] = rgb.g
        Defaults[.lastColorB] = rgb.b
        bluetoothManager?.send(BLECommand.ledOn)
        bluetoothManager?.send(BLECommand.color(rgb.r, rgb.g, rgb.b))
        isLedOn = true
        addToRecentColors(color)
    }

    func setColorFromHex(_ hex: String) {
        guard let color = Color(hex: hex) else { return }
        setColor(color)
    }

    func addToRecentColors(_ color: Color) {
        let hex = color.hexString
        var recents = Defaults[.recentColorsHex]
        recents.removeAll { $0 == hex }
        recents.insert(hex, at: 0)
        if recents.count > 12 { recents = Array(recents.prefix(12)) }
        Defaults[.recentColorsHex] = recents
        recentColors = recents.compactMap { Color(hex: $0) }
    }

    func applyTheme(_ theme: MoonsideTheme) {
        selectedTheme = theme
        let bc = theme.baseColors
        themeColor1 = Color(r: bc.r1, g: bc.g1, b: bc.b1)
        themeColor2 = Color(r: bc.r2, g: bc.g2, b: bc.b2)
        persistThemeColors()
        bluetoothManager?.send(BLECommand.ledOn)
        bluetoothManager?.send(theme.command)
        isLedOn = true
    }

    func updateThemeColor1(_ color: Color) {
        themeColor1 = color
        persistThemeColors()
        sendCurrentThemeWithColors()
    }

    func updateThemeColor2(_ color: Color) {
        themeColor2 = color
        persistThemeColors()
        sendCurrentThemeWithColors()
    }

    func resetThemeColors() {
        guard let theme = selectedTheme else { return }
        let bc = theme.baseColors
        themeColor1 = Color(r: bc.r1, g: bc.g1, b: bc.b1)
        themeColor2 = Color(r: bc.r2, g: bc.g2, b: bc.b2)
        persistThemeColors()
        bluetoothManager?.send(BLECommand.ledOn)
        bluetoothManager?.send(theme.command)
        isLedOn = true
    }

    // Integration check with feedback
    var claudeCodeCheckMessage: String?
    var antigravityCheckMessage: String?
    var codexCheckMessage: String?

    func checkIntegrationWithFeedback(agent: AgentType) {
        switch agent {
        case .claudeCode:
            claudeCodeCheckMessage = "checking…"
        case .antigravity:
            antigravityCheckMessage = "checking…"
        case .codex:
            codexCheckMessage = "checking…"
        }

        checkIntegrations()

        let result: String
        switch agent {
        case .claudeCode:
            result = integrationStatus.claudeCodeActive ? "connected" : "not found"
            claudeCodeCheckMessage = result
        case .antigravity:
            result = integrationStatus.antigravityActive ? "connected" : "not found"
            antigravityCheckMessage = result
        case .codex:
            result = integrationStatus.codexActive ? "connected" : "not found"
            codexCheckMessage = result
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self else { return }
            switch agent {
            case .claudeCode: self.claudeCodeCheckMessage = nil
            case .antigravity: self.antigravityCheckMessage = nil
            case .codex: self.codexCheckMessage = nil
            }
        }
    }

    func toggleLed() {
        isLedOn.toggle()
        bluetoothManager?.send(isLedOn ? BLECommand.ledOn : BLECommand.ledOff)
        if isLedOn {
            isManuallyOff = false
            applyState(.idle)
        } else {
            isManuallyOff = true
            currentState = .off
            updateSleepPrevention(for: .off)
            try? "off".write(toFile: "/tmp/moonside_state", atomically: true, encoding: .utf8)
        }
    }

    func setControlMode(_ mode: ControlMode) {
        controlMode = mode
        Defaults[.controlMode] = mode
    }

    func toggleLaunchAtLogin() {
        launchAtLogin.toggle()
        LaunchAtLogin.isEnabled = launchAtLogin
    }

    // MARK: - Integration Check

    func checkIntegrations() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        // Claude Code: check if moonside hook exists in settings.json
        let settingsPath = homeDir + "/.claude/settings.json"
        if let data = FileManager.default.contents(atPath: settingsPath),
           let text = String(data: data, encoding: .utf8) {
            integrationStatus.claudeCodeActive = text.contains("moonside")
        } else {
            integrationStatus.claudeCodeActive = false
        }

        // Antigravity: check if GEMINI.md mentions moonside
        let geminiPath = homeDir + "/.gemini/GEMINI.md"
        if let data = FileManager.default.contents(atPath: geminiPath),
           let text = String(data: data, encoding: .utf8) {
            integrationStatus.antigravityActive = text.contains("moonside")
        } else {
            integrationStatus.antigravityActive = false
        }

        // Codex: check if hooks.json mentions moonside
        let codexHooksPath = homeDir + "/.codex/hooks.json"
        if let data = FileManager.default.contents(atPath: codexHooksPath),
           let text = String(data: data, encoding: .utf8) {
            integrationStatus.codexActive = text.contains("moonside")
        } else {
            integrationStatus.codexActive = false
        }
    }

    func testFlash(agent: AgentType) {
        flashWorkItem?.cancel()

        isTestingFlash = true
        let prevState = currentState

        let themeCmd: String
        switch agent {
        case .claudeCode:
            // #583300 → #831100, Blue Lava effect
            themeCmd = BLECommand.theme("LAVA1", 88, 51, 0, 131, 17, 0)
        case .antigravity:
            // #831100 → #011D57, Blue Lava effect
            themeCmd = BLECommand.theme("LAVA1", 131, 17, 0, 1, 29, 87)
        case .codex:
            // #450D59 → #11053B, Purple Lava effect
            themeCmd = BLECommand.theme("LAVA1", 69, 13, 89, 17, 5, 59)
        }

        bluetoothManager?.send(BLECommand.ledOn)
        bluetoothManager?.send(themeCmd)

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.applyState(prevState)
            self.isTestingFlash = false
        }
        flashWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: workItem)
    }

    func manualReconnect() {
        bluetoothManager?.manualReconnect()
    }

    // MARK: - Private

    private func persistThemeColors() {
        let c1 = themeColor1.rgbComponents
        let c2 = themeColor2.rgbComponents
        Defaults[.themeColor1R] = c1.r
        Defaults[.themeColor1G] = c1.g
        Defaults[.themeColor1B] = c1.b
        Defaults[.themeColor2R] = c2.r
        Defaults[.themeColor2G] = c2.g
        Defaults[.themeColor2B] = c2.b
    }

    private func sendCurrentThemeWithColors() {
        guard let theme = selectedTheme else { return }
        bluetoothManager?.send(BLECommand.ledOn)
        bluetoothManager?.send(theme.commandWith(color1: themeColor1, color2: themeColor2))
        isLedOn = true
    }

    // MARK: - State → BLE command mapping

    static let stateCommands: [LampState: [String]] = [
        // .idle is handled dynamically in applyState() using the user's themeColor1
        .working: [BLECommand.ledOn, BLECommand.theme("BEAT2", 88, 51, 0, 131, 17, 0)],
        .workingAG: [BLECommand.ledOn, BLECommand.theme("BEAT2", 131, 17, 0, 1, 29, 87)],
        .workingCX: [BLECommand.ledOn, BLECommand.theme("BEAT2", 69, 13, 89, 17, 5, 59)],
        .inputCC: [BLECommand.ledOn, BLECommand.theme("LAVA1", 88, 51, 0, 131, 17, 0)],
        .inputAG: [BLECommand.ledOn, BLECommand.theme("LAVA1", 131, 17, 0, 1, 29, 87)],
        .inputCX: [BLECommand.ledOn, BLECommand.theme("LAVA1", 69, 13, 89, 17, 5, 59)],
        .off: [BLECommand.ledOff],
    ]

    private func updateSleepPrevention(for state: LampState) {
        let isWorking = (state == .working || state == .workingAG || state == .workingCX)

        if isWorking && sleepPreventionActivity == nil {
            sleepPreventionActivity = ProcessInfo.processInfo.beginActivity(
                options: .idleSystemSleepDisabled,
                reason: "MoonsideBar: AI agent is actively processing"
            )
        } else if !isWorking, let activity = sleepPreventionActivity {
            ProcessInfo.processInfo.endActivity(activity)
            sleepPreventionActivity = nil
        }
    }
}

import Defaults
import Foundation
import Observation
import SwiftUI

// MARK: - Enums

enum ControlMode: String, CaseIterable, Defaults.Serializable {
    case auto
    case manual
}

enum LampState: String, Defaults.Serializable {
    case idle
    case working
    case inputCC = "input_cc"
    case inputAG = "input_ag"
    case off
}

enum ConnectionStatus: String {
    case disconnected
    case connecting
    case connected
}

// MARK: - Moonside Themes

struct MoonsideTheme: Identifiable, Hashable {
    let id: String
    let name: String
    let command: String
    let colors: (Color, Color) // two representative colors for preview

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: MoonsideTheme, rhs: MoonsideTheme) -> Bool { lhs.id == rhs.id }
}

extension MoonsideTheme {
    static let all: [MoonsideTheme] = [
        // Solid blends
        MoonsideTheme(id: "THEME1", name: "Warm Sunset", command: "THEME.THEME1.255,100,0,255,50,0,",
                       colors: (.orange, .red)),
        MoonsideTheme(id: "THEME2", name: "Cool Ocean", command: "THEME.THEME2.0,100,255,0,200,255,",
                       colors: (.blue, .cyan)),
        MoonsideTheme(id: "THEME3", name: "Forest", command: "THEME.THEME3.0,200,50,50,255,100,",
                       colors: (.green, .mint)),
        MoonsideTheme(id: "THEME4", name: "Lavender", command: "THEME.THEME4.180,100,255,255,100,200,",
                       colors: (.purple, .pink)),
        MoonsideTheme(id: "THEME5", name: "Fireplace", command: "THEME.THEME5.255,80,0,255,40,0,",
                       colors: (.red, .orange)),
        // Wave
        MoonsideTheme(id: "WAVE1", name: "Pink Ball", command: "THEME.WAVE1.255,100,200,100,0,150,",
                       colors: (.pink, .purple)),
        // Beat (pulse)
        MoonsideTheme(id: "BEAT1", name: "Dancing Beat", command: "THEME.BEAT1.255,255,255,100,100,100,",
                       colors: (.white, .gray)),
        MoonsideTheme(id: "BEAT2", name: "Bouncing Stars", command: "THEME.BEAT2.255,255,255,0,0,140,",
                       colors: (.white, Color(red: 0, green: 0, blue: 0.55))),
        MoonsideTheme(id: "BEAT3", name: "Shining Beat", command: "THEME.BEAT3.255,100,200,150,0,255,",
                       colors: (.pink, .purple)),
        // Gradient
        MoonsideTheme(id: "GRADIENT1", name: "Green Land", command: "THEME.GRADIENT1.0,200,50,50,255,100,",
                       colors: (.green, .mint)),
        MoonsideTheme(id: "GRADIENT2", name: "Summer Glow", command: "THEME.GRADIENT2.255,200,50,255,100,0,",
                       colors: (.yellow, .orange)),
        // Rainbow
        MoonsideTheme(id: "RAINBOW1", name: "Rainbow One", command: "THEME.RAINBOW1.255,0,0,0,0,255,",
                       colors: (.red, .blue)),
        MoonsideTheme(id: "RAINBOW2", name: "Rising Rainbow", command: "THEME.RAINBOW2.255,100,0,100,0,255,",
                       colors: (.orange, .purple)),
        MoonsideTheme(id: "RAINBOW3", name: "Blending Rainbow", command: "THEME.RAINBOW3.0,255,0,0,0,255,",
                       colors: (.green, .blue)),
        // Effects
        MoonsideTheme(id: "TWINKLE1", name: "Twinkle Star", command: "THEME.TWINKLE1.255,200,100,100,50,0,",
                       colors: (.white, .yellow)),
        MoonsideTheme(id: "FIRE2", name: "Night Fire", command: "THEME.FIRE2.255,50,0,255,150,0,",
                       colors: (.red, .orange)),
        MoonsideTheme(id: "COLORDROP1", name: "Raining Blue", command: "THEME.COLORDROP1.0,100,255,0,50,200,",
                       colors: (.blue, Color(red: 0, green: 0.2, blue: 0.8))),
        MoonsideTheme(id: "LAVA1", name: "Blue Lava", command: "THEME.LAVA1.0,50,255,0,0,100,",
                       colors: (.blue, Color(red: 0, green: 0, blue: 0.4))),
        MoonsideTheme(id: "PULSING1", name: "Pulsing", command: "THEME.PULSING1.0,100,255,30,60,180,",
                       colors: (.blue, Color(red: 0.12, green: 0.24, blue: 0.7))),
    ]
}

// MARK: - Defaults Keys

extension Defaults.Keys {
    static let brightness = Key<Int>("brightness", default: 50)
    static let controlMode = Key<ControlMode>("controlMode", default: .auto)
    static let lastColorR = Key<Int>("lastColorR", default: 255)
    static let lastColorG = Key<Int>("lastColorG", default: 230)
    static let lastColorB = Key<Int>("lastColorB", default: 200)
    static let deviceUUID = Key<String>("deviceUUID", default: "")
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

    var isConnected: Bool { connectionStatus == .connected }

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
            guard self.controlMode == .auto else { return }
            self.applyState(state)
        }
        monitor.start()
        stateFileMonitor = monitor
    }

    func applyState(_ state: LampState) {
        currentState = state
        guard let commands = Self.stateCommands[state] else { return }
        for command in commands {
            bluetoothManager?.send(command)
        }
        isLedOn = state != .off
    }

    func setBrightness(_ value: Int) {
        let clamped = max(0, min(120, value))
        brightness = clamped
        Defaults[.brightness] = clamped
        let cmd = String(format: "BRIGH%03d", clamped)
        bluetoothManager?.send(cmd)
    }

    func setColor(_ color: Color) {
        customColor = color
        let resolved = NSColor(color)
        let r = Int((resolved.redComponent * 255).rounded())
        let g = Int((resolved.greenComponent * 255).rounded())
        let b = Int((resolved.blueComponent * 255).rounded())
        Defaults[.lastColorR] = r
        Defaults[.lastColorG] = g
        Defaults[.lastColorB] = b
        let cmd = String(format: "COLOR%03d%03d%03d", r, g, b)
        bluetoothManager?.send("LEDON")
        bluetoothManager?.send(cmd)
        isLedOn = true
    }

    func applyTheme(_ theme: MoonsideTheme) {
        bluetoothManager?.send("LEDON")
        bluetoothManager?.send(theme.command)
        isLedOn = true
    }

    func toggleLed() {
        isLedOn.toggle()
        bluetoothManager?.send(isLedOn ? "LEDON" : "LEDOFF")
        if isLedOn {
            applyState(.idle)
        }
    }

    func setControlMode(_ mode: ControlMode) {
        controlMode = mode
        Defaults[.controlMode] = mode
    }

    // MARK: - State → BLE command mapping

    static let stateCommands: [LampState: [String]] = [
        .idle: ["LEDON", "COLOR255230200", "BRIGH050"],
        .working: ["LEDON", "THEME.BEAT2.255,255,255,0,0,140,"],
        .inputCC: ["LEDON", "THEME.BEAT2.255,160,50,180,60,0,"],
        .inputAG: ["LEDON", "THEME.BEAT2.100,180,255,0,30,140,"],
        .off: ["LEDOFF"],
    ]
}

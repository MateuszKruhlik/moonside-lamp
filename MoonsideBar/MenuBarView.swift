import LaunchAtLogin
import SwiftUI

struct MenuBarView: View {
    @Bindable var appState: AppState
    @State private var showThemes = false

    var body: some View {
        VStack(spacing: 0) {
            connectionHeader
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            toggleSection
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

            brightnessSection
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

            Divider()

            modeSection
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

            Divider()

            colorSection
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

            Divider()

            presetsSection
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

            Divider()

            if showThemes {
                themeBrowser
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                Divider()
            }

            if appState.controlMode == .auto {
                stateIndicator
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                Divider()
            }

            footerSection
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Connection Header

    private var connectionHeader: some View {
        HStack {
            Circle()
                .fill(connectionColor)
                .frame(width: 8, height: 8)
            Text(connectionText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var connectionColor: Color {
        switch appState.connectionStatus {
        case .connected: .green
        case .connecting: .orange
        case .disconnected: .red
        }
    }

    private var connectionText: String {
        switch appState.connectionStatus {
        case .connected: "Connected"
        case .connecting: "Connecting…"
        case .disconnected: "Disconnected"
        }
    }

    // MARK: - LED Toggle

    private var toggleSection: some View {
        Toggle(isOn: Binding(
            get: { appState.isLedOn },
            set: { _ in appState.toggleLed() }
        )) {
            Label("Lamp", systemImage: "lightbulb.fill")
                .font(.system(size: 13, weight: .medium))
        }
        .toggleStyle(.switch)
    }

    // MARK: - Brightness

    private var brightnessSection: some View {
        HStack {
            Image(systemName: "sun.min")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Slider(
                value: Binding(
                    get: { Double(appState.brightness) },
                    set: { appState.setBrightness(Int($0)) }
                ),
                in: 0...120,
                step: 1
            )
            Image(systemName: "sun.max")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Control Mode

    private var modeSection: some View {
        HStack {
            Text("Mode")
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Picker("", selection: Binding(
                get: { appState.controlMode },
                set: { appState.setControlMode($0) }
            )) {
                Text("Auto").tag(ControlMode.auto)
                Text("Manual").tag(ControlMode.manual)
            }
            .pickerStyle(.segmented)
            .frame(width: 130)
        }
    }

    // MARK: - Color Picker

    private var colorSection: some View {
        HStack {
            Text("Color")
                .font(.system(size: 13, weight: .medium))
            Spacer()
            ColorPicker("", selection: Binding(
                get: { appState.customColor },
                set: { appState.setColor($0) }
            ), supportsOpacity: false)
            .labelsHidden()
        }
    }

    // MARK: - Presets

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Presets")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(showThemes ? "Hide Themes" : "Themes ▸") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showThemes.toggle()
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                PresetButton(
                    label: "Warm White",
                    color: Color(red: 1.0, green: 0.9, blue: 0.78),
                    isActive: appState.currentState == .idle
                ) {
                    appState.applyState(.idle)
                }
                PresetButton(
                    label: "Focus",
                    color: Color(red: 0.39, green: 0.71, blue: 1.0),
                    isActive: appState.currentState == .working
                ) {
                    appState.applyState(.working)
                }
                PresetButton(
                    label: "Off",
                    color: Color.gray.opacity(0.3),
                    isActive: appState.currentState == .off
                ) {
                    appState.applyState(.off)
                }
            }
        }
    }

    // MARK: - Theme Browser

    private var themeBrowser: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Themes")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 6),
                GridItem(.flexible(), spacing: 6),
                GridItem(.flexible(), spacing: 6),
            ], spacing: 6) {
                ForEach(MoonsideTheme.all) { theme in
                    ThemeButton(theme: theme) {
                        appState.applyTheme(theme)
                    }
                }
            }
        }
    }

    // MARK: - State Indicator

    private var stateIndicator: some View {
        HStack {
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)
            Text("Agent: \(stateLabel)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var stateColor: Color {
        switch appState.currentState {
        case .idle: Color(red: 1.0, green: 0.9, blue: 0.78)
        case .working: .white
        case .inputCC: .orange
        case .inputAG: .blue
        case .off: .gray
        }
    }

    private var stateLabel: String {
        switch appState.currentState {
        case .idle: "Idle"
        case .working: "Working"
        case .inputCC: "Claude Code waiting"
        case .inputAG: "Antigravity waiting"
        case .off: "Off"
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 6) {
            LaunchAtLogin.Toggle("Launch at Login")
                .font(.system(size: 12))
            Button("Quit MoonsideBar") {
                appState.bluetoothManager?.send("LEDOFF")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NSApplication.shared.terminate(nil)
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preset Button

struct PresetButton: View {
    let label: String
    let color: Color
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Theme Button

struct ThemeButton: View {
    let theme: MoonsideTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [theme.colors.0, theme.colors.1],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 28)
                Text(theme.name)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

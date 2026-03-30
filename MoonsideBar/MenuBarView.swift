import SwiftUI

// MARK: - Card Styling (iOS Control Center style)

private enum Layout {
    static let cardRadius: CGFloat = 24
    static let cardPadding: CGFloat = 14
    static let iconSize: CGFloat = 24
    static let iconFrame: CGFloat = 40
    static let agentIconSize: CGFloat = 38
    static let cardHeight: CGFloat = 68
    static let titleFont: Font = .system(size: 15, weight: .medium, design: .monospaced)
    static let subtitleFont: Font = .system(size: 14, weight: .medium, design: .monospaced)
    static let subtitleColor: Color = .white.opacity(0.32)
}

private let cardRadius = Layout.cardRadius
private let cardPadding = Layout.cardPadding
private let titleFont = Layout.titleFont
private let subtitleFont = Layout.subtitleFont
private let subtitleColor = Layout.subtitleColor

struct ControlCenterCard: ViewModifier {
    var fixedHeight: CGFloat? = 68

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, cardPadding)
            .padding(.vertical, fixedHeight == nil ? 15 : 0)
            .frame(maxWidth: .infinity)
            .frame(height: fixedHeight)
            .background(
                ZStack {
                    Color(red: 51/255, green: 51/255, blue: 51/255).opacity(0.35)
                    Color.black.opacity(0.2)
                }
                .clipShape(RoundedRectangle(cornerRadius: cardRadius))
            )
    }
}

extension View {
    func ccCard(height: CGFloat? = 68) -> some View {
        modifier(ControlCenterCard(fixedHeight: height))
    }
}

// MARK: - Card Hover Button Style

struct CardHoverButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : (isHovered ? 0.9 : 1.0))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

// MARK: - Agent Colors

enum AgentColors {
    static let claudeCode1 = Color(red: 186/255, green: 91/255, blue: 60/255)    // #BA5B3C
    static let claudeCode2 = Color(red: 243/255, green: 159/255, blue: 132/255)  // #F39F84
    static let antigravity1 = Color(red: 29/255, green: 117/255, blue: 236/255)  // #1D75EC
    static let antigravity2 = Color(red: 128/255, green: 185/255, blue: 255/255) // #80B9FF
    static let codex1 = Color(red: 69/255, green: 13/255, blue: 89/255)          // #450D59
    static let codex2 = Color(red: 17/255, green: 5/255, blue: 59/255)          // #11053B
}

// MARK: - Agent Icon Names

enum AgentIcon {
    static let claudeCode = "claude"
    static let antigravity = "antigravity"
    static let codex = "codex"
}

// MARK: - Dot Toggle (Figma: two 8px dots, vertical, backdrop-blur capsule)

struct DotToggle: View {
    let isOn: Bool

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(.white.opacity(isOn ? 0.3 : 1.0))
                .frame(width: 8, height: 8)
            Circle()
                .fill(.white.opacity(isOn ? 1.0 : 0.3))
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .animation(.easeInOut(duration: 0.2), value: isOn)
    }
}

// MARK: - Toggle Card (shared by Mode + Launch at Login)

struct ToggleCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Layout.iconSize, height: Layout.iconSize)
                    .foregroundStyle(.white)
                    .frame(width: Layout.iconFrame, height: Layout.iconFrame)

                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(Layout.titleFont)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(Layout.subtitleFont)
                        .foregroundStyle(Layout.subtitleColor)
                }

                Spacer()

                DotToggle(isOn: isOn)
                    .padding(.trailing, 4)
            }
            .ccCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(subtitle)
    }
}

// MARK: - Thin Bar Slider

struct ThinBarSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    @State private var isDragging = false

    private static let thumbSize: CGFloat = 20
    private static let trackHeight: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            let trackWidth = geo.size.width
            let span = range.upperBound - range.lowerBound
            let fraction = span > 0 ? (value - range.lowerBound) / span : 0
            let fillWidth = max(0, trackWidth * fraction)
            let thumbX = max(0, min(fillWidth - Self.thumbSize / 2, trackWidth - Self.thumbSize))

            ZStack(alignment: .leading) {
                // Inactive track
                Capsule()
                    .fill(.white.opacity(0.32))
                    .frame(height: Self.trackHeight)

                // Active track
                RoundedRectangle(cornerRadius: 4)
                    .fill(.white)
                    .blendMode(.plusLighter)
                    .frame(width: fillWidth, height: Self.trackHeight)

                // Thumb
                Circle()
                    .fill(.white)
                    .frame(width: Self.thumbSize, height: Self.thumbSize)
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                    .scaleEffect(isDragging ? 1.12 : 1.0)
                    .offset(x: thumbX)
                    .animation(.easeOut(duration: 0.12), value: isDragging)
            }
            .frame(height: Self.thumbSize)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        isDragging = true
                        let pct = max(0, min(1, drag.location.x / trackWidth))
                        value = range.lowerBound + pct * span
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .frame(height: 20)
    }
}

// MARK: - Main View

struct MenuBarView: View {
    @Bindable var appState: AppState
    @State private var wizardAgent: AgentType?

    var body: some View {
        VStack(spacing: 10) {
            connectionAndPowerSection
            modeSection
            brightnessSection
            agentCardsSection
            moreSettingsButton
            if appState.isMoreSettingsExpanded {
                moreSettingsSection
            }

            if let agent = wizardAgent {
                SetupWizardView(appState: appState, agent: agent) {
                    withAnimation { wizardAgent = nil }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }

    // MARK: - 1. Connection + Power

    private var connectionAndPowerSection: some View {
        HStack(spacing: 10) {
            // Connection card
            Button {
                if appState.connectionStatus == .unauthorized {
                    // Open System Settings → Privacy → Bluetooth
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth") {
                        NSWorkspace.shared.open(url)
                    }
                } else if appState.connectionStatus == .disconnected {
                    appState.manualReconnect()
                }
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(connectionDotColor)
                        .frame(width: 8, height: 8)
                        .frame(width: Layout.iconFrame, height: Layout.iconFrame)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Moonside")
                            .font(titleFont)
                            .foregroundStyle(.white)
                        Text(connectionText)
                            .font(subtitleFont)
                            .foregroundStyle(appState.connectionStatus == .unauthorized ? .red.opacity(0.7) : subtitleColor)
                    }
                    Spacer()
                }
                .ccCard()
            }
            .buttonStyle(CardHoverButtonStyle())

            // Power button card
            Button {
                appState.toggleLed()
            } label: {
                Image(appState.isLedOn ? "icon_power" : "icon_poweroff")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Layout.iconSize, height: Layout.iconSize)
                    .foregroundStyle(.white)
                    .frame(width: 102, height: Layout.cardHeight)
                    .background(
                        ZStack {
                            Color(red: 51/255, green: 51/255, blue: 51/255).opacity(0.35)
                            Color.black.opacity(0.2)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: cardRadius))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Power")
            .accessibilityValue(appState.isLedOn ? "On" : "Off")
        }
    }

    // MARK: - 2. Mode

    private var modeSection: some View {
        ToggleCard(
            icon: "icon_mode",
            title: "Mode",
            subtitle: appState.controlMode == .agenticLighting ? "Agentic lighting" : "Manual",
            isOn: appState.controlMode == .agenticLighting
        ) {
            let newMode: ControlMode = appState.controlMode == .agenticLighting ? .manual : .agenticLighting
            appState.setControlMode(newMode)
        }
    }

    // MARK: - 3. Brightness

    private var brightnessSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image("icon_brightness")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Layout.iconSize, height: Layout.iconSize)
                    .foregroundStyle(.white)
                    .frame(width: Layout.iconFrame, height: Layout.iconFrame)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Brightness")
                        .font(titleFont)
                        .foregroundStyle(.white)
                    Text(brightnessLabel)
                        .font(subtitleFont)
                        .foregroundStyle(subtitleColor)
                }
                Spacer()
            }

            ThinBarSlider(value: brightnessBinding, range: 0...120)
                .accessibilityLabel("Brightness")
                .accessibilityValue("\(appState.brightness)")
        }
        .ccCard(height: nil)
    }

    // MARK: - 4. Agent Cards

    private var agentCardsSection: some View {
        VStack(spacing: 10) {
            agentCard(
                name: "Claude code",
                iconName: AgentIcon.claudeCode,
                isActive: appState.integrationStatus.claudeCodeActive,
                agent: .claudeCode
            )

            agentCard(
                name: "Antigravity",
                iconName: AgentIcon.antigravity,
                isActive: appState.integrationStatus.antigravityActive,
                agent: .antigravity
            )

            agentCard(
                name: "Codex",
                iconName: AgentIcon.codex,
                isActive: appState.integrationStatus.codexActive,
                agent: .codex
            )
        }
    }

    private func agentCard(name: String, iconName: String, isActive: Bool, agent: AgentType) -> some View {
        let checkMessage: String? = switch agent {
        case .claudeCode: appState.claudeCodeCheckMessage
        case .antigravity: appState.antigravityCheckMessage
        case .codex: appState.codexCheckMessage
        }
        let subtitleText = checkMessage ?? (isActive ? "connected" : "disconnected")
        let subtitleForeground: Color = {
            if let msg = checkMessage {
                return msg == "connected" ? .green : (msg == "checking…" ? .orange : .red.opacity(0.7))
            }
            return subtitleColor
        }()

        return HStack(spacing: 8) {
            Image(iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Layout.agentIconSize, height: Layout.agentIconSize)

            VStack(alignment: .leading, spacing: 0) {
                Text(name)
                    .font(titleFont)
                    .foregroundStyle(.white)
                Text(subtitleText)
                    .font(subtitleFont)
                    .foregroundStyle(subtitleForeground)
            }

            Spacer()

            Button {
                appState.checkIntegrationWithFeedback(agent: agent)
                if isActive {
                    appState.testFlash(agent: agent)
                } else {
                    withAnimation { wizardAgent = agent }
                }
            } label: {
                Text(isActive ? "Reconnect" : "Setup")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(appState.isTestingFlash)
            .opacity(appState.isTestingFlash ? 0.5 : 1)
            .accessibilityLabel(isActive ? "Reconnect \(name)" : "Setup \(name)")
        }
        .ccCard()
        .accessibilityElement(children: .combine)
    }

    // MARK: - 5. More Settings Button

    private var moreSettingsButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                appState.isMoreSettingsExpanded.toggle()
            }
        } label: {
            Text(appState.isMoreSettingsExpanded ? "Less settings" : "More settings")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(subtitleColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.06), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 6. More Settings Content

    private var moreSettingsSection: some View {
        VStack(spacing: 10) {
            themesCard
            colorsCard
            launchAtLoginCard
        }
        .transition(
            .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .top))
            )
        )
    }

    // MARK: - 6a. Themes Card

    private var themesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image("icon_themes")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Layout.iconSize, height: Layout.iconSize)
                    .foregroundStyle(.white)
                    .frame(width: Layout.iconFrame, height: Layout.iconFrame)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Themes")
                        .font(titleFont)
                        .foregroundStyle(.white)
                    Text(appState.selectedTheme?.name ?? "None")
                        .font(subtitleFont)
                        .foregroundStyle(subtitleColor)
                }
                Spacer()

                Button {
                    if let theme = appState.selectedTheme {
                        appState.resetThemeColors()
                        appState.applyTheme(theme)
                    }
                } label: {
                    Image(systemName: "arrow.2.circlepath")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(appState.selectedTheme == nil)
                .opacity(appState.selectedTheme != nil ? 1 : 0.3)
            }

            ThinBarSlider(
                value: themeBinding,
                range: 0...Double(max(1, MoonsideTheme.all.count - 1))
            )
        }
        .ccCard(height: nil)
    }

    // MARK: - 6b. Colors Card

    private var colorsCard: some View {
        ColorsCard(appState: appState)
            .ccCard(height: nil)
    }

    // MARK: - 6c. Launch at Login

    private var launchAtLoginCard: some View {
        ToggleCard(
            icon: "icon_login",
            title: "Launch at login",
            subtitle: appState.launchAtLogin ? "on" : "off",
            isOn: appState.launchAtLogin
        ) {
            appState.toggleLaunchAtLogin()
        }
    }

    // MARK: - Bindings

    private var brightnessBinding: Binding<Double> {
        Binding(
            get: { Double(appState.brightness) },
            set: { appState.setBrightness(Int($0)) }
        )
    }

    private var themeBinding: Binding<Double> {
        Binding(
            get: { Double(themeIndex) },
            set: { newVal in
                let idx = Int(newVal.rounded())
                let clamped = max(0, min(MoonsideTheme.all.count - 1, idx))
                appState.applyTheme(MoonsideTheme.all[clamped])
            }
        )
    }

    // MARK: - Helpers

    private var connectionDotColor: Color {
        switch appState.connectionStatus {
        case .connected: Color(red: 0.2, green: 0.7, blue: 0.4) // #33b366
        case .connecting: .orange
        case .unauthorized: .red
        case .disconnected: Color(red: 0.65, green: 0.25, blue: 0.25)
        }
    }

    private var connectionText: String {
        switch appState.connectionStatus {
        case .connected: "connected"
        case .connecting: "connecting…"
        case .unauthorized: "allow Bluetooth in Settings"
        case .disconnected: "disconnected"
        }
    }

    private var brightnessLabel: String {
        let pct = Double(appState.brightness) / 120.0
        if pct < 0.33 { return "Low" }
        if pct < 0.66 { return "Medium" }
        return "High"
    }

    private var themeIndex: Int {
        guard let theme = appState.selectedTheme else { return 0 }
        return MoonsideTheme.all.firstIndex(of: theme) ?? 0
    }
}

// MARK: - Colors Card

struct ColorsCard: View {
    @Bindable var appState: AppState
    @State private var editingSlot: ColorSlot = .color1
    @State private var hexInput: String = "#FFFFFF"
    @State private var selectedGridColor: Color?

    enum ColorSlot: String, CaseIterable {
        case color1 = "first"
        case color2 = "Last"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 8) {
                Image("icon_color")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Layout.iconSize, height: Layout.iconSize)
                    .foregroundStyle(.white)
                    .frame(width: Layout.iconFrame, height: Layout.iconFrame)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Colors")
                        .font(titleFont)
                        .foregroundStyle(.white)
                    Text("Smooth transition between colors")
                        .font(subtitleFont)
                        .foregroundStyle(subtitleColor)
                }
                Spacer()

                // Reset button
                Button {
                    appState.resetThemeColors()
                    syncHexFromSlot()
                } label: {
                    Text("Reset")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(appState.selectedTheme == nil)
                .opacity(appState.selectedTheme != nil ? 1 : 0.3)
            }

            VStack(spacing: 16) {
                segmentedControl

                hexInputField

                colorGrid

                if !appState.recentColors.isEmpty {
                    recentColorsSection
                }
            }
        }
        .onAppear { syncHexFromSlot() }
    }

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(ColorSlot.allCases, id: \.self) { slot in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        editingSlot = slot
                        syncHexFromSlot()
                    }
                } label: {
                    Text(slot.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(editingSlot == slot ? Color(red: 1/255, green: 1/255, blue: 1/255) : subtitleColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(
                            editingSlot == slot
                                ? AnyShapeStyle(Color.white)
                                : AnyShapeStyle(Color.clear),
                            in: RoundedRectangle(cornerRadius: 7)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
    }

    private var hexInputField: some View {
        TextField("", text: $hexInput)
            .font(.system(size: 15, weight: .medium, design: .monospaced))
            .foregroundStyle(.white)
            .textFieldStyle(.plain)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
            .onSubmit {
                applyHex()
            }
    }

    private var colorGrid: some View {
        VStack(spacing: 0) {
            ForEach(Array(Self.gridColors.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, hex in
                        let color = Color(hex: hex) ?? .clear
                        Rectangle()
                            .fill(color)
                            .frame(height: 27)
                            .frame(maxWidth: .infinity)
                            .overlay(
                                selectedGridColor == color
                                    ? RoundedRectangle(cornerRadius: 2)
                                        .stroke(.white, lineWidth: 2)
                                        .padding(4)
                                    : nil
                            )
                            .onTapGesture {
                                applyColor(color, hex: hex)
                            }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private var recentColorsSection: some View {
        let colors = appState.recentColors
        let rows = stride(from: 0, to: colors.count, by: 6).map {
            Array(colors[$0..<min($0 + 6, colors.count)])
        }

        return VStack(spacing: 18) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, color in
                        recentDot(color: color)
                    }
                    // Fill remaining slots to keep layout even
                    if row.count < 6 {
                        ForEach(0..<(6 - row.count), id: \.self) { _ in
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 30, height: 30)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func recentDot(color: Color) -> some View {
        Button {
            applyColor(color, hex: color.hexString)
        } label: {
            Circle()
                .fill(color)
                .frame(width: 30, height: 30)
                .overlay(
                    selectedGridColor == color
                        ? Circle()
                            .stroke(.white, lineWidth: 2)
                            .padding(4)
                        : nil
                )
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func applyColor(_ color: Color, hex: String) {
        selectedGridColor = color
        hexInput = hex

        // Auto-select first theme if none selected
        if appState.selectedTheme == nil {
            appState.applyTheme(MoonsideTheme.all[0])
        }

        switch editingSlot {
        case .color1:
            appState.updateThemeColor1(color)
        case .color2:
            appState.updateThemeColor2(color)
        }
        appState.addToRecentColors(color)
    }

    private func applyHex() {
        let cleaned = hexInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let color = Color(hex: cleaned) else { return }
        applyColor(color, hex: cleaned)
    }

    private func syncHexFromSlot() {
        let color = editingSlot == .color1 ? appState.themeColor1 : appState.themeColor2
        hexInput = color.hexString
        selectedGridColor = color
    }

    // MARK: - Color Grid Data (10 rows x 12 columns from Figma)

    static let gridColors: [[String]] = [
        ["#FEFFFE", "#EBEBEB", "#D6D6D6", "#C2C2C2", "#ADADAD", "#999999", "#858585", "#707070", "#5C5C5C", "#474747", "#333333", "#000000"],
        ["#00374A", "#011D57", "#11053B", "#2E063D", "#3C071B", "#5C0701", "#5A1C00", "#583300", "#563D00", "#666100", "#4F5504", "#263E0F"],
        ["#004D65", "#012F7B", "#1A0A52", "#450D59", "#551029", "#831100", "#7B2900", "#7A4A00", "#785800", "#8D8602", "#6F760A", "#38571A"],
        ["#016E8F", "#0042A9", "#2C0977", "#61187C", "#791A3D", "#B51A00", "#AD3E00", "#A96800", "#A67B01", "#C4BC00", "#9BA50E", "#4E7A27"],
        ["#008CB4", "#0056D6", "#371A94", "#7A219E", "#99244F", "#E22400", "#DA5100", "#D38301", "#D19D01", "#F5EC00", "#C3D117", "#669D34"],
        ["#00A1D8", "#0061FD", "#4D22B2", "#982ABC", "#B92D5D", "#FF4015", "#FF6A00", "#FFAB01", "#FCC700", "#FEFB41", "#D9EC37", "#76BB40"],
        ["#01C7FC", "#3A87FD", "#5E30EB", "#BE38F3", "#E63B7A", "#FE6250", "#FE8648", "#FEB43F", "#FECB3E", "#FFF76B", "#E4EF65", "#96D35F"],
        ["#52D6FC", "#74A7FF", "#864FFD", "#D357FE", "#EE719E", "#FF8C82", "#FEA57D", "#FEC777", "#FED977", "#FFF994", "#EAF28F", "#B1DD8B"],
        ["#93E3FC", "#A7C6FF", "#B18CFE", "#E292FE", "#F4A4C0", "#FFB5AF", "#FFC5AB", "#FED9A8", "#FDE4A8", "#FFFBB9", "#F1F7B7", "#CDE8B5"],
        ["#CBF0FF", "#D2E2FE", "#D8C9FE", "#EFCAFE", "#F9D3E0", "#FFDAD8", "#FFE2D6", "#FEECD4", "#FEF1D5", "#FDFBDD", "#F6FADB", "#DEEED4"],
    ]
}

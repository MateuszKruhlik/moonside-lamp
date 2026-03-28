import SwiftUI

// MARK: - How It Works View

struct HowItWorksView: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                header
                introSection
                agentLightingSection
                setupSection
                statesSection
                manualSection
                connectionSection
                stateFileSection
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 400, idealWidth: 440, minHeight: 460, idealHeight: 560)
        .background(.ultraThickMaterial)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            if let icon = NSImage(named: "icon_menubar") {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
            }

            Text("How it works")
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .foregroundStyle(.primary)

            Spacer()
        }
    }

    // MARK: - Sections

    private var introSection: some View {
        Text("MoonsideBar controls your Moonside Lamp One from the menu bar via Bluetooth. Use it as a standalone lamp controller or pair it with an AI coding agent — the lamp will change color based on what the agent is doing.")
            .font(.system(size: 13, design: .monospaced))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var agentLightingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Agentic lighting")

            Text("In Agentic mode, the lamp reacts to your AI agent automatically. No need to touch anything — it just works once set up.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                featureRow("Claude Code", "orange pulse while processing, slow glow when waiting for you")
                featureRow("Antigravity", "blue pulse while processing, slow glow when waiting for you")
                featureRow("Codex", "green pulse while processing, slow glow when waiting for you")
                featureRow("Idle", "warm white — agent is ready")
                featureRow("Off", "lamp turns off when the session ends")
            }
        }
    }

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("One-click setup")

            Text("Click \"Setup\" on the Claude Code, Antigravity, or Codex card. The wizard handles everything automatically:")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                bulletRow("Claude Code — installs a hook script and configures settings.json. Every agent event (start, stop, waiting) triggers the lamp.")
                bulletRow("Antigravity — adds lamp instructions to GEMINI.md. Gemini reads these and calls the hook when asking you a question.")
                bulletRow("Codex — installs a hook script and creates hooks.json. Codex events (start, tool use, stop) trigger the lamp.")
            }

            Text("The only prerequisite: have the CLI tool installed first (Claude Code, Gemini CLI, or Codex). The wizard checks this and tells you if something is missing.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Lamp states")

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                stateRow(color: .orange, state: "working", desc: "Claude Code is processing")
                stateRow(color: .blue, state: "working_ag", desc: "Antigravity is processing")
                stateRow(color: .green, state: "working_cx", desc: "Codex is processing")
                stateRow(color: .orange.opacity(0.6), state: "input_cc", desc: "Claude Code needs your input")
                stateRow(color: .blue.opacity(0.6), state: "input_ag", desc: "Antigravity needs your input")
                stateRow(color: .green.opacity(0.6), state: "input_cx", desc: "Codex needs your input")
                stateRow(color: Color(r: 255, g: 230, b: 200), state: "idle", desc: "Ready, no active task")
                stateRow(color: .gray.opacity(0.3), state: "off", desc: "Lamp off")
            }
        }
    }

    private var manualSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Manual mode")

            Text("Switch to Manual to take full control:")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                bulletRow("Pick any color from the grid or type a hex code")
                bulletRow("Slide through 20 themes — animated light effects")
                bulletRow("Adjust brightness from 0 to 120")
                bulletRow("Customize theme colors with the color editor")
            }
        }
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Bluetooth connection")

            Text("MoonsideBar finds your lamp automatically. On first launch, allow Bluetooth when macOS asks. After that, the app reconnects on its own — even after sleep or a restart.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                bulletRow("Green dot — connected")
                bulletRow("Orange dot — connecting…")
                bulletRow("Red dot — disconnected or Bluetooth not allowed")
            }

            Text("Click the connection card to reconnect, or open System Settings if Bluetooth access is needed.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var stateFileSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("For developers")

            Text("Any tool can control the lamp by writing to /tmp/moonside_state. MoonsideBar watches this file and reacts immediately.")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("printf 'working' > /tmp/moonside_state")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Reusable Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold, design: .monospaced))
            .foregroundStyle(.primary)
    }

    private func featureRow(_ label: String, _ description: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(width: 100, alignment: .leading)
            Text("— \(description)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("·")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func stateRow(color: Color, state: String, desc: String) -> some View {
        GridRow {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(state)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
            Text(desc)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Window Controller

final class HowItWorksWindowController {
    static let shared = HowItWorksWindowController()
    private var window: NSWindow?

    func showWindow() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let view = HowItWorksView()

        let hostingView = NSHostingView(rootView: view)
        let w = NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.contentMinSize = NSSize(width: 400, height: 460)
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.isMovableByWindowBackground = true
        w.contentView = hostingView
        w.center()
        w.isReleasedWhenClosed = false
        w.makeKeyAndOrderFront(nil)
        window = w
    }
}

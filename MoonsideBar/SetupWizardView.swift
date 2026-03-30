import SwiftUI

// MARK: - Setup Step

struct SetupStep: Identifiable {
    let id = UUID()
    let title: String
    var status: StepStatus
    var detail: String?

    enum StepStatus {
        case pending, checking, passed, failed, installed
    }
}

// MARK: - Setup Wizard View

struct SetupWizardView: View {
    @Bindable var appState: AppState
    let agent: AgentType
    let onDismiss: () -> Void

    @State private var steps: [SetupStep] = []
    @State private var isRunning = false
    @State private var isDone = false

    private var agentIconName: String {
        switch agent {
        case .claudeCode: "claude"
        case .antigravity: "antigravity"
        case .codex: "codex"
        }
    }

    private var agentTitle: String {
        switch agent {
        case .claudeCode: "Claude Code Setup"
        case .antigravity: "Antigravity Setup"
        case .codex: "Codex Setup"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            stepsList
            actionArea
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { buildSteps() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(agentIconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)

            Text(agentTitle)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Steps List

    private var stepsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(steps) { step in
                HStack(spacing: 10) {
                    statusIcon(step.status)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)

                        if let detail = step.detail {
                            Text(detail)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Action Area

    private var actionArea: some View {
        HStack {
            if isDone {
                let allPassed = steps.allSatisfy { $0.status == .passed || $0.status == .installed }
                Text(allPassed ? "Setup complete" : "Some steps need attention")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(allPassed ? .green : .orange)
            }

            Spacer()

            if !isDone {
                Button {
                    runSetup()
                } label: {
                    Text(isRunning ? "Setting up…" : "Run Setup")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isRunning)
            } else {
                Button {
                    onDismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Status Icon

    @ViewBuilder
    private func statusIcon(_ status: SetupStep.StepStatus) -> some View {
        switch status {
        case .pending:
            Circle()
                .fill(.white.opacity(0.2))
                .frame(width: 8, height: 8)
        case .checking:
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 8, height: 8)
        case .passed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.red.opacity(0.7))
        case .installed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.blue)
        }
    }

    // MARK: - Build Steps

    private func buildSteps() {
        switch agent {
        case .claudeCode:
            steps = [
                SetupStep(title: "Claude Code CLI installed", status: .pending,
                          detail: "~/.claude/ directory"),
                SetupStep(title: "Hook script installed", status: .pending,
                          detail: "~/.claude/moonside_hooks/moonside_hook.sh"),
                SetupStep(title: "Hooks configured in settings.json", status: .pending,
                          detail: "~/.claude/settings.json"),
                SetupStep(title: "State file accessible", status: .pending,
                          detail: "/tmp/moonside_state"),
            ]
        case .antigravity:
            steps = [
                SetupStep(title: "Gemini CLI installed", status: .pending,
                          detail: "~/.gemini/ directory"),
                SetupStep(title: "Lamp instructions in GEMINI.md", status: .pending,
                          detail: "~/.gemini/GEMINI.md"),
                SetupStep(title: "State file accessible", status: .pending,
                          detail: "/tmp/moonside_state"),
            ]
        case .codex:
            steps = [
                SetupStep(title: "Codex CLI installed", status: .pending,
                          detail: "~/.codex/ directory"),
                SetupStep(title: "Hook script installed", status: .pending,
                          detail: "~/.claude/moonside_hooks/moonside_codex_hook.sh"),
                SetupStep(title: "Hooks enabled in config.toml", status: .pending,
                          detail: "[features] codex_hooks = true"),
                SetupStep(title: "Hooks configured in hooks.json", status: .pending,
                          detail: "~/.codex/hooks.json"),
                SetupStep(title: "State file accessible", status: .pending,
                          detail: "/tmp/moonside_state"),
            ]
        }
    }

    // MARK: - Run Setup

    private func runSetup() {
        isRunning = true

        switch agent {
        case .claudeCode:
            runClaudeCodeSetup()
        case .antigravity:
            runAntigravitySetup()
        case .codex:
            runCodexSetup()
        }
    }

    private func runClaudeCodeSetup() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let fm = FileManager.default

        // Step 1: Check ~/.claude/ exists
        updateStep(0, status: .checking)
        let claudeDir = home + "/.claude"
        if fm.fileExists(atPath: claudeDir) {
            updateStep(0, status: .passed)
        } else {
            updateStep(0, status: .failed, detail: "Install Claude Code CLI first: claude.ai/claude-code")
            finishSetup()
            return
        }

        // Step 2: Install hook script
        updateStep(1, status: .checking)
        let hooksDir = home + "/.claude/moonside_hooks"
        let hookPath = hooksDir + "/moonside_hook.sh"

        if fm.fileExists(atPath: hookPath),
           let content = try? String(contentsOfFile: hookPath, encoding: .utf8),
           content.contains("moonside_state") {
            updateStep(1, status: .passed)
        } else {
            // Create directory and install hook
            do {
                try fm.createDirectory(atPath: hooksDir, withIntermediateDirectories: true)
                try Self.hookScriptContent.write(toFile: hookPath, atomically: true, encoding: .utf8)
                // Make executable
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookPath)
                updateStep(1, status: .installed, detail: "Hook script installed")
            } catch {
                updateStep(1, status: .failed, detail: "Failed: \(error.localizedDescription)")
                finishSetup()
                return
            }
        }

        // Step 3: Configure settings.json hooks
        updateStep(2, status: .checking)
        let settingsPath = home + "/.claude/settings.json"

        if let data = fm.contents(atPath: settingsPath),
           let text = String(data: data, encoding: .utf8),
           text.contains("moonside") {
            updateStep(2, status: .passed)
        } else {
            // Merge hooks into settings.json
            do {
                var settings: [String: Any] = [:]
                if let data = fm.contents(atPath: settingsPath),
                   let existing = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    settings = existing
                }
                let hooksData = Self.settingsHooksJSON.data(using: .utf8)!
                let hooksObj = try JSONSerialization.jsonObject(with: hooksData) as! [String: Any]
                settings["hooks"] = hooksObj["hooks"]
                let output = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
                try output.write(to: URL(fileURLWithPath: settingsPath))
                updateStep(2, status: .installed, detail: "Hooks merged into settings.json")
            } catch {
                updateStep(2, status: .failed, detail: "Failed: \(error.localizedDescription)")
            }
        }

        // Step 4: State file
        updateStep(3, status: .checking)
        let statePath = "/tmp/moonside_state"
        if fm.isWritableFile(atPath: "/tmp") {
            if !fm.fileExists(atPath: statePath) {
                fm.createFile(atPath: statePath, contents: "idle".data(using: .utf8))
            }
            updateStep(3, status: .passed)
        } else {
            updateStep(3, status: .failed, detail: "/tmp is not writable")
        }

        finishSetup()
    }

    private func runAntigravitySetup() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let fm = FileManager.default

        // Step 1: Check ~/.gemini/ exists
        updateStep(0, status: .checking)
        let geminiDir = home + "/.gemini"
        if fm.fileExists(atPath: geminiDir) {
            updateStep(0, status: .passed)
        } else {
            // Try to create it
            do {
                try fm.createDirectory(atPath: geminiDir, withIntermediateDirectories: true)
                updateStep(0, status: .installed, detail: "Created ~/.gemini/")
            } catch {
                updateStep(0, status: .failed, detail: "Install Gemini CLI first")
                finishSetup()
                return
            }
        }

        // Step 2: Add instructions to GEMINI.md
        updateStep(1, status: .checking)
        let geminiMdPath = geminiDir + "/GEMINI.md"

        if let data = fm.contents(atPath: geminiMdPath),
           let text = String(data: data, encoding: .utf8),
           text.contains("moonside") {
            updateStep(1, status: .passed)
        } else {
            do {
                var existing = ""
                if let data = fm.contents(atPath: geminiMdPath),
                   let text = String(data: data, encoding: .utf8) {
                    existing = text
                }
                let separator = existing.isEmpty ? "" : "\n\n"
                let newContent = existing + separator + Self.geminiMdContent
                try newContent.write(toFile: geminiMdPath, atomically: true, encoding: .utf8)
                updateStep(1, status: .installed, detail: "Instructions added to GEMINI.md")
            } catch {
                updateStep(1, status: .failed, detail: "Failed: \(error.localizedDescription)")
            }
        }

        // Step 3: State file
        updateStep(2, status: .checking)
        let statePath = "/tmp/moonside_state"
        if fm.isWritableFile(atPath: "/tmp") {
            if !fm.fileExists(atPath: statePath) {
                fm.createFile(atPath: statePath, contents: "idle".data(using: .utf8))
            }
            updateStep(2, status: .passed)
        } else {
            updateStep(2, status: .failed, detail: "/tmp is not writable")
        }

        finishSetup()
    }

    private func runCodexSetup() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let fm = FileManager.default

        // Step 1: Check ~/.codex/ exists
        updateStep(0, status: .checking)
        let codexDir = home + "/.codex"
        if fm.fileExists(atPath: codexDir) {
            updateStep(0, status: .passed)
        } else {
            updateStep(0, status: .failed, detail: "Install Codex CLI first: openai.com/codex")
            finishSetup()
            return
        }

        // Step 2: Install hook script
        updateStep(1, status: .checking)
        let hooksDir = home + "/.claude/moonside_hooks"
        let hookPath = hooksDir + "/moonside_codex_hook.sh"

        if fm.fileExists(atPath: hookPath),
           let content = try? String(contentsOfFile: hookPath, encoding: .utf8),
           content.contains("moonside_state") {
            updateStep(1, status: .passed)
        } else {
            do {
                try fm.createDirectory(atPath: hooksDir, withIntermediateDirectories: true)
                try Self.codexHookScriptContent.write(toFile: hookPath, atomically: true, encoding: .utf8)
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookPath)
                updateStep(1, status: .installed, detail: "Hook script installed")
            } catch {
                updateStep(1, status: .failed, detail: "Failed: \(error.localizedDescription)")
                finishSetup()
                return
            }
        }

        // Step 3: Enable hooks in config.toml
        updateStep(2, status: .checking)
        let configPath = codexDir + "/config.toml"
        let currentConfig = (try? String(contentsOfFile: configPath, encoding: .utf8)) ?? ""

        if currentConfig.contains("codex_hooks") && currentConfig.contains("true") {
            updateStep(2, status: .passed)
        } else {
            do {
                var updatedConfig = currentConfig
                if updatedConfig.contains("[features]") {
                    // Add codex_hooks under existing [features] section
                    updatedConfig = updatedConfig.replacingOccurrences(
                        of: "[features]",
                        with: "[features]\ncodex_hooks = true"
                    )
                } else {
                    // Add new [features] section
                    if !updatedConfig.isEmpty && !updatedConfig.hasSuffix("\n") {
                        updatedConfig += "\n"
                    }
                    updatedConfig += "\n[features]\ncodex_hooks = true\n"
                }
                try updatedConfig.write(toFile: configPath, atomically: true, encoding: .utf8)
                updateStep(2, status: .installed, detail: "Hooks enabled in config.toml")
            } catch {
                updateStep(2, status: .failed, detail: "Failed: \(error.localizedDescription)")
            }
        }

        // Step 4: Configure hooks.json
        updateStep(3, status: .checking)
        let hooksJsonPath = codexDir + "/hooks.json"

        if let data = fm.contents(atPath: hooksJsonPath),
           let text = String(data: data, encoding: .utf8),
           text.contains("moonside") {
            updateStep(3, status: .passed)
        } else {
            do {
                if let existingData = fm.contents(atPath: hooksJsonPath),
                   var existingJson = try JSONSerialization.jsonObject(with: existingData) as? [String: Any] {
                    // Merge moonside hooks into existing hooks.json
                    let moonsideData = Self.codexHooksJSON.data(using: .utf8)!
                    let moonsideJson = try JSONSerialization.jsonObject(with: moonsideData) as! [String: Any]
                    let moonsideHooks = moonsideJson["hooks"] as! [String: Any]

                    var existingHooks = existingJson["hooks"] as? [String: Any] ?? [:]
                    for (key, value) in moonsideHooks {
                        if var existingArray = existingHooks[key] as? [Any] {
                            existingArray.append(contentsOf: value as! [Any])
                            existingHooks[key] = existingArray
                        } else {
                            existingHooks[key] = value
                        }
                    }
                    existingJson["hooks"] = existingHooks

                    let output = try JSONSerialization.data(withJSONObject: existingJson, options: [.prettyPrinted, .sortedKeys])
                    try output.write(to: URL(fileURLWithPath: hooksJsonPath))
                } else {
                    // Create new hooks.json
                    try Self.codexHooksJSON.write(toFile: hooksJsonPath, atomically: true, encoding: .utf8)
                }
                updateStep(3, status: .installed, detail: "Hooks written to hooks.json")
            } catch {
                updateStep(3, status: .failed, detail: "Failed: \(error.localizedDescription)")
            }
        }

        // Step 5: State file
        updateStep(4, status: .checking)
        let statePath = "/tmp/moonside_state"
        if fm.isWritableFile(atPath: "/tmp") {
            if !fm.fileExists(atPath: statePath) {
                fm.createFile(atPath: statePath, contents: "idle".data(using: .utf8))
            }
            updateStep(4, status: .passed)
        } else {
            updateStep(4, status: .failed, detail: "/tmp is not writable")
        }

        finishSetup()
    }

    // MARK: - Helpers

    private func updateStep(_ index: Int, status: SetupStep.StepStatus, detail: String? = nil) {
        guard index < steps.count else { return }
        steps[index].status = status
        if let detail { steps[index].detail = detail }
    }

    private func finishSetup() {
        isRunning = false
        isDone = true
        appState.checkIntegrations()
    }

    // MARK: - Bundled Content

    static let hookScriptContent = """
    #!/usr/bin/env bash
    # Moonside LED hook for Claude Code / Antigravity.
    # Usage: moonside_hook.sh <working|working_ag|idle|input_cc|input_ag|off>
    # Always exits 0 to never block the caller.
    #
    # Priority: MoonsideBar.app (state file only) > Python daemon (state file + launch)

    set -e

    STATE="${1:-idle}"
    STATE_FILE="/tmp/moonside_state"

    # Write desired state (MoonsideBar.app watches this file)
    printf '%s' "$STATE" > "$STATE_FILE"

    exit 0
    """

    static let settingsHooksJSON = """
    {
      "hooks": {
        "SessionStart": [{"hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_hook.sh idle"}]}],
        "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_hook.sh working"}]}],
        "Stop": [{"hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_hook.sh idle"}]}],
        "PreToolUse": [
          {"matcher": "Bash", "hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_hook.sh working"}]},
          {"matcher": "Read", "hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_hook.sh working"}]},
          {"matcher": "Write", "hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_hook.sh working"}]},
          {"matcher": "Edit", "hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_hook.sh working"}]},
          {"matcher": "MultiEdit", "hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_hook.sh working"}]},
          {"matcher": "Glob", "hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_hook.sh working"}]},
          {"matcher": "Grep", "hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_hook.sh working"}]},
          {"matcher": "WebFetch", "hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_hook.sh working"}]},
          {"matcher": "WebSearch", "hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_hook.sh working"}]},
          {"matcher": "Task", "hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_hook.sh working"}]},
          {"matcher": "NotebookEdit", "hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_hook.sh working"}]},
          {"matcher": "Skill", "hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_hook.sh working"}]},
          {"matcher": "EnterPlanMode", "hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_hook.sh working"}]},
          {"matcher": "AskUserQuestion", "hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_hook.sh input_cc"}]},
          {"matcher": "ExitPlanMode", "hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_hook.sh input_cc"}]}
        ],
        "PostToolUse": [
          {"matcher": "AskUserQuestion", "hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_hook.sh input_cc"}]}
        ],
        "PermissionRequest": [{"hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_hook.sh input_cc"}]}],
        "Notification": [
          {"matcher": "permission_prompt|elicitation_dialog", "hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_hook.sh input_cc"}]},
          {"matcher": "idle_prompt", "hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_hook.sh idle"}]}
        ],
        "SessionEnd": [{"hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_hook.sh off"}]}]
      }
    }
    """

    static let geminiMdContent = """
    # Desk Lamp Hook
    Run `bash ~/.claude/moonside_hooks/moonside_hook.sh working_ag` when starting work on a task.
    Run `bash ~/.claude/moonside_hooks/moonside_hook.sh input_ag` before asking user a question.
    Run `bash ~/.claude/moonside_hooks/moonside_hook.sh idle` when finished with a task or response.
    """

    static let codexHookScriptContent = """
    #!/usr/bin/env bash
    # Moonside LED hook for OpenAI Codex.
    # Codex hooks receive JSON on stdin and return JSON on stdout.
    # Always exits 0 to never block the caller.

    set -e

    STATE_FILE="/tmp/moonside_state"

    # Read stdin (Codex passes JSON with hook_event_name)
    INPUT="$(cat)"

    # Extract event name from JSON
    EVENT="$(echo "$INPUT" | grep -o '"hook_event_name":"[^"]*"' | head -1 | cut -d'"' -f4)"

    case "$EVENT" in
      SessionStart)
        printf '%s' "idle" > "$STATE_FILE"
        echo ""
        ;;
      UserPromptSubmit)
        printf '%s' "working_cx" > "$STATE_FILE"
        echo ""
        ;;
      PreToolUse)
        printf '%s' "working_cx" > "$STATE_FILE"
        echo '{"decision":"approve"}'
        ;;
      PostToolUse)
        printf '%s' "working_cx" > "$STATE_FILE"
        echo ""
        ;;
      Stop)
        printf '%s' "idle" > "$STATE_FILE"
        echo ""
        ;;
      *)
        printf '%s' "idle" > "$STATE_FILE"
        echo ""
        ;;
    esac

    exit 0
    """

    static let codexHooksJSON = """
    {
      "hooks": {
        "SessionStart": [{"hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_codex_hook.sh", "timeout": 5}]}],
        "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_codex_hook.sh", "timeout": 5}]}],
        "PreToolUse": [
          {"matcher": "Bash", "hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_codex_hook.sh", "timeout": 5}]},
          {"matcher": "Read", "hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_codex_hook.sh", "timeout": 5}]},
          {"matcher": "Write", "hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_codex_hook.sh", "timeout": 5}]},
          {"matcher": "Edit", "hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_codex_hook.sh", "timeout": 5}]}
        ],
        "Stop": [{"hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_codex_hook.sh", "timeout": 5}]}]
      }
    }
    """
}

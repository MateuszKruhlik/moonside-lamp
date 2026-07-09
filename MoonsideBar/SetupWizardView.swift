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
                          detail: "/tmp/moonside_cc (or _ag, _cx)"),
            ]
        case .antigravity:
            steps = [
                SetupStep(title: "Gemini CLI installed", status: .pending,
                          detail: "~/.gemini/ directory"),
                SetupStep(title: "Hook script installed", status: .pending,
                          detail: "~/.claude/moonside_hooks/moonside_ag_hook.sh"),
                SetupStep(title: "Lamp instructions in GEMINI.md", status: .pending,
                          detail: "~/.gemini/GEMINI.md"),
                SetupStep(title: "State file accessible", status: .pending,
                          detail: "/tmp/moonside_ag"),
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
                          detail: "/tmp/moonside_cc (or _ag, _cx)"),
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
           content.contains("moonside_resolve") {
            updateStep(1, status: .passed)
        } else {
            // Create directory and install hook
            do {
                try fm.createDirectory(atPath: hooksDir, withIntermediateDirectories: true)
                try Self.hookScriptContent.write(toFile: hookPath, atomically: true, encoding: .utf8)
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookPath)
                // Shared per-session aggregator (sourced by the hook)
                let resolvePath = hooksDir + "/moonside_resolve.sh"
                try Self.resolveScriptContent.write(toFile: resolvePath, atomically: true, encoding: .utf8)
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: resolvePath)
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
            // Merge hooks into settings.json — append per event, never replace the
            // user's existing hooks (replacing the whole "hooks" key would silently
            // wipe any hooks the user already configured).
            do {
                var settings: [String: Any] = [:]
                if let data = fm.contents(atPath: settingsPath),
                   let existing = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    settings = existing
                }
                let hooksData = Self.settingsHooksJSON.data(using: .utf8)!
                let hooksObj = try JSONSerialization.jsonObject(with: hooksData) as! [String: Any]
                let moonsideHooks = hooksObj["hooks"] as! [String: Any]

                var existingHooks = settings["hooks"] as? [String: Any] ?? [:]
                for (event, value) in moonsideHooks {
                    let moonsideEntries = value as? [Any] ?? []
                    if var eventEntries = existingHooks[event] as? [Any] {
                        // Append only entries not already present (canonical-JSON compare).
                        let present = Set(eventEntries.compactMap { Self.canonicalJSON($0) })
                        for entry in moonsideEntries {
                            if let key = Self.canonicalJSON(entry), present.contains(key) { continue }
                            eventEntries.append(entry)
                        }
                        existingHooks[event] = eventEntries
                    } else {
                        existingHooks[event] = moonsideEntries
                    }
                }
                settings["hooks"] = existingHooks

                let output = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
                try output.write(to: URL(fileURLWithPath: settingsPath))
                updateStep(2, status: .installed, detail: "Hooks merged into settings.json")
            } catch {
                updateStep(2, status: .failed, detail: "Failed: \(error.localizedDescription)")
            }
        }

        // Step 4: State file
        updateStep(3, status: .checking)
        let statePath = "/tmp/moonside_cc"
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
            do {
                try fm.createDirectory(atPath: geminiDir, withIntermediateDirectories: true)
                updateStep(0, status: .installed, detail: "Created ~/.gemini/")
            } catch {
                updateStep(0, status: .failed, detail: "Install Gemini CLI first")
                finishSetup()
                return
            }
        }

        // Step 2: Install AG hook script + shared per-session resolver
        updateStep(1, status: .checking)
        let hookDir = home + "/.claude/moonside_hooks"
        let agHookPath = hookDir + "/moonside_ag_hook.sh"
        do {
            try fm.createDirectory(atPath: hookDir, withIntermediateDirectories: true)
            try Self.agHookScriptContent.write(toFile: agHookPath, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: agHookPath)
            // Shared per-session aggregator (sourced by the hook) — same helper as cc/cx
            let resolvePath = hookDir + "/moonside_resolve.sh"
            try Self.resolveScriptContent.write(toFile: resolvePath, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: resolvePath)
            updateStep(1, status: .installed, detail: "moonside_ag_hook.sh + resolver")
        } catch {
            updateStep(1, status: .failed, detail: "Failed: \(error.localizedDescription)")
        }

        // Step 3: Add instructions to GEMINI.md
        updateStep(2, status: .checking)
        let geminiMdPath = geminiDir + "/GEMINI.md"

        if let data = fm.contents(atPath: geminiMdPath),
           let text = String(data: data, encoding: .utf8),
           text.contains("moonside_ag_hook") {
            updateStep(2, status: .passed)
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
                updateStep(2, status: .installed, detail: "Instructions added to GEMINI.md")
            } catch {
                updateStep(2, status: .failed, detail: "Failed: \(error.localizedDescription)")
            }
        }

        // Step 4: State file
        updateStep(3, status: .checking)
        let statePath = "/tmp/moonside_ag"
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
           content.contains("moonside_resolve") {
            updateStep(1, status: .passed)
        } else {
            do {
                try fm.createDirectory(atPath: hooksDir, withIntermediateDirectories: true)
                try Self.codexHookScriptContent.write(toFile: hookPath, atomically: true, encoding: .utf8)
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookPath)
                // Shared per-session aggregator (sourced by the hook)
                let resolvePath = hooksDir + "/moonside_resolve.sh"
                try Self.resolveScriptContent.write(toFile: resolvePath, atomically: true, encoding: .utf8)
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: resolvePath)
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
        let statePath = "/tmp/moonside_cx"
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

    /// Canonical JSON string of a hook entry, used for duplicate detection when
    /// merging moonside entries into an existing hooks array.
    private static func canonicalJSON(_ object: Any) -> String? {
        guard JSONSerialization.isValidJSONObject([object]),
              let data = try? JSONSerialization.data(withJSONObject: [object], options: [.sortedKeys]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

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

    static let hookScriptContent = #"""
    #!/usr/bin/env bash
    # Moonside LED hook for Claude Code (per-session aware).
    # Usage: moonside_hook.sh <working|idle|input_cc|off>
    # Reads session_id from the hook JSON on stdin so concurrent Claude Code
    # sessions don't clobber each other's lamp state. Always exits 0.

    STATE="${1:-idle}"

    # Pull session_id from the hook payload (stdin is a pipe when Claude runs us).
    SID="default"
    if [ ! -t 0 ]; then
      IFS= read -r -d '' INPUT 2>/dev/null || true
      if [[ "$INPUT" =~ \"session_id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
        SID="${BASH_REMATCH[1]}"
      fi
    fi

    case "$STATE" in
      working)  CAT=working ;;
      input_cc) CAT=input ;;
      off)      CAT=end ;;
      *)        CAT=idle ;;
    esac

    source "$HOME/.claude/moonside_hooks/moonside_resolve.sh"
    MS_SID="$SID" MS_CAT="$CAT" moonside_resolve cc

    exit 0
    """#

    static let resolveScriptContent = #"""
    #!/usr/bin/env bash
    # Moonside per-session state aggregator (sourced helper — defines a function only).
    #
    # Usage:  MS_SID=<session id> MS_CAT=<input|working|idle|end> moonside_resolve <cc|cx|ag>
    #
    # Each session writes its own file under /tmp/moonside_<agent>.d/. We then write
    # the highest-priority state across all live sessions (input > working > idle) to
    # the single /tmp/moonside_<agent> file the MoonsideBar app watches. This stops
    # concurrent sessions of one agent from clobbering each other (a finishing tab no
    # longer drags the lamp to idle while another tab is still working).
    #
    # Written with bash builtins so the hot path forks no extra processes.

    moonside_resolve() {
      local agent="$1"
      local sid="${MS_SID:-default}"
      local cat="${MS_CAT:-idle}"
      local dir="/tmp/moonside_${agent}.d"
      local out="/tmp/moonside_${agent}"

      # Sanitize the session id into a safe filename.
      sid="${sid//[^A-Za-z0-9_-]/_}"
      [ -n "$sid" ] || sid="default"

      [ -d "$dir" ] || mkdir -p "$dir" 2>/dev/null

      if [ "$cat" = "end" ]; then
        rm -f "$dir/$sid" 2>/dev/null
      else
        printf '%s' "$cat" > "$dir/$sid" 2>/dev/null
      fi

      # Prune orphaned session files (e.g. a crashed session stuck on "working").
      # Only on boundary events (idle/end), never on the per-tool hot path.
      case "$cat" in
        idle|end) find "$dir" -type f -mmin +1440 -delete 2>/dev/null ;;
      esac

      # Aggregate the highest-priority live state.
      local f s had_input=0 had_working=0 had_idle=0
      for f in "$dir"/*; do
        [ -e "$f" ] || continue
        s="$(<"$f")"
        case "$s" in
          input)   had_input=1 ;;
          working) had_working=1 ;;
          idle)    had_idle=1 ;;
        esac
      done

      local best
      if   [ "$had_input" = 1 ];   then best=input
      elif [ "$had_working" = 1 ]; then best=working
      elif [ "$had_idle" = 1 ];    then best=idle
      else best=off
      fi

      # Emit the agent-specific token the app understands.
      local tok
      case "$agent" in
        cc) case "$best" in input) tok=input_cc ;; working) tok=working    ;; idle) tok=idle ;; *) tok=off ;; esac ;;
        cx) case "$best" in input) tok=input_cx ;; working) tok=working_cx ;; idle) tok=idle ;; *) tok=off ;; esac ;;
        ag) case "$best" in input) tok=input_ag ;; working) tok=working_ag ;; *) tok=idle ;; esac ;;
        *)  tok="$best" ;;
      esac

      printf '%s' "$tok" > "$out" 2>/dev/null
      return 0
    }
    """#

    static let agHookScriptContent = """
    #!/usr/bin/env bash
    # Moonside LED hook for Antigravity (Gemini) — per-session aware.
    # Usage: moonside_ag_hook.sh <working_ag|input_ag|idle>
    # Gemini passes no session id, so we key the per-session bucket on the
    # controlling terminal (one tty per session) and fall back to "default"
    # (degrades to single-session last-wins). Always exits 0.

    STATE="${1:-idle}"

    # Per-session id from the controlling TTY (stable per terminal tab).
    SID="$(ps -o tty= -p $$ 2>/dev/null | tr -d '[:space:]')"
    case "$SID" in ""|"?"|"??") SID="default" ;; esac

    case "$STATE" in
      working_ag) CAT=working ;;
      input_ag)   CAT=input ;;
      *)          CAT=idle ;;
    esac

    source "$HOME/.claude/moonside_hooks/moonside_resolve.sh"
    MS_SID="$SID" MS_CAT="$CAT" moonside_resolve ag

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
          {"hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_hook.sh working"}]}
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
    Run `bash ~/.claude/moonside_hooks/moonside_ag_hook.sh working_ag` when starting work on a task.
    Run `bash ~/.claude/moonside_hooks/moonside_ag_hook.sh input_ag` before asking user a question.
    Run `bash ~/.claude/moonside_hooks/moonside_ag_hook.sh idle` when finished with a task or response.
    """

    static let codexHookScriptContent = #"""
    #!/usr/bin/env bash
    # Moonside LED hook for OpenAI Codex (per-session aware).
    # Codex hooks receive JSON on stdin and return JSON on stdout.
    # Always exits 0 so it can never block Codex.

    IFS= read -r -d '' INPUT 2>/dev/null || true

    EVENT=""
    if [[ "$INPUT" =~ \"hook_event_name\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
      EVENT="${BASH_REMATCH[1]}"
    fi

    # Codex's session field name isn't guaranteed; try the common keys, else fall
    # back to a shared bucket (degrades to single-session behaviour, never breaks).
    SID="default"
    if [[ "$INPUT" =~ \"session_id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
      SID="${BASH_REMATCH[1]}"
    elif [[ "$INPUT" =~ \"conversation_id\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
      SID="${BASH_REMATCH[1]}"
    fi

    case "$EVENT" in
      SessionStart)                          CAT=idle ;;
      UserPromptSubmit|PreToolUse|PostToolUse) CAT=working ;;
      Stop)                                  CAT=input ;;
      *)                                     CAT=idle ;;
    esac

    source "$HOME/.claude/moonside_hooks/moonside_resolve.sh"
    MS_SID="$SID" MS_CAT="$CAT" moonside_resolve cx

    echo ""
    exit 0
    """#

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

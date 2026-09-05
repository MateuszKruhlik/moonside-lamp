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
        let notifyPath = hooksDir + "/moonside_codex_notify.sh"
        let stateHelperPath = hooksDir + "/moonside_codex_state.sh"

        if fm.fileExists(atPath: hookPath),
           let content = try? String(contentsOfFile: hookPath, encoding: .utf8),
           content.contains("MOONSIDE_CODEX_HOOK_VERSION=5"),
           let notifyContent = try? String(contentsOfFile: notifyPath, encoding: .utf8),
           notifyContent.contains("MOONSIDE_CODEX_NOTIFY_VERSION=5"),
           let stateContent = try? String(contentsOfFile: stateHelperPath, encoding: .utf8),
           stateContent.contains("MOONSIDE_CODEX_STATE_VERSION=5") {
            updateStep(1, status: .passed)
        } else {
            do {
                try fm.createDirectory(atPath: hooksDir, withIntermediateDirectories: true)
                // Install the coordinator first so upgraded entry points never
                // observe a partially installed bundle.
                try Self.codexStateScriptContent.write(toFile: stateHelperPath, atomically: true, encoding: .utf8)
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: stateHelperPath)
                try Self.codexHookScriptContent.write(toFile: hookPath, atomically: true, encoding: .utf8)
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookPath)
                try Self.codexNotifyScriptContent.write(toFile: notifyPath, atomically: true, encoding: .utf8)
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: notifyPath)
                // Keep the shared resolver available for the other agent hooks.
                let resolvePath = hooksDir + "/moonside_resolve.sh"
                try Self.resolveScriptContent.write(toFile: resolvePath, atomically: true, encoding: .utf8)
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: resolvePath)
                updateStep(1, status: .installed, detail: "Codex scripts installed")
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

        do {
            let existingData = fm.contents(atPath: hooksJsonPath)
            let existingJson: [String: Any]
            if let existingData {
                existingJson = try JSONSerialization.jsonObject(with: existingData) as? [String: Any] ?? [:]
            } else {
                existingJson = [:]
            }

            let mergedJson = try Self.mergingCodexHooks(into: existingJson)
            if existingData != nil,
               Self.canonicalJSON(existingJson) == Self.canonicalJSON(mergedJson) {
                updateStep(3, status: .passed)
            } else {
                let output = try JSONSerialization.data(withJSONObject: mergedJson, options: [.prettyPrinted, .sortedKeys])
                try output.write(to: URL(fileURLWithPath: hooksJsonPath))
                updateStep(3, status: .installed, detail: "Hooks written to hooks.json")
            }
        } catch {
            updateStep(3, status: .failed, detail: "Failed: \(error.localizedDescription)")
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

    private static var codexHookCommands: Set<String> {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let script = "\(home)/.claude/moonside_hooks/moonside_codex_hook.sh"
        return [
            "bash ~/.claude/moonside_hooks/moonside_codex_hook.sh",
            "/bin/bash ~/.claude/moonside_hooks/moonside_codex_hook.sh",
            "bash \(script)",
            "/bin/bash \(script)",
            "bash \"\(script)\"",
            "/bin/bash \"\(script)\"",
            "bash '\(script)'",
            "/bin/bash '\(script)'",
        ]
    }

    private static func containsMoonsideCodexHook(_ object: Any) -> Bool {
        if let dictionary = object as? [String: Any] {
            if let command = dictionary["command"] as? String,
               codexHookCommands.contains(command) {
                return true
            }
            return dictionary.values.contains(where: containsMoonsideCodexHook)
        }
        if let array = object as? [Any] {
            return array.contains(where: containsMoonsideCodexHook)
        }
        return false
    }

    private static func mergingCodexHooks(into existingJson: [String: Any]) throws -> [String: Any] {
        let templateData = codexHooksJSON.data(using: .utf8)!
        let templateJson = try JSONSerialization.jsonObject(with: templateData) as! [String: Any]
        let requiredHooks = templateJson["hooks"] as! [String: Any]

        var result = existingJson
        var hooks = result["hooks"] as? [String: Any] ?? [:]

        // Drop an obsolete no-op event only when every registered handler is
        // ours. Keeping mixed events preserves foreign handler trust indexes.
        for event in ["SessionStart", "PreToolUse", "PostToolUse"] {
            guard let entries = hooks[event] as? [Any] else { continue }
            if !entries.isEmpty && entries.allSatisfy({ entry in
                guard let dictionary = entry as? [String: Any],
                      let handlers = dictionary["hooks"] as? [Any],
                      !handlers.isEmpty else { return false }
                return handlers.allSatisfy(containsMoonsideCodexHook)
            }) {
                hooks.removeValue(forKey: event)
            }
        }

        // Preserve every existing group and handler index. If our registration
        // is missing, append it after foreign entries so their trust keys stay
        // valid.
        for (event, value) in requiredHooks {
            let requiredEntries = value as? [Any] ?? []
            var entries = hooks[event] as? [Any] ?? []
            if !entries.contains(where: containsMoonsideCodexHook) {
                entries.append(contentsOf: requiredEntries)
            }
            hooks[event] = entries
        }

        result["hooks"] = hooks
        return result
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
    # Moonside hook entry point for persisted, user-facing Codex sessions.
    # Always exits 0 so a lamp integration can never block Codex.

    MOONSIDE_CODEX_HOOK_VERSION=5

    IFS= read -r -d '' PAYLOAD 2>/dev/null || true
    printf '%s' "$PAYLOAD" \
      | /bin/bash "$HOME/.claude/moonside_hooks/moonside_codex_state.sh" hook \
          >/dev/null 2>&1 \
      || true

    exit 0
    """#

    static let codexNotifyScriptContent = #"""
    #!/usr/bin/env bash
    # Moonside notify entry point for completed Codex turns.
    # Always exits 0 so a lamp integration can never block Codex.

    MOONSIDE_CODEX_NOTIFY_VERSION=5

    PAYLOAD="$*"
    if [ -z "$PAYLOAD" ] && [ ! -t 0 ]; then
      IFS= read -r -d '' PAYLOAD 2>/dev/null || true
    fi

    printf '%s' "$PAYLOAD" \
      | /bin/bash "$HOME/.claude/moonside_hooks/moonside_codex_state.sh" notify \
          >/dev/null 2>&1 \
      || true

    exit 0
    """#

    static let codexStateScriptContent = #"""
    #!/usr/bin/env bash
    # Serialized state coordinator for persisted, user-facing Codex sessions.
    # Payloads arrive on stdin. No payload or identifier is logged.

    MOONSIDE_CODEX_STATE_VERSION=5

    MODE="${1:-}"
    LOCKED="${2:-}"
    LOCK_FILE="/tmp/moonside_cx.lock"
    BUCKET_DIR="/tmp/moonside_cx.d"
    TURN_DIR="/tmp/moonside_cx.turns"
    STATE_FILE="/tmp/moonside_cx"
    DB_PATH="${CODEX_HOME:-$HOME/.codex}/state_5.sqlite"

    case "$MODE" in hook|notify) ;; *) exit 0 ;; esac
    IFS= read -r -d '' PAYLOAD 2>/dev/null || true

    # lockf owns the kernel lock for the whole parse, validate, prune, mutate and
    # aggregate transaction. A pre-start timeout leaves state untouched, and the
    # kernel releases the lock whenever the coordinator exits or crashes.
    if [ "$LOCKED" != "--locked" ]; then
      printf '%s' "$PAYLOAD" \
        | /usr/bin/lockf -k -t 2 "$LOCK_FILE" /bin/bash "$0" "$MODE" --locked \
            >/dev/null 2>&1 \
        || true
      exit 0
    fi

    json_string() {
      printf '%s' "$PAYLOAD" \
        | /usr/bin/plutil -extract "$1" raw -expect string -n -o - - 2>/dev/null
    }

    has_key() {
      printf '%s' "$PAYLOAD" | /usr/bin/plutil -type "$1" - >/dev/null 2>&1
    }

    is_safe_id() {
      case "$1" in
        ""|*[!A-Za-z0-9_-]*) return 1 ;;
        *) return 0 ;;
      esac
    }

    read_hook_sid() {
      if has_key session_id; then
        SID="$(json_string session_id)"
      elif has_key thread_id; then
        SID="$(json_string thread_id)"
      elif has_key thread-id; then
        SID="$(json_string thread-id)"
      elif has_key conversation_id; then
        SID="$(json_string conversation_id)"
      fi
    }

    read_notify_sid() {
      if has_key thread-id; then
        SID="$(json_string thread-id)"
      elif has_key thread_id; then
        SID="$(json_string thread_id)"
      elif has_key session_id; then
        SID="$(json_string session_id)"
      elif has_key conversation_id; then
        SID="$(json_string conversation_id)"
      fi
    }

    read_turn_id() {
      TURN_PRESENT=0
      if has_key turn_id; then
        TURN_PRESENT=1
        TURN_ID="$(json_string turn_id)"
      elif has_key turn-id; then
        TURN_PRESENT=1
        TURN_ID="$(json_string turn-id)"
      fi
    }

    load_user_ids() {
      DB_READ_OK=0
      ROOT_IDS=""
      ACTIVE_USER_IDS=""
      [ -f "$DB_PATH" ] || return 1
      local rows id active
      rows="$(/usr/bin/sqlite3 -batch -noheader -readonly "$DB_PATH" \
          "SELECT id, CASE WHEN COALESCE(archived, 0) = 0 THEN 1 ELSE 0 END
             FROM threads
            WHERE thread_source = 'user'
               OR (thread_source IS NULL AND source = 'vscode');" 2>/dev/null)" \
        || return 1

      while IFS='|' read -r id active; do
        is_safe_id "$id" || continue
        ROOT_IDS="${ROOT_IDS}${ROOT_IDS:+$'\n'}${id}"
        if [ "$active" = 1 ]; then
          ACTIVE_USER_IDS="${ACTIVE_USER_IDS}${ACTIVE_USER_IDS:+$'\n'}${id}"
        fi
      done <<< "$rows"
      DB_READ_OK=1
      return 0
    }

    id_in_list() {
      local wanted="$1" ids="$2" candidate
      while IFS= read -r candidate; do
        [ "$candidate" = "$wanted" ] && return 0
      done <<< "$ids"
      return 1
    }

    is_persisted_root() { id_in_list "$1" "$ROOT_IDS"; }
    is_active_root() { id_in_list "$1" "$ACTIVE_USER_IDS"; }

    atomic_write() {
      local destination="$1" value="$2" temporary="${1}.tmp.$$"
      if printf '%s' "$value" > "$temporary" 2>/dev/null \
          && /bin/mv -f "$temporary" "$destination" 2>/dev/null; then
        return 0
      fi
      /bin/rm -f "$temporary" 2>/dev/null
      return 1
    }

    prune_orphans() {
      local file sid
      [ "$DB_READ_OK" = 1 ] || return 0

      for file in "$BUCKET_DIR"/*; do
        [ -f "$file" ] || continue
        sid="${file##*/}"
        if ! is_active_root "$sid"; then
          /bin/rm -f "$file" "$TURN_DIR/$sid" 2>/dev/null
        fi
      done

      for file in "$TURN_DIR"/*; do
        [ -f "$file" ] || continue
        sid="${file##*/}"
        if ! is_active_root "$sid" || [ ! -f "$BUCKET_DIR/$sid" ]; then
          /bin/rm -f "$file" 2>/dev/null
        fi
      done
    }

    aggregate() {
      local file state had_input=0 had_working=0 had_idle=0 token
      for file in "$BUCKET_DIR"/*; do
        [ -f "$file" ] || continue
        state="$(<"$file")"
        case "$state" in
          input) had_input=1 ;;
          working) had_working=1 ;;
          idle) had_idle=1 ;;
        esac
      done

      if [ "$had_input" = 1 ]; then
        token=input_cx
      elif [ "$had_working" = 1 ]; then
        token=working_cx
      elif [ "$had_idle" = 1 ]; then
        token=idle
      else
        token=off
      fi
      printf '%s' "$token" > "$STATE_FILE" 2>/dev/null
    }

    ACTION=""
    SID=""
    TURN_ID=""
    TURN_PRESENT=0
    DB_READ_OK=0
    ROOT_IDS=""
    ACTIVE_USER_IDS=""

    if [ "$MODE" = hook ]; then
      EVENT="$(json_string hook_event_name)"
      case "$EVENT" in
        UserPromptSubmit) ACTION=start ;;
        Stop|Interrupt) ACTION=complete ;;
        SessionEnd) ACTION=end ;;
        SessionStart|PreToolUse|PostToolUse) exit 0 ;;
        *) exit 0 ;;
      esac
      read_hook_sid
    else
      TYPE="$(json_string type)"
      [ "$TYPE" = agent-turn-complete ] || exit 0
      ACTION=complete
      read_notify_sid
    fi

    is_safe_id "$SID" || exit 0
    if [ "$ACTION" != end ]; then
      read_turn_id
      if [ "$TURN_PRESENT" = 1 ]; then
        is_safe_id "$TURN_ID" || exit 0
      fi
    fi

    BUCKET="$BUCKET_DIR/$SID"
    TURN_FILE="$TURN_DIR/$SID"

    if [ "$ACTION" = start ]; then
      # A start is accepted only for a persisted root conversation. Ephemeral
      # internals and subagents have no matching user row and remain invisible.
      load_user_ids || exit 0
      is_active_root "$SID" || exit 0
      /bin/mkdir -p "$BUCKET_DIR" "$TURN_DIR" 2>/dev/null || exit 0
      prune_orphans

      if [ "$TURN_PRESENT" = 1 ]; then
        atomic_write "$TURN_FILE" "$TURN_ID" || exit 0
      else
        # Legacy starts without a turn id can only be completed by a matching
        # legacy completion. They cannot safely protect against delayed events.
        /bin/rm -f "$TURN_FILE" 2>/dev/null
      fi
      atomic_write "$BUCKET" working || exit 0
      aggregate
      exit 0
    fi

    if [ "$ACTION" = end ]; then
      if [ ! -f "$BUCKET" ]; then
        load_user_ids || exit 0
        is_persisted_root "$SID" || exit 0
      fi
      /bin/rm -f "$BUCKET" "$TURN_FILE" 2>/dev/null
      if [ "$DB_READ_OK" != 1 ]; then
        load_user_ids || true
      fi
      prune_orphans
      aggregate
      exit 0
    fi

    # Turn completions never create a bucket. A bucket proves an earlier start
    # was accepted; database failure therefore does not prevent safe completion.
    if [ ! -f "$BUCKET" ]; then
      load_user_ids || exit 0
      is_persisted_root "$SID" || exit 0
      prune_orphans
      aggregate
      exit 0
    fi
    if [ -f "$TURN_FILE" ]; then
      [ "$TURN_PRESENT" = 1 ] || exit 0
      CURRENT_TURN="$(<"$TURN_FILE")"
      [ "$CURRENT_TURN" = "$TURN_ID" ] || exit 0
    fi

    # Buckets migrated from v3 have no turn sidecar. Their completion is accepted
    # with or without a turn id, but legacy events have no ordering guarantee.
    if load_user_ids; then
      prune_orphans
      if [ ! -f "$BUCKET" ]; then
        aggregate
        exit 0
      fi
    fi

    atomic_write "$BUCKET" idle || exit 0
    aggregate
    exit 0
    """#

    static let codexHooksJSON = """
    {
      "hooks": {
        "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_codex_hook.sh", "timeout": 5}]}],
        "Stop": [{"hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_codex_hook.sh", "timeout": 5}]}],
        "Interrupt": [{"hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_codex_hook.sh", "timeout": 3}]}],
        "SessionEnd": [{"hooks": [{"type": "command", "command": "bash ~/.claude/moonside_hooks/moonside_codex_hook.sh", "timeout": 3}]}]
      }
    }
    """
}

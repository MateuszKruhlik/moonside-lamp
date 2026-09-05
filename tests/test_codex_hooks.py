import json
from pathlib import Path
import re
import subprocess
import tempfile
import textwrap
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
HOOK = REPO_ROOT / "scripts" / "moonside_codex_hook.sh"
NOTIFY = REPO_ROOT / "scripts" / "moonside_codex_notify.sh"
WIZARD = REPO_ROOT / "MoonsideBar" / "SetupWizardView.swift"


def embedded_raw_literal(name):
    match = re.search(
        rf'static let {name} = #"""\n(.*?)\n    """#',
        WIZARD.read_text(),
        re.DOTALL,
    )
    if match is None:
        raise AssertionError(f"Missing Swift raw literal: {name}")
    return textwrap.dedent(match.group(1)) + "\n"


class CodexHookBehaviorTests(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)
        self.home = self.root / "home"
        self.state_root = self.root / "state"
        hooks_dir = self.home / ".claude" / "moonside_hooks"
        hooks_dir.mkdir(parents=True)
        self.state_root.mkdir()

        def isolated_copy(content, destination):
            content = content.replace(
                "/tmp/moonside_", str(self.state_root / "moonside_")
            )
            destination.write_text(content)

        isolated_copy(
            embedded_raw_literal("resolveScriptContent"),
            hooks_dir / "moonside_resolve.sh",
        )
        self.hook = self.root / "moonside_codex_hook.sh"
        self.notify = self.root / "moonside_codex_notify.sh"
        isolated_copy(HOOK.read_text(), self.hook)
        isolated_copy(NOTIFY.read_text(), self.notify)

        self.env = {"HOME": str(self.home), "PATH": "/usr/bin:/bin"}

    def tearDown(self):
        self.tempdir.cleanup()

    def run_hook(self, payload):
        result = subprocess.run(
            ["/bin/bash", str(self.hook)],
            input=json.dumps(payload),
            text=True,
            capture_output=True,
            env=self.env,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def run_notify(self, payload, *, stdin=False):
        encoded = json.dumps(payload)
        command = ["/bin/bash", str(self.notify)]
        if not stdin:
            command.append(encoded)
        result = subprocess.run(
            command,
            input=encoded if stdin else None,
            text=True,
            capture_output=True,
            env=self.env,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return result

    def state(self):
        state_file = self.state_root / "moonside_cx"
        return state_file.read_text() if state_file.exists() else None

    def bucket(self, sid):
        safe_sid = re.sub(r"[^A-Za-z0-9_-]", "_", sid)
        bucket_file = self.state_root / "moonside_cx.d" / safe_sid
        return bucket_file.read_text() if bucket_file.exists() else None

    def test_stop_marks_completed_response_idle(self):
        self.run_hook({"hook_event_name": "UserPromptSubmit", "session_id": "alpha"})
        self.assertEqual(self.state(), "working_cx")

        self.run_hook({"hook_event_name": "Stop", "session_id": "alpha"})

        self.assertEqual(self.state(), "idle")
        self.assertEqual(self.bucket("alpha"), "idle")

    def test_notify_agent_turn_complete_uses_thread_dash_id(self):
        self.run_hook({"hook_event_name": "UserPromptSubmit", "thread_id": "thread-42"})

        self.run_notify({"type": "agent-turn-complete", "thread-id": "thread-42"})

        self.assertEqual(self.state(), "idle")
        self.assertEqual(self.bucket("thread-42"), "idle")

    def test_completed_session_does_not_override_another_working_session(self):
        self.run_hook({"hook_event_name": "UserPromptSubmit", "session_id": "alpha"})
        self.run_hook({"hook_event_name": "UserPromptSubmit", "session_id": "beta"})

        self.run_hook({"hook_event_name": "Stop", "session_id": "alpha"})

        self.assertEqual(self.bucket("alpha"), "idle")
        self.assertEqual(self.bucket("beta"), "working")
        self.assertEqual(self.state(), "working_cx")

    def test_notify_completion_does_not_override_another_working_session(self):
        self.run_hook({"hook_event_name": "UserPromptSubmit", "thread_id": "alpha"})
        self.run_hook({"hook_event_name": "UserPromptSubmit", "thread_id": "beta"})

        self.run_notify({"type": "agent-turn-complete", "thread-id": "alpha"})

        self.assertEqual(self.bucket("alpha"), "idle")
        self.assertEqual(self.bucket("beta"), "working")
        self.assertEqual(self.state(), "working_cx")

    def test_unknown_hook_event_is_no_op(self):
        self.run_hook({"hook_event_name": "UserPromptSubmit", "session_id": "alpha"})

        self.run_hook({"hook_event_name": "FutureEvent", "session_id": "alpha"})

        self.assertEqual(self.state(), "working_cx")
        self.assertEqual(self.bucket("alpha"), "working")

    def test_unknown_notify_type_is_no_op(self):
        self.run_hook({"hook_event_name": "UserPromptSubmit", "session_id": "alpha"})

        self.run_notify({"type": "future-event", "session_id": "alpha"})

        self.assertEqual(self.state(), "working_cx")
        self.assertEqual(self.bucket("alpha"), "working")

    def test_notify_without_session_id_is_no_op(self):
        self.run_hook({"hook_event_name": "UserPromptSubmit", "session_id": "alpha"})

        self.run_notify({"type": "agent-turn-complete"}, stdin=True)

        self.assertEqual(self.state(), "working_cx")
        self.assertEqual(self.bucket("alpha"), "working")

    def test_legacy_session_and_conversation_ids_remain_supported(self):
        for key, sid in (("session_id", "legacy-session"), ("conversation_id", "legacy-conversation")):
            with self.subTest(key=key):
                self.run_hook({"hook_event_name": "UserPromptSubmit", key: sid})
                self.assertEqual(self.bucket(sid), "working")
                self.run_notify({"type": "agent-turn-complete", key: sid})
                self.assertEqual(self.bucket(sid), "idle")

    def test_hook_without_session_id_is_no_op(self):
        self.run_hook({"hook_event_name": "UserPromptSubmit"})

        self.assertIsNone(self.state())


class CodexHookSourceTests(unittest.TestCase):
    def test_scripts_do_not_log_payloads(self):
        for script in (HOOK, NOTIFY):
            with self.subTest(script=script.name):
                content = script.read_text()
                self.assertNotIn("moonside_debug.log", content)
                self.assertNotIn("RAW=%q", content)
                self.assertNotIn("PAYLOAD=%q", content)
                self.assertNotIn("> /tmp/moonside_cx", content)

    def test_embedded_hook_matches_source_script(self):
        self.assertEqual(
            embedded_raw_literal("codexHookScriptContent"),
            HOOK.read_text(),
        )

    def test_wizard_uses_unambiguous_v2_install_marker(self):
        wizard = WIZARD.read_text()
        codex_setup = wizard.split("private func runCodexSetup()", 1)[1].split(
            "// MARK: - Helpers", 1
        )[0]
        self.assertIn('content.contains("MOONSIDE_CODEX_HOOK_VERSION=2")', codex_setup)
        self.assertEqual(wizard.count('content.contains("MOONSIDE_CODEX_HOOK_VERSION=2")'), 1)
        self.assertIn("MOONSIDE_CODEX_HOOK_VERSION=2", HOOK.read_text())


if __name__ == "__main__":
    unittest.main()

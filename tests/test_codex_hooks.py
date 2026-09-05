import json
from pathlib import Path
import re
import shutil
import sqlite3
import subprocess
import tempfile
import textwrap
from concurrent.futures import ThreadPoolExecutor
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
HOOK = REPO_ROOT / "scripts" / "moonside_codex_hook.sh"
NOTIFY = REPO_ROOT / "scripts" / "moonside_codex_notify.sh"
STATE = REPO_ROOT / "scripts" / "moonside_codex_state.sh"
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


def embedded_string_literal(name):
    match = re.search(
        rf'static let {name} = """\n(.*?)\n    """',
        WIZARD.read_text(),
        re.DOTALL,
    )
    if match is None:
        raise AssertionError(f"Missing Swift string literal: {name}")
    return textwrap.dedent(match.group(1))


class CodexHookBehaviorTests(unittest.TestCase):
    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)
        self.home = self.root / "home"
        self.state_root = self.root / "state"
        self.codex_home = self.root / "codex"
        hooks_dir = self.home / ".claude" / "moonside_hooks"
        hooks_dir.mkdir(parents=True)
        self.state_root.mkdir()
        self.codex_home.mkdir()
        self.database = self.codex_home / "state_5.sqlite"

        connection = sqlite3.connect(self.database)
        try:
            connection.execute(
                """CREATE TABLE threads (
                    id TEXT PRIMARY KEY,
                    thread_source TEXT,
                    source TEXT,
                    archived INTEGER NOT NULL DEFAULT 0
                )"""
            )
            connection.executemany(
                """INSERT INTO threads (id, thread_source, source, archived)
                   VALUES (?, 'user', 'vscode', 0)""",
                [
                    (sid,)
                    for sid in (
                        "alpha",
                        "beta",
                        "legacy-session",
                        "legacy-conversation",
                        "parent",
                        "thread-42",
                        "worker",
                        *(f"root-{index}" for index in range(12)),
                    )
                ],
            )
            connection.execute(
                """INSERT INTO threads (id, thread_source, source, archived)
                   VALUES ('child', 'subagent', 'vscode', 0)"""
            )
            connection.execute(
                """INSERT INTO threads (id, thread_source, source, archived)
                   VALUES ('legacy-vscode', NULL, 'vscode', 0)"""
            )
            connection.execute(
                """INSERT INTO threads (id, thread_source, source, archived)
                   VALUES ('legacy-archived', NULL, 'vscode', 1)"""
            )
            connection.commit()
        finally:
            connection.close()

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
        self.state_helper = hooks_dir / "moonside_codex_state.sh"
        isolated_copy(HOOK.read_text(), self.hook)
        isolated_copy(NOTIFY.read_text(), self.notify)
        if STATE.exists():
            isolated_copy(STATE.read_text(), self.state_helper)

        self.env = {
            "CODEX_HOME": str(self.codex_home),
            "HOME": str(self.home),
            "PATH": "/usr/bin:/bin",
        }

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

    def turn(self, sid):
        safe_sid = re.sub(r"[^A-Za-z0-9_-]", "_", sid)
        turn_file = self.state_root / "moonside_cx.turns" / safe_sid
        return turn_file.read_text() if turn_file.exists() else None

    def reset_state(self):
        for path in (
            self.state_root / "moonside_cx",
            self.state_root / "moonside_cx.lock",
        ):
            path.unlink(missing_ok=True)
        for path in (
            self.state_root / "moonside_cx.d",
            self.state_root / "moonside_cx.turns",
        ):
            shutil.rmtree(path, ignore_errors=True)

    def test_stop_marks_completed_response_idle(self):
        self.run_hook({"hook_event_name": "UserPromptSubmit", "session_id": "alpha"})
        self.assertEqual(self.state(), "working_cx")

        self.run_hook({"hook_event_name": "Stop", "session_id": "alpha"})

        self.assertEqual(self.state(), "idle")
        self.assertEqual(self.bucket("alpha"), "idle")

    def test_tool_events_do_not_reanimate_completed_session(self):
        self.run_hook({"hook_event_name": "UserPromptSubmit", "session_id": "alpha"})
        self.run_hook({"hook_event_name": "Stop", "session_id": "alpha"})

        for event in ("PreToolUse", "PostToolUse"):
            with self.subTest(event=event):
                self.run_hook({"hook_event_name": event, "session_id": "alpha"})
                self.assertEqual(self.state(), "idle")
                self.assertEqual(self.bucket("alpha"), "idle")

    def test_tool_event_does_not_interrupt_active_session(self):
        self.run_hook({"hook_event_name": "UserPromptSubmit", "session_id": "alpha"})

        self.run_hook({"hook_event_name": "PreToolUse", "session_id": "alpha"})

        self.assertEqual(self.state(), "working_cx")
        self.assertEqual(self.bucket("alpha"), "working")

    def test_only_persisted_user_root_can_start_working(self):
        for sid in ("internal", "child", "legacy-archived"):
            with self.subTest(sid=sid):
                self.reset_state()
                self.run_hook({"hook_event_name": "UserPromptSubmit", "session_id": sid})
                self.assertIsNone(self.state())
                self.assertIsNone(self.bucket(sid))

    def test_legacy_vscode_root_with_null_thread_source_can_start(self):
        self.run_hook(
            {"hook_event_name": "UserPromptSubmit", "session_id": "legacy-vscode"}
        )

        self.assertEqual(self.bucket("legacy-vscode"), "working")
        self.assertEqual(self.state(), "working_cx")

    def test_nested_or_malformed_session_id_has_no_effect(self):
        payloads = (
            {"hook_event_name": "UserPromptSubmit", "metadata": {"session_id": "alpha"}},
            {
                "hook_event_name": "UserPromptSubmit",
                "session_id": "alpha' OR '1'='1",
            },
        )
        for payload in payloads:
            with self.subTest(payload=payload):
                self.reset_state()
                self.run_hook(payload)
                self.assertIsNone(self.state())

    def test_canonical_hook_session_id_prevents_legacy_fallback(self):
        self.run_hook(
            {
                "hook_event_name": "UserPromptSubmit",
                "session_id": "child",
                "thread_id": "alpha",
            }
        )

        self.assertIsNone(self.state())
        self.assertIsNone(self.bucket("alpha"))

    def test_missing_database_fails_closed_without_creating_database(self):
        self.database.unlink()

        self.run_hook({"hook_event_name": "UserPromptSubmit", "session_id": "alpha"})

        self.assertFalse(self.database.exists())
        self.assertIsNone(self.state())

    def test_schema_mismatch_fails_closed(self):
        self.database.unlink()
        connection = sqlite3.connect(self.database)
        try:
            connection.execute("CREATE TABLE unrelated (id TEXT PRIMARY KEY)")
            connection.commit()
        finally:
            connection.close()

        self.run_hook({"hook_event_name": "UserPromptSubmit", "session_id": "alpha"})

        self.assertIsNone(self.state())

    def test_database_failure_never_prunes_existing_buckets(self):
        bucket_dir = self.state_root / "moonside_cx.d"
        bucket_dir.mkdir()
        (bucket_dir / "alpha").write_text("working")
        (bucket_dir / "orphan").write_text("input")
        (self.state_root / "moonside_cx").write_text("input_cx")
        self.database.unlink()

        self.run_hook({"hook_event_name": "Stop", "session_id": "alpha"})

        self.assertEqual(self.bucket("alpha"), "idle")
        self.assertEqual(self.bucket("orphan"), "input")
        self.assertEqual(self.state(), "input_cx")

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

    def test_late_tool_event_does_not_change_completed_parent_bucket(self):
        self.run_hook({"hook_event_name": "UserPromptSubmit", "session_id": "parent"})
        self.run_hook({"hook_event_name": "Stop", "session_id": "parent"})
        self.run_hook({"hook_event_name": "UserPromptSubmit", "session_id": "worker"})

        self.run_hook({"hook_event_name": "PreToolUse", "session_id": "parent"})

        self.assertEqual(self.bucket("parent"), "idle")
        self.assertEqual(self.bucket("worker"), "working")
        self.assertEqual(self.state(), "working_cx")

    def test_boundary_prunes_orphan_but_retains_persisted_active_root(self):
        bucket_dir = self.state_root / "moonside_cx.d"
        turn_dir = self.state_root / "moonside_cx.turns"
        bucket_dir.mkdir()
        turn_dir.mkdir()
        (bucket_dir / "alpha").write_text("working")
        (turn_dir / "alpha").write_text("turn-alpha")
        (bucket_dir / "orphan").write_text("working")
        (turn_dir / "orphan").write_text("turn-orphan")

        self.run_hook(
            {
                "hook_event_name": "UserPromptSubmit",
                "session_id": "beta",
                "turn_id": "turn-beta",
            }
        )

        self.assertEqual(self.bucket("alpha"), "working")
        self.assertEqual(self.turn("alpha"), "turn-alpha")
        self.assertEqual(self.bucket("beta"), "working")
        self.assertIsNone(self.bucket("orphan"))
        self.assertIsNone(self.turn("orphan"))

    def test_completion_for_different_session_does_not_create_idle_bucket(self):
        self.run_hook(
            {
                "hook_event_name": "UserPromptSubmit",
                "session_id": "alpha",
                "turn_id": "turn-alpha",
            }
        )

        self.run_hook(
            {
                "hook_event_name": "Stop",
                "session_id": "beta",
                "turn_id": "turn-alpha",
            }
        )

        self.assertEqual(self.bucket("alpha"), "working")
        self.assertIsNone(self.bucket("beta"))
        self.assertEqual(self.state(), "working_cx")

    def test_completion_from_old_turn_does_not_idle_newer_turn(self):
        self.run_hook(
            {
                "hook_event_name": "UserPromptSubmit",
                "session_id": "alpha",
                "turn_id": "turn-1",
            }
        )
        self.run_hook(
            {
                "hook_event_name": "UserPromptSubmit",
                "session_id": "alpha",
                "turn_id": "turn-2",
            }
        )

        self.run_hook(
            {
                "hook_event_name": "Stop",
                "session_id": "alpha",
                "turn_id": "turn-1",
            }
        )
        self.assertEqual(self.bucket("alpha"), "working")
        self.assertEqual(self.turn("alpha"), "turn-2")

        self.run_hook(
            {
                "hook_event_name": "Stop",
                "session_id": "alpha",
                "turn_id": "turn-2",
            }
        )
        self.assertEqual(self.bucket("alpha"), "idle")

    def test_completion_without_turn_id_does_not_idle_tracked_turn(self):
        self.run_hook(
            {
                "hook_event_name": "UserPromptSubmit",
                "session_id": "alpha",
                "turn_id": "turn-1",
            }
        )

        self.run_hook({"hook_event_name": "Stop", "session_id": "alpha"})

        self.assertEqual(self.bucket("alpha"), "working")
        self.assertEqual(self.turn("alpha"), "turn-1")

    def test_notify_completes_untracked_v3_bucket_even_with_turn_id(self):
        bucket_dir = self.state_root / "moonside_cx.d"
        bucket_dir.mkdir()
        (bucket_dir / "alpha").write_text("working")
        (self.state_root / "moonside_cx").write_text("working_cx")

        self.run_notify(
            {
                "type": "agent-turn-complete",
                "thread-id": "alpha",
                "turn-id": "turn-from-notify",
            }
        )

        self.assertEqual(self.bucket("alpha"), "idle")
        self.assertEqual(self.state(), "idle")

    def test_persisted_boundary_without_bucket_prunes_orphan_and_reaggregates(self):
        bucket_dir = self.state_root / "moonside_cx.d"
        turn_dir = self.state_root / "moonside_cx.turns"
        bucket_dir.mkdir()
        turn_dir.mkdir()
        (bucket_dir / "orphan").write_text("working")
        (turn_dir / "orphan").write_text("turn-orphan")
        (self.state_root / "moonside_cx").write_text("working_cx")

        self.run_notify({"type": "agent-turn-complete", "thread-id": "alpha"})

        self.assertIsNone(self.bucket("orphan"))
        self.assertIsNone(self.turn("orphan"))
        self.assertEqual(self.state(), "off")

    def test_interrupt_completes_only_matching_turn(self):
        self.run_hook(
            {
                "hook_event_name": "UserPromptSubmit",
                "session_id": "alpha",
                "turn_id": "turn-current",
            }
        )

        self.run_hook(
            {
                "hook_event_name": "Interrupt",
                "session_id": "alpha",
                "turn_id": "turn-old",
            }
        )
        self.assertEqual(self.bucket("alpha"), "working")

        self.run_hook(
            {
                "hook_event_name": "Interrupt",
                "session_id": "alpha",
                "turn_id": "turn-current",
            }
        )
        self.assertEqual(self.bucket("alpha"), "idle")

    def test_session_end_removes_bucket_and_turn_without_turn_match(self):
        self.run_hook(
            {
                "hook_event_name": "UserPromptSubmit",
                "session_id": "alpha",
                "turn_id": "turn-alpha",
            }
        )
        self.run_hook({"hook_event_name": "UserPromptSubmit", "session_id": "beta"})

        self.run_hook(
            {
                "hook_event_name": "SessionEnd",
                "session_id": "alpha",
                "turn_id": "different-turn",
            }
        )

        self.assertIsNone(self.bucket("alpha"))
        self.assertIsNone(self.turn("alpha"))
        self.assertEqual(self.bucket("beta"), "working")
        self.assertEqual(self.state(), "working_cx")

    def test_session_end_accepts_archived_persisted_root_without_bucket(self):
        bucket_dir = self.state_root / "moonside_cx.d"
        bucket_dir.mkdir()
        (bucket_dir / "orphan").write_text("working")
        (self.state_root / "moonside_cx").write_text("working_cx")

        self.run_hook(
            {"hook_event_name": "SessionEnd", "session_id": "legacy-archived"}
        )

        self.assertIsNone(self.bucket("orphan"))
        self.assertEqual(self.state(), "off")

    def test_rejected_old_turn_does_not_publish_partially_pruned_state(self):
        self.run_hook(
            {
                "hook_event_name": "UserPromptSubmit",
                "session_id": "alpha",
                "turn_id": "turn-new",
            }
        )
        bucket_dir = self.state_root / "moonside_cx.d"
        turn_dir = self.state_root / "moonside_cx.turns"
        (bucket_dir / "orphan").write_text("input")
        (turn_dir / "orphan").write_text("turn-orphan")
        (self.state_root / "moonside_cx").write_text("input_cx")

        self.run_hook(
            {
                "hook_event_name": "Stop",
                "session_id": "alpha",
                "turn_id": "turn-old",
            }
        )

        self.assertEqual(self.bucket("alpha"), "working")
        self.assertEqual(self.bucket("orphan"), "input")
        self.assertEqual(self.state(), "input_cx")

    def test_concurrent_start_and_stop_produce_consistent_final_state(self):
        for _ in range(12):
            self.run_hook({"hook_event_name": "Stop", "session_id": "alpha"})
            self.run_hook({"hook_event_name": "UserPromptSubmit", "session_id": "beta"})

            with ThreadPoolExecutor(max_workers=2) as executor:
                futures = (
                    executor.submit(
                        self.run_hook,
                        {"hook_event_name": "UserPromptSubmit", "session_id": "alpha"},
                    ),
                    executor.submit(
                        self.run_hook,
                        {"hook_event_name": "Stop", "session_id": "beta"},
                    ),
                )
                for future in futures:
                    future.result()

            self.assertEqual(self.bucket("alpha"), "working")
            self.assertEqual(self.bucket("beta"), "idle")
            self.assertEqual(self.state(), "working_cx")

    def test_twelve_concurrent_roots_do_not_drop_boundaries(self):
        roots = [f"root-{index}" for index in range(12)]

        with ThreadPoolExecutor(max_workers=len(roots)) as executor:
            futures = [
                executor.submit(
                    self.run_hook,
                    {"hook_event_name": "UserPromptSubmit", "session_id": sid},
                )
                for sid in roots
            ]
            for future in futures:
                future.result()

        for sid in roots:
            self.assertEqual(self.bucket(sid), "working")
        self.assertEqual(self.state(), "working_cx")

        with ThreadPoolExecutor(max_workers=len(roots)) as executor:
            futures = [
                executor.submit(
                    self.run_hook,
                    {"hook_event_name": "Stop", "session_id": sid},
                )
                for sid in roots
            ]
            for future in futures:
                future.result()

        for sid in roots:
            self.assertEqual(self.bucket(sid), "idle")
        self.assertEqual(self.state(), "idle")

    def test_notify_completion_does_not_override_another_working_session(self):
        self.run_hook({"hook_event_name": "UserPromptSubmit", "thread_id": "alpha"})
        self.run_hook({"hook_event_name": "UserPromptSubmit", "thread_id": "beta"})

        self.run_notify({"type": "agent-turn-complete", "thread-id": "alpha"})

        self.assertEqual(self.bucket("alpha"), "idle")
        self.assertEqual(self.bucket("beta"), "working")
        self.assertEqual(self.state(), "working_cx")

    def test_notify_thread_id_prevents_legacy_fallback(self):
        self.run_hook({"hook_event_name": "UserPromptSubmit", "session_id": "alpha"})

        self.run_notify(
            {
                "type": "agent-turn-complete",
                "thread-id": "beta",
                "session_id": "alpha",
            }
        )

        self.assertEqual(self.bucket("alpha"), "working")
        self.assertIsNone(self.bucket("beta"))
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

    def test_unknown_notify_does_not_create_bucket(self):
        self.run_notify(
            {"type": "future-event", "thread-id": "alpha", "turn-id": "turn-1"}
        )

        self.assertIsNone(self.state())
        self.assertIsNone(self.bucket("alpha"))

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

    def test_stop_and_notify_do_not_create_phantom_idle_bucket(self):
        self.run_hook({"hook_event_name": "Stop", "session_id": "alpha"})
        self.run_notify({"type": "agent-turn-complete", "thread-id": "beta"})

        self.assertEqual(self.state(), "off")
        self.assertIsNone(self.bucket("alpha"))
        self.assertIsNone(self.bucket("beta"))

    def test_wrappers_write_no_stdout(self):
        start = self.run_hook(
            {"hook_event_name": "UserPromptSubmit", "session_id": "alpha"}
        )
        stop = self.run_hook({"hook_event_name": "Stop", "session_id": "alpha"})
        notify = self.run_notify(
            {"type": "agent-turn-complete", "thread-id": "alpha"}
        )

        self.assertEqual(start.stdout, "")
        self.assertEqual(stop.stdout, "")
        self.assertEqual(notify.stdout, "")


class CodexHookSourceTests(unittest.TestCase):
    def test_scripts_do_not_log_payloads(self):
        for script in (HOOK, NOTIFY, STATE):
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

    def test_embedded_state_and_notify_match_source_scripts(self):
        self.assertTrue(STATE.exists())
        self.assertEqual(
            embedded_raw_literal("codexStateScriptContent"),
            STATE.read_text(),
        )
        self.assertEqual(
            embedded_raw_literal("codexNotifyScriptContent"),
            NOTIFY.read_text(),
        )

    def test_state_mutations_are_serialized_with_lockf(self):
        self.assertTrue(STATE.exists())
        state = STATE.read_text()
        self.assertIn("/usr/bin/lockf", state)
        self.assertIn("/tmp/moonside_cx.lock", state)

    def test_wizard_installs_all_codex_scripts(self):
        wizard = WIZARD.read_text()
        codex_setup = wizard.split("private func runCodexSetup()", 1)[1].split(
            "// MARK: - Helpers", 1
        )[0]
        for name in (
            "moonside_codex_hook.sh",
            "moonside_codex_notify.sh",
            "moonside_codex_state.sh",
        ):
            with self.subTest(name=name):
                self.assertIn(name, codex_setup)
        self.assertLess(
            codex_setup.index("Self.codexStateScriptContent.write"),
            codex_setup.index("Self.codexHookScriptContent.write"),
        )

    def test_codex_hook_template_registers_only_state_boundaries(self):
        template = json.loads(embedded_string_literal("codexHooksJSON"))
        self.assertEqual(
            set(template["hooks"]),
            {"UserPromptSubmit", "Stop", "Interrupt", "SessionEnd"},
        )
        self.assertEqual(template["hooks"]["Interrupt"][0]["hooks"][0]["timeout"], 3)
        self.assertEqual(template["hooks"]["SessionEnd"][0]["hooks"][0]["timeout"], 3)

    def test_swift_upgrade_merge_preserves_foreign_hooks_and_updates_moonside(self):
        wizard = WIZARD.read_text()
        helper_start = wizard.index("    private static var codexHookCommands")
        helper_end = wizard.index("    private func updateStep", helper_start)
        helper_source = textwrap.dedent(wizard[helper_start:helper_end])
        template = embedded_string_literal("codexHooksJSON")
        swift_source = f'''import Foundation

struct Harness {{
    static let codexHooksJSON = #"""
{template}
"""#

{textwrap.indent(helper_source, "    ")}
    static func mergeForTest(_ input: [String: Any]) throws -> [String: Any] {{
        try mergingCodexHooks(into: input)
    }}
}}

let inputData = FileHandle.standardInput.readDataToEndOfFile()
let input = try JSONSerialization.jsonObject(with: inputData) as! [String: Any]
let output = try Harness.mergeForTest(input)
let outputData = try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys])
FileHandle.standardOutput.write(outputData)
'''
        own_handler = {
            "type": "command",
            "command": "bash ~/.claude/moonside_hooks/moonside_codex_hook.sh",
            "timeout": 5,
            "trustId": "keep-trust",
        }
        installed_handler = {
            "type": "command",
            "command": (
                f"/bin/bash {Path.home()}/.claude/moonside_hooks/"
                "moonside_codex_hook.sh"
            ),
            "timeout": 5,
            "trustId": "keep-installed-trust",
        }
        foreign_handler = {"type": "command", "command": "bash ~/foreign.sh"}
        own = {"hooks": [own_handler]}
        installed = {"hooks": [installed_handler]}
        foreign = {"hooks": [foreign_handler]}
        mixed = {"matcher": "Bash", "hooks": [own_handler, foreign_handler]}
        fixture = {
            "custom": {"preserve": True},
            "hooks": {
                "SessionStart": [own, foreign],
                "PreToolUse": [mixed],
                "PostToolUse": [own],
                "UserPromptSubmit": [installed, foreign, own],
                "Stop": [own],
                "SessionEnd": [foreign],
                "OtherEvent": [foreign],
            },
        }

        with tempfile.TemporaryDirectory() as directory:
            script = Path(directory) / "merge.swift"
            script.write_text(swift_source)
            result = subprocess.run(
                ["/usr/bin/swift", str(script)],
                input=json.dumps(fixture),
                text=True,
                capture_output=True,
                check=False,
            )

        self.assertEqual(result.returncode, 0, result.stderr)
        merged = json.loads(result.stdout)
        self.assertEqual(merged["custom"], fixture["custom"])
        self.assertEqual(merged["hooks"]["SessionStart"], [own, foreign])
        self.assertEqual(merged["hooks"]["PreToolUse"], [mixed])
        self.assertNotIn("PostToolUse", merged["hooks"])
        self.assertEqual(
            merged["hooks"]["UserPromptSubmit"], [installed, foreign, own]
        )
        self.assertEqual(merged["hooks"]["Stop"], [own])
        self.assertEqual(merged["hooks"]["OtherEvent"], [foreign])
        self.assertIn("Interrupt", merged["hooks"])
        self.assertEqual(merged["hooks"]["SessionEnd"][0], foreign)
        self.assertEqual(len(merged["hooks"]["SessionEnd"]), 2)

    def test_wizard_uses_unambiguous_v5_install_marker(self):
        wizard = WIZARD.read_text()
        codex_setup = wizard.split("private func runCodexSetup()", 1)[1].split(
            "// MARK: - Helpers", 1
        )[0]
        self.assertIn('content.contains("MOONSIDE_CODEX_HOOK_VERSION=5")', codex_setup)
        self.assertEqual(wizard.count('content.contains("MOONSIDE_CODEX_HOOK_VERSION=5")'), 1)
        self.assertIn("MOONSIDE_CODEX_HOOK_VERSION=5", HOOK.read_text())


if __name__ == "__main__":
    unittest.main()

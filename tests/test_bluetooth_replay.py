import os
import re
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
BLUETOOTH_SOURCE = Path(
    os.environ.get(
        "MOONSIDE_BLUETOOTH_SOURCE",
        REPO_ROOT / "MoonsideBar" / "BluetoothManager.swift",
    )
)


HARNESS_SOURCE = r"""
import Foundation

func pumpRunLoop(for duration: TimeInterval) {
    let deadline = Date().addingTimeInterval(duration)
    while Date() < deadline {
        RunLoop.main.run(mode: .default, before: deadline)
    }
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(1)
    }
}

let scenario = CommandLine.arguments[1]
let replay = CommandReplayScheduler()
var sent: [String] = []

switch scenario {
case "connected-idle-supersedes-offline-replay":
    replay.schedule(["LEDON", "THEME.BEAT2"], spacing: 0.06) { sent.append($0) }
    // Mirrors the synchronous AppState callback published when RX becomes ready.
    replay.cancelPending()
    sent.append("LEDON")
    sent.append("COLOR255255255")
    sent.append("BRIGH050")
    pumpRunLoop(for: 0.15)
    require(sent == ["LEDON", "COLOR255255255", "BRIGH050"],
            "offline history ran after the connected callback applied idle: \(sent)")

case "fresh-idle-cancels-stale-theme":
    replay.schedule(["LEDON", "THEME.BEAT2"], spacing: 0.06) { sent.append($0) }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
        replay.cancelPending()
        sent.append("LEDON")
        sent.append("COLOR255255255")
        sent.append("BRIGH050")
    }
    pumpRunLoop(for: 0.15)
    require(sent.suffix(3) == ["LEDON", "COLOR255255255", "BRIGH050"],
            "a stale replay command ran after the fresh idle batch: \(sent)")
    require(!sent.suffix(from: sent.firstIndex(of: "COLOR255255255")!).contains("THEME.BEAT2"),
            "the old working theme overwrote idle: \(sent)")

case "uninterrupted-replay":
    replay.schedule(["LEDON", "THEME.BEAT2"], spacing: 0.01) { sent.append($0) }
    pumpRunLoop(for: 0.08)
    require(sent == ["LEDON", "THEME.BEAT2"],
            "an uninterrupted replay did not preserve command order: \(sent)")

default:
    FileHandle.standardError.write(Data("unknown scenario\n".utf8))
    exit(2)
}
"""


class BluetoothReplayTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = BLUETOOTH_SOURCE.read_text()
        match = re.search(
            r"// TESTABLE-BEGIN: CommandReplayScheduler\n"
            r"(.*?)"
            r"// TESTABLE-END: CommandReplayScheduler",
            source,
            re.DOTALL,
        )
        if match is None:
            raise AssertionError("BluetoothManager is missing the testable replay scheduler")

        cls.tempdir = tempfile.TemporaryDirectory()
        cls.root = Path(cls.tempdir.name)
        main_source = cls.root / "main.swift"
        main_source.write_text(
            "import Foundation\n\n"
            + match.group(1)
            + "\n"
            + textwrap.dedent(HARNESS_SOURCE).removeprefix("import Foundation\n")
        )
        cls.executable = cls.root / "bluetooth-replay-harness"
        result = subprocess.run(
            ["swiftc", str(main_source), "-o", str(cls.executable)],
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            raise AssertionError(result.stderr)

        # Type-check the complete production file too. Defaults is replaced only
        # in this temporary copy because the standalone compiler does not resolve
        # the app's Swift Package dependencies.
        manager_source = cls.root / "BluetoothManager.swift"
        manager_source.write_text(
            source.replace("import Defaults\n", "").replace(
                "Defaults[.deviceUUID]", "testDeviceUUID"
            )
        )
        app_stubs = cls.root / "AppStubs.swift"
        app_stubs.write_text(
            textwrap.dedent(
                """
                import Foundation

                var testDeviceUUID = ""

                enum ConnectionStatus {
                    case disconnected, connecting, connected, unauthorized
                }

                enum BLECommand {
                    static let ledOn = "LEDON"
                    static let ledOff = "LEDOFF"
                }
                """
            )
        )
        result = subprocess.run(
            ["swiftc", "-typecheck", str(manager_source), str(app_stubs)],
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            raise AssertionError(result.stderr)

    @classmethod
    def tearDownClass(cls):
        if hasattr(cls, "tempdir"):
            cls.tempdir.cleanup()

    def run_scenario(self, scenario):
        result = subprocess.run(
            [str(self.executable), scenario],
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_fresh_idle_cancels_delayed_working_theme(self):
        self.run_scenario("fresh-idle-cancels-stale-theme")

    def test_connected_idle_supersedes_offline_working_replay(self):
        self.run_scenario("connected-idle-supersedes-offline-replay")

    def test_uninterrupted_replay_preserves_commands(self):
        self.run_scenario("uninterrupted-replay")

    def test_bluetooth_manager_routes_live_and_replayed_commands_through_gate(self):
        source = BLUETOOTH_SOURCE.read_text()
        send_body = source.split("func send(_ command: String)", 1)[1].split("func connect()", 1)[0]
        flush_body = source.split("private func flushQueue()", 1)[1].split(
            "// MARK: - CBCentralManagerDelegate", 1
        )[0]
        self.assertIn("commandReplay.cancelPending()", send_body)
        self.assertIn("commandReplay.schedule(queued", flush_body)

    def test_connection_schedules_history_before_publishing_current_state(self):
        source = BLUETOOTH_SOURCE.read_text()
        ready_body = source.split(
            "func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor", 1
        )[1]
        replay_position = ready_body.index("flushQueue()")
        connected_position = ready_body.index("onConnectionStatusChanged?(.connected)")
        self.assertLess(replay_position, connected_position)


if __name__ == "__main__":
    unittest.main()

import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
MONITOR_SOURCE = REPO_ROOT / "MoonsideBar" / "StateFileMonitor.swift"


HARNESS_SOURCE = r"""
import Foundation

enum LampState: String {
    case idle
    case working
    case workingAG = "working_ag"
    case workingCX = "working_cx"
    case inputCC = "input_cc"
    case inputAG = "input_ag"
    case inputCX = "input_cx"
    case off
}

func pumpRunLoop(for duration: TimeInterval) {
    let deadline = Date().addingTimeInterval(duration)
    while Date() < deadline {
        RunLoop.main.run(mode: .default, before: deadline)
    }
}

func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return true }
        RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
    }
    return condition()
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(1)
    }
}

let scenario = CommandLine.arguments[1]
let root = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("state-file-monitor-test-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: root) }
let stateURL = root.appendingPathComponent("state")

switch scenario {
case "initial-read":
    try "working_cx".write(to: stateURL, atomically: false, encoding: .utf8)
    let monitor = StateFileMonitor(path: stateURL.path)
    var seen: [LampState] = []
    monitor.onStateChange = { seen.append($0) }
    monitor.start()
    require(seen.last == .workingCX, "start() did not synchronously publish the initial state")
    monitor.stop()
    pumpRunLoop(for: 0.05)

case "restart":
    try "idle".write(to: stateURL, atomically: false, encoding: .utf8)
    let monitor = StateFileMonitor(path: stateURL.path)
    var seen: [LampState] = []
    monitor.onStateChange = { seen.append($0) }
    monitor.start()
    monitor.stop()
    monitor.start()
    pumpRunLoop(for: 0.05)
    try "working_cx".write(to: stateURL, atomically: false, encoding: .utf8)
    require(waitUntil(timeout: 0.5) { seen.last == .workingCX },
            "a cancelled source closed the descriptor owned by the restarted monitor")
    monitor.stop()
    pumpRunLoop(for: 0.05)

case "rename-then-write":
    try "idle".write(to: stateURL, atomically: false, encoding: .utf8)
    let monitor = StateFileMonitor(path: stateURL.path)
    var seen: [LampState] = []
    monitor.onStateChange = { seen.append($0) }
    monitor.start()
    try "input_cx".write(to: stateURL, atomically: true, encoding: .utf8)
    require(waitUntil(timeout: 0.7) { seen.last == .inputCX },
            "monitor did not reattach after an atomic rename replacement")
    try "working_cx".write(to: stateURL, atomically: false, encoding: .utf8)
    require(waitUntil(timeout: 0.5) { seen.last == .workingCX },
            "reattached monitor did not observe the subsequent write")
    monitor.stop()
    pumpRunLoop(for: 0.05)

case "stop-cancels-retry":
    try "working_cx".write(to: stateURL, atomically: false, encoding: .utf8)
    let monitor = StateFileMonitor(path: stateURL.path)
    var seen: [LampState] = []
    monitor.onStateChange = { seen.append($0) }
    monitor.start()
    try FileManager.default.removeItem(at: stateURL)
    pumpRunLoop(for: 0.03)
    monitor.stop()
    let countAtStop = seen.count
    pumpRunLoop(for: 0.5)
    require(!FileManager.default.fileExists(atPath: stateURL.path),
            "a delayed retry recreated the file after stop()")
    require(seen.count == countAtStop,
            "a delayed retry resurrected callbacks after stop()")

default:
    FileHandle.standardError.write(Data("unknown scenario\n".utf8))
    exit(2)
}
"""


class StateFileMonitorBehaviorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tempdir = tempfile.TemporaryDirectory()
        cls.root = Path(cls.tempdir.name)
        harness_source = cls.root / "main.swift"
        harness_source.write_text(textwrap.dedent(HARNESS_SOURCE))
        cls.executable = cls.root / "state-file-monitor-harness"
        result = subprocess.run(
            [
                "swiftc",
                str(MONITOR_SOURCE),
                str(harness_source),
                "-o",
                str(cls.executable),
            ],
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            raise AssertionError(result.stderr)

    @classmethod
    def tearDownClass(cls):
        cls.tempdir.cleanup()

    def run_scenario(self, scenario):
        result = subprocess.run(
            [str(self.executable), scenario],
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_reads_initial_state(self):
        self.run_scenario("initial-read")

    def test_restart_keeps_new_watcher_alive(self):
        self.run_scenario("restart")

    def test_rename_replacement_keeps_following_writes_observable(self):
        self.run_scenario("rename-then-write")

    def test_stop_cancels_pending_reattach(self):
        self.run_scenario("stop-cancels-retry")


if __name__ == "__main__":
    unittest.main()

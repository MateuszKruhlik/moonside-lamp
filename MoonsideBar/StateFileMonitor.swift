import Foundation

final class StateFileMonitor {

    private let path = "/tmp/moonside_state"
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1

    var onStateChange: ((LampState) -> Void)?

    func start() {
        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: "idle".data(using: .utf8))
        }

        watchFile()
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    // MARK: - Private

    private func watchFile() {
        // Clean up previous source if any
        source?.cancel()
        if fileDescriptor >= 0 {
            close(fileDescriptor)
        }

        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        source?.setEventHandler { [weak self] in
            guard let self else { return }
            let event = self.source?.data ?? []

            if event.contains(.delete) || event.contains(.rename) {
                // File was replaced — re-watch after short delay
                self.source?.cancel()
                if self.fileDescriptor >= 0 {
                    close(self.fileDescriptor)
                    self.fileDescriptor = -1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.watchFile()
                }
                return
            }

            self.readState()
        }

        source?.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        source?.resume()

        // Read initial state
        readState()
    }

    private func readState() {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines) else { return }

        if let state = LampState(rawValue: content) {
            onStateChange?(state)
        }
    }

    deinit {
        stop()
    }
}

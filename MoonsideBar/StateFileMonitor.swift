import Foundation

final class StateFileMonitor {

    private let path: String
    private var source: DispatchSourceFileSystemObject?
    private var generation: UInt = 0
    private var nextSourceID: UInt = 0
    private var activeSourceID: UInt?
    private var isRunning = false

    var onStateChange: ((LampState) -> Void)?

    init(path: String = "/tmp/moonside_state") {
        self.path = path
    }

    func start() {
        generation &+= 1
        let currentGeneration = generation
        isRunning = true

        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: "idle".data(using: .utf8))
        }

        watchFile(generation: currentGeneration)
    }

    func stop() {
        isRunning = false
        generation &+= 1
        activeSourceID = nil
        let sourceToCancel = source
        source = nil
        sourceToCancel?.cancel()
    }

    // MARK: - Private

    private func watchFile(generation expectedGeneration: UInt, retryOnFailure: Bool = true) {
        guard isRunning, generation == expectedGeneration else { return }

        // Clean up previous source if any
        activeSourceID = nil
        let previousSource = source
        source = nil
        previousSource?.cancel()

        let fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            // The file can be briefly gone after a delete/rename event — losing
            // the watch here would silently kill the monitor for good. Recreate
            // the file (like start() does) and retry once after a short delay.
            guard retryOnFailure else { return }
            if !FileManager.default.fileExists(atPath: path) {
                FileManager.default.createFile(atPath: path, contents: "idle".data(using: .utf8))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.watchFile(generation: expectedGeneration, retryOnFailure: false)
            }
            return
        }

        nextSourceID &+= 1
        let sourceID = nextSourceID
        let newSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        newSource.setEventHandler { [weak self] in
            guard let self,
                  self.isRunning,
                  self.generation == expectedGeneration,
                  self.activeSourceID == sourceID else { return }
            let event = self.source?.data ?? []

            if event.contains(.delete) || event.contains(.rename) {
                // File was replaced — re-watch after short delay
                self.activeSourceID = nil
                let replacedSource = self.source
                self.source = nil
                replacedSource?.cancel()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.watchFile(generation: expectedGeneration)
                }
                return
            }

            self.readState()
        }

        // The source owns this exact descriptor for its whole lifetime. Capturing
        // it by value prevents an older cancel handler from closing a newer watch.
        newSource.setCancelHandler {
            close(fileDescriptor)
        }

        source = newSource
        activeSourceID = sourceID
        newSource.resume()

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

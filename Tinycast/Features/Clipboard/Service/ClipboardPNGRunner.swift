import Foundation

/// Re-encodes a copied TIFF as PNG in `ClipboardTextHelper`, so a 5K bitmap never lands in the app.
nonisolated enum ClipboardPNGRunner {
    /// The wait blocks, so it stays off the cooperative pool.
    private static let queue = DispatchQueue(label: "com.tinycast.clipboard-png", qos: .utility)

    /// Nil when the helper fails or overruns `timeout`; the caller decides whether to encode itself.
    static func png(
        fromTIFF tiff: Data, helper: URL = ClipboardTextWorker.executable,
        timeout: DispatchTimeInterval = .seconds(30)
    ) async -> Data? {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: encode(tiff, helper: helper, timeout: timeout))
            }
        }
    }

    private static func encode(_ tiff: Data, helper: URL, timeout: DispatchTimeInterval) -> Data? {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("tinycast-clipboard-\(UUID().uuidString)")
        let source = base.appendingPathExtension("tiff")
        let destination = base.appendingPathExtension("png")
        defer {
            try? FileManager.default.removeItem(at: source)
            try? FileManager.default.removeItem(at: destination)
        }
        guard (try? tiff.write(to: source)) != nil else { return nil }
        let process = Process()
        process.executableURL = helper
        process.arguments = ["png", source.path, destination.path]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard let exit = try? process.runObservingExit() else { return nil }
        let deadline = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: deadline)
        exit.wait()
        deadline.cancel()
        guard process.terminationStatus == 0 else { return nil }
        // Mapped: the pages stay file-backed, and the unlink in `defer` leaves the mapping intact.
        return try? Data(contentsOf: destination, options: .alwaysMapped)
    }
}

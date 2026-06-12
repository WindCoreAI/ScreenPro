import Foundation
import os.signpost

// MARK: - Performance Monitor (007-cloud-polish)

/// Lightweight signpost-based instrumentation for the performance targets in
/// docs/milestones/00-overview.md (capture < 50ms, overlay < 200ms, etc.).
/// Intervals show up in Instruments under the "Performance" category.
final class PerformanceMonitor: @unchecked Sendable {
    static let shared = PerformanceMonitor()

    private let log = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "com.yourcompany.ScreenPro",
        category: "Performance"
    )
    private let lock = NSLock()
    private var signpostIDs: [String: OSSignpostID] = [:]

    private init() {}

    /// Begins a named signpost interval.
    func begin(_ name: StaticString, id key: String) {
        let id = OSSignpostID(log: log)
        lock.lock()
        signpostIDs[key] = id
        lock.unlock()
        os_signpost(.begin, log: log, name: name, signpostID: id, "%{public}s", key)
    }

    /// Ends a previously begun signpost interval.
    func end(_ name: StaticString, id key: String) {
        lock.lock()
        let id = signpostIDs.removeValue(forKey: key)
        lock.unlock()
        guard let id else { return }
        os_signpost(.end, log: log, name: name, signpostID: id, "%{public}s", key)
    }

    /// Measures a synchronous operation.
    func measure<T>(_ name: StaticString, id key: String, _ operation: () throws -> T) rethrows -> T {
        begin(name, id: key)
        defer { end(name, id: key) }
        return try operation()
    }

    /// Measures an asynchronous operation.
    func measureAsync<T>(
        _ name: StaticString,
        id key: String,
        _ operation: () async throws -> T
    ) async rethrows -> T {
        begin(name, id: key)
        defer { end(name, id: key) }
        return try await operation()
    }
}

// MARK: - Memory Pressure Handling

/// Observes system memory pressure and invokes cleanup callbacks so the app
/// can shed caches (thumbnails, frozen-screen images) under pressure.
@MainActor
final class MemoryPressureHandler {
    static let shared = MemoryPressureHandler()

    enum Level {
        case warning
        case critical
    }

    private var source: DispatchSourceMemoryPressure?

    private init() {}

    func startMonitoring(onPressure: @escaping @MainActor (Level) -> Void) {
        stopMonitoring()

        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )

        source.setEventHandler { [weak source] in
            guard let source else { return }
            let level: Level = source.data.contains(.critical) ? .critical : .warning
            // Handler runs on the main queue, which is the main actor's executor.
            MainActor.assumeIsolated {
                onPressure(level)
            }
        }

        source.resume()
        self.source = source
    }

    func stopMonitoring() {
        source?.cancel()
        source = nil
    }
}

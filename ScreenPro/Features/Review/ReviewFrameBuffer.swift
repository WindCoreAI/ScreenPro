import Foundation
import CoreMedia
import CoreImage
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// MARK: - Frame providing seam (unit tests inject stubs — research.md R10)

protocol ReviewFrameProviding: AnyObject, Sendable {
    /// Most recent frame (manual flags).
    func latestFrame() -> CGImage?
    /// Frame whose capture time is closest to `time` (voice notes resolve to
    /// the utterance start, which is slightly in the past).
    func frame(nearest time: TimeInterval) -> CGImage?
}

// MARK: - ReviewFrameBuffer (008-review-recording)
//
// Consumes RecordingService.videoFrameTap samples on the stream's sample
// queue and keeps a small ring of recent frames so flags and utterance
// starts can resolve to what was on screen at that moment (research.md R3).
//
// Invariants:
// - Never retains the stream's CVPixelBuffers (the SCStream pool is fixed
//   size; holding buffers stalls capture). Frames are converted to immutable
//   CGImages at copy time.
// - Copies at most one frame per `sampleInterval`, bounding cost on the
//   real-time sample path.

final class ReviewFrameBuffer: ReviewFrameProviding, @unchecked Sendable {
    private struct Entry {
        let time: TimeInterval
        let image: CGImage
    }

    private let lock = NSLock()
    private var ring: [Entry] = []
    private let capacity: Int
    private let sampleInterval: TimeInterval
    private let clock: RecordedTimeClock
    private var lastSampleAt: TimeInterval = -.greatestFiniteMagnitude
    private let ciContext = CIContext(options: [.cacheIntermediates: false])

    init(clock: RecordedTimeClock, capacity: Int = 5, sampleInterval: TimeInterval = 0.5) {
        self.clock = clock
        self.capacity = capacity
        self.sampleInterval = sampleInterval
    }

    /// Called from RecordingService.videoFrameTap on the sample-handler queue.
    func ingest(_ sampleBuffer: CMSampleBuffer) {
        let now = clock.now

        lock.lock()
        let due = now - lastSampleAt >= sampleInterval
        if due { lastSampleAt = now }
        lock.unlock()

        guard due, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // CIContext.createCGImage copies the pixels; the stream buffer is
        // released as soon as this returns.
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return }

        lock.lock()
        ring.append(Entry(time: now, image: cgImage))
        if ring.count > capacity {
            ring.removeFirst(ring.count - capacity)
        }
        lock.unlock()
    }

    func latestFrame() -> CGImage? {
        lock.lock(); defer { lock.unlock() }
        return ring.last?.image
    }

    func frame(nearest time: TimeInterval) -> CGImage? {
        lock.lock(); defer { lock.unlock() }
        return ring.min { abs($0.time - time) < abs($1.time - time) }?.image
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        ring.removeAll()
        lastSampleAt = -.greatestFiniteMagnitude
    }

    // MARK: - PNG export

    /// Writes a frame as PNG. Call off the main actor (ReviewSessionService
    /// wraps this in a background task per flag).
    static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ) else {
            throw ReviewReportError.encodingFailed("cannot create PNG destination at \(url.lastPathComponent)")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ReviewReportError.encodingFailed("PNG encode failed for \(url.lastPathComponent)")
        }
    }
}

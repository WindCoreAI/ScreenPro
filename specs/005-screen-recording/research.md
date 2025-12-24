# Research: Screen Recording

**Feature**: 005-screen-recording
**Date**: 2025-12-23

## Overview

This document captures research findings for implementing screen recording in ScreenPro. All technical decisions align with the project's constitution requiring native Apple frameworks only.

---

## 1. ScreenCaptureKit for Video Capture

### Decision
Use `SCStream` with `SCStreamOutput` protocol for continuous frame capture during recording.

### Rationale
- ScreenCaptureKit is Apple's modern replacement for deprecated CGWindowListCreateImage
- Provides hardware-accelerated capture with minimal CPU overhead
- Supports both screen and audio capture in a unified API
- Required for macOS 14+ (Sonoma) as per constitution

### Best Practices
- Use `SCStreamConfiguration` to set resolution, frame rate, and pixel format
- Set `minimumFrameInterval` based on target FPS (e.g., CMTime(value: 1, timescale: 30) for 30fps)
- Enable `capturesAudio` for system audio capture (no audio drivers needed on macOS 13+)
- Use `queueDepth` of 5-8 frames to handle encoding latency spikes
- Implement `SCStreamDelegate` for error handling and stream lifecycle

### Alternatives Considered
| Alternative | Rejected Because |
|-------------|------------------|
| AVCaptureScreenInput | Deprecated, less flexible than ScreenCaptureKit |
| CGDisplayStream | Lower-level, more complex, no audio support |

---

## 2. AVAssetWriter for Video Encoding

### Decision
Use `AVAssetWriter` with `AVAssetWriterInput` for real-time H.264 encoding to MP4.

### Rationale
- Native Apple framework for media writing
- Hardware-accelerated H.264 encoding via VideoToolbox
- Supports real-time encoding with `expectsMediaDataInRealTime = true`
- Handles audio/video synchronization internally

### Best Practices
- Create separate `AVAssetWriterInput` for video and audio tracks
- Use `AVAssetWriterInputPixelBufferAdaptor` for efficient pixel buffer handling
- Configure video compression properties:
  - `AVVideoCodecKey`: `.h264`
  - `AVVideoProfileLevelKey`: `AVVideoProfileLevelH264HighAutoLevel`
  - `AVVideoAverageBitRateKey`: Scale based on resolution and quality
- Start session at first frame's presentation time to ensure proper timing
- Mark inputs as finished before calling `finishWriting()`

### Bitrate Guidelines
| Resolution | Low | Medium | High | Maximum |
|------------|-----|--------|------|---------|
| 480p | 1.25 Mbps | 1.9 Mbps | 2.5 Mbps | 3.75 Mbps |
| 720p | 2.5 Mbps | 3.75 Mbps | 5 Mbps | 7.5 Mbps |
| 1080p | 5 Mbps | 7.5 Mbps | 10 Mbps | 15 Mbps |
| 4K | 17.5 Mbps | 26 Mbps | 35 Mbps | 52.5 Mbps |

### Alternatives Considered
| Alternative | Rejected Because |
|-------------|------------------|
| Direct VideoToolbox | More complex, AVAssetWriter provides sufficient control |
| FFmpeg | External dependency violates constitution |

---

## 3. Audio Capture Architecture

### Decision
- System audio: Use ScreenCaptureKit's built-in audio capture (`SCStreamOutputType.audio`)
- Microphone: Use `AVAudioEngine` with `inputNode` for microphone capture

### Rationale
- ScreenCaptureKit audio capture requires no kernel extensions or audio drivers
- AVAudioEngine provides modern, low-latency microphone access
- Both sources can be written to the same AVAssetWriter audio track

### Best Practices
- Request microphone permission only when user enables mic recording
- Install tap on `AVAudioEngine.inputNode` for microphone audio
- Use consistent sample rate (44100 Hz) and channel count (stereo) for both sources
- Mix audio sources before writing if both enabled:
  - Option A: Mix at sample buffer level before writing
  - Option B: Write to separate audio tracks (simpler, lets player handle mix)
- Encode audio as AAC at 128kbps for good quality/size balance

### Audio Synchronization
- Use presentation timestamps from CMSampleBuffer for both video and audio
- Start AVAssetWriter session at first video frame timestamp
- Audio naturally syncs via timestamps when written to same writer

### Alternatives Considered
| Alternative | Rejected Because |
|-------------|------------------|
| Core Audio directly | More complex, AVAudioEngine sufficient |
| Third-party audio libraries | External dependency violates constitution |

---

## 4. GIF Encoding with ImageIO

### Decision
Use `CGImageDestination` with `kUTTypeGIF` for animated GIF creation.

### Rationale
- Native ImageIO framework, no external dependencies
- Direct control over frame timing and loop count
- Produces standard GIF format compatible everywhere

### Best Practices
- Set file-level property `kCGImagePropertyGIFLoopCount` (0 = infinite)
- Set per-frame properties:
  - `kCGImagePropertyGIFDelayTime`: Frame delay in seconds
  - `kCGImagePropertyGIFUnclampedDelayTime`: For delays < 0.1s
- Capture frames at lower FPS than video (10-15 fps typical for GIF)
- Scale down frames to reduce file size (50-75% of original)
- Limit color palette naturally via GIF format (256 colors max)

### File Size Optimization
- Lower frame rate: 10-15 fps vs 30 fps
- Reduce resolution: Scale to 50-75%
- Shorter duration: GIFs work best for 5-15 second clips
- Consider frame skipping for very long recordings

### Alternatives Considered
| Alternative | Rejected Because |
|-------------|------------------|
| APNG | Less universal support than GIF |
| WebP | Less compatible, not native to ImageIO |

---

## 5. Recording Controls Window

### Decision
Use `NSWindow` with `.floating` level and SwiftUI content for recording controls.

### Rationale
- Consistent with existing Quick Access overlay pattern
- NSWindow provides precise control over window behavior
- SwiftUI enables reactive UI updates for timer and state

### Best Practices
- Window configuration:
  - `level = .floating` to stay above other windows
  - `styleMask = [.borderless]` for custom appearance
  - `isMovableByWindowBackground = true` for dragging
  - `collectionBehavior = [.canJoinAllSpaces, .stationary]` to persist across spaces
  - `ignoresMouseEvents = false` (user needs to interact)
- Position at top-center of screen by default
- Use capsule shape with dark semi-transparent background
- Show: recording indicator (red dot), duration timer, pause/resume, stop buttons
- Pulsing animation on recording indicator when actively recording

### Accessibility
- All buttons must have accessibility labels
- Recording state announced via `NSAccessibility.post(notification:)`
- Timer updates announced at reasonable intervals (not every 100ms)

---

## 6. Click Visualization Overlay

### Decision
Use `NSWindow` at `.screenSaver` level with `ignoresMouseEvents = true` for click visualization.

### Rationale
- Window at .screenSaver level renders above all content
- ignoresMouseEvents ensures clicks pass through to underlying windows
- Can capture clicks via `NSEvent.addGlobalMonitorForEvents`

### Best Practices
- Monitor both `.leftMouseDown` and `.rightMouseDown` events
- Create animated ring at click position:
  - Left click: Blue ring
  - Right click: Green ring (or different color for differentiation)
- Animation: Scale from 0.5 to 1.5 while fading from 1.0 to 0.0 over 500ms
- Remove click effects after animation completes
- Coordinate conversion: NSEvent.mouseLocation is in screen coordinates

### Alternatives Considered
| Alternative | Rejected Because |
|-------------|------------------|
| Core Animation layer on capture | Requires compositing during capture |
| Post-processing video | Too complex, real-time overlay simpler |

---

## 7. Keystroke Overlay

### Decision
Use `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)` to capture keystrokes.

### Rationale
- Global event monitoring captures keys regardless of focused app
- No need for accessibility permission if not capturing passwords/secure fields
- Consistent with click visualization approach

### Best Practices
- Display overlay window at bottom-center of screen
- Show modifier symbols: ⌘ (Command), ⇧ (Shift), ⌥ (Option), ⌃ (Control)
- Format: modifiers + key (e.g., "⌘⇧S")
- Show last 5 key combinations, older ones fade out
- Clear display after 2 seconds of no input
- Use monospace font for consistent key display
- Handle special keys: Escape (⎋), Return (↩), Tab (⇥), Space (␣)

### Security Considerations
- Consider filtering secure input fields (may need accessibility permission)
- Don't log or persist captured keystrokes
- Only display during recording, clear after stop

---

## 8. Pause/Resume Implementation

### Decision
Track paused time offset and adjust presentation timestamps accordingly.

### Rationale
- Must produce seamless video without gaps when resumed
- AVAssetWriter expects continuous timestamps

### Best Practices
- On pause:
  - Stop SCStream capture
  - Record paused timestamp
  - Stop duration timer
- On resume:
  - Calculate pause duration
  - Resume SCStream capture
  - Add pause duration to timestamp offset
  - Resume duration timer
- When writing frames after resume:
  - Adjust presentation time by subtracting cumulative pause duration
  - This creates seamless output without time gaps

---

## 9. Memory Management for Long Recordings

### Decision
Write frames to disk progressively via AVAssetWriter, don't buffer in memory.

### Rationale
- 30-minute recording at 30fps = 54,000 frames
- Storing all frames in memory would exceed reasonable limits
- AVAssetWriter handles progressive writing automatically

### Best Practices
- For video: AVAssetWriter writes encoded frames to disk incrementally
- For GIF: This is more challenging since ImageIO needs all frames upfront
  - Option A: Warn users about memory for long GIF recordings
  - Option B: Limit GIF recording duration (e.g., 60 seconds max)
  - Option C: Write frames to temp files, load sequentially at finalization
- Monitor memory pressure and warn user if approaching limits
- Clean up temp files on cancel or completion

### GIF Duration Recommendation
- Recommend GIF recordings under 15 seconds for best results
- Show estimated file size during recording
- Allow longer with warning about file size/memory

---

## 10. Error Handling

### Decision
Implement comprehensive error handling for all recording failure modes.

### Rationale
- Recording involves multiple subsystems that can fail independently
- Users need clear feedback when something goes wrong
- Partial recordings should be salvaged when possible

### Error Categories
1. **Permission Errors**: Screen recording, microphone access
2. **Resource Errors**: Disk space, memory pressure
3. **Encoding Errors**: AVAssetWriter failures
4. **Capture Errors**: SCStream delegate errors
5. **File System Errors**: Cannot write to save location

### Best Practices
- Define custom error enum with LocalizedError conformance
- Show user-friendly error messages via notification
- Log detailed errors for debugging
- On fatal error during recording:
  - Stop capture immediately
  - Attempt to finalize partial recording if possible
  - Clean up resources
  - Notify user with recovery options

---

## Summary of Key Decisions

| Topic | Decision |
|-------|----------|
| Video Capture | SCStream with SCStreamOutput |
| Video Encoding | AVAssetWriter with H.264 |
| System Audio | ScreenCaptureKit audio capture |
| Microphone | AVAudioEngine inputNode |
| GIF Creation | ImageIO CGImageDestination |
| Controls UI | Floating NSWindow with SwiftUI |
| Click Overlay | NSWindow at .screenSaver level |
| Keystroke Capture | NSEvent global monitor |
| Pause/Resume | Timestamp offset adjustment |
| Memory Management | Progressive disk writing |

# Milestone 7: Cloud & Polish

## Overview

**Goal**: Complete the product with cloud features, capture history, and final polish for production release.

**Prerequisites**: Milestone 6 completed

---

## Deliverables

| Deliverable | Description | Priority |
|-------------|-------------|----------|
| Cloud Upload Service | Upload to hosting | P0 |
| Shareable Links | Generate share URLs | P0 |
| Capture History | Browse past captures | P0 |
| Onboarding Flow | First-run experience | P1 |
| Localization | Multi-language support | P2 |
| Accessibility | VoiceOver, keyboard | P1 |
| Performance Optimization | Memory, speed | P1 |
| App Icon & Branding | Visual identity | P1 |

---

## Implementation Tasks

### 7.1 Implement Cloud Service

**File**: `Core/Services/CloudService.swift`

```swift
import Foundation

actor CloudService {
    // MARK: - Types

    struct UploadConfig {
        var expiresIn: TimeInterval? = nil  // nil = never
        var password: String? = nil
        var maxDownloads: Int? = nil
    }

    struct UploadResult {
        let id: String
        let url: URL
        let deleteToken: String
        let expiresAt: Date?
        let createdAt: Date
    }

    struct CloudError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    // MARK: - Configuration

    private let baseURL: URL
    private let apiKey: String?

    init(baseURL: URL = URL(string: "https://api.screenpro.cloud")!, apiKey: String? = nil) {
        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    // MARK: - Upload

    func upload(
        data: Data,
        filename: String,
        mimeType: String,
        config: UploadConfig = UploadConfig()
    ) async throws -> UploadResult {
        var request = URLRequest(url: baseURL.appendingPathComponent("upload"))
        request.httpMethod = "POST"

        // Multipart form data
        let boundary = UUID().uuidString
        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField: "Content-Type"
        )

        if let apiKey = apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()

        // File data
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.append("\r\n")

        // Config fields
        if let expiresIn = config.expiresIn {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"expires_in\"\r\n\r\n")
            body.append("\(Int(expiresIn))\r\n")
        }

        if let password = config.password {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"password\"\r\n\r\n")
            body.append("\(password)\r\n")
        }

        body.append("--\(boundary)--\r\n")
        request.httpBody = body

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CloudError(message: "Upload failed")
        }

        let result = try JSONDecoder().decode(UploadResponse.self, from: responseData)

        return UploadResult(
            id: result.id,
            url: URL(string: result.url)!,
            deleteToken: result.deleteToken,
            expiresAt: result.expiresAt.flatMap { ISO8601DateFormatter().date(from: $0) },
            createdAt: Date()
        )
    }

    // MARK: - Delete

    func delete(id: String, token: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("delete/\(id)"))
        request.httpMethod = "DELETE"
        request.setValue(token, forHTTPHeaderField: "X-Delete-Token")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CloudError(message: "Delete failed")
        }
    }

    // MARK: - Response Types

    private struct UploadResponse: Codable {
        let id: String
        let url: String
        let deleteToken: String
        let expiresAt: String?
    }
}

// MARK: - Data Extension

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
```

---

### 7.2 Implement Capture History

**File**: `Features/History/CaptureHistoryStore.swift`

```swift
import SwiftData
import SwiftUI

@Model
final class CaptureHistoryItem {
    var id: UUID
    var captureDate: Date
    var captureType: String  // "screenshot", "video", "gif"
    var thumbnailData: Data?
    var filePath: String?
    var cloudURL: String?
    var cloudDeleteToken: String?
    var width: Int
    var height: Int
    var fileSize: Int64
    var tags: [String]

    init(
        id: UUID = UUID(),
        captureDate: Date = Date(),
        captureType: String,
        thumbnailData: Data? = nil,
        filePath: String? = nil,
        width: Int = 0,
        height: Int = 0,
        fileSize: Int64 = 0
    ) {
        self.id = id
        self.captureDate = captureDate
        self.captureType = captureType
        self.thumbnailData = thumbnailData
        self.filePath = filePath
        self.width = width
        self.height = height
        self.fileSize = fileSize
        self.tags = []
    }
}

@MainActor
final class CaptureHistoryStore: ObservableObject {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    @Published private(set) var items: [CaptureHistoryItem] = []
    @Published var searchText: String = ""
    @Published var filterType: String? = nil

    var filteredItems: [CaptureHistoryItem] {
        var result = items

        if let type = filterType {
            result = result.filter { $0.captureType == type }
        }

        if !searchText.isEmpty {
            result = result.filter { item in
                item.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }

        return result
    }

    init() throws {
        let schema = Schema([CaptureHistoryItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        modelContainer = try ModelContainer(for: schema, configurations: config)
        modelContext = ModelContext(modelContainer)
    }

    func fetchItems(limit: Int = 100) {
        let descriptor = FetchDescriptor<CaptureHistoryItem>(
            sortBy: [SortDescriptor(\.captureDate, order: .reverse)]
        )

        do {
            items = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch history: \(error)")
        }
    }

    func addItem(_ item: CaptureHistoryItem) {
        modelContext.insert(item)
        try? modelContext.save()
        fetchItems()
    }

    func deleteItem(_ item: CaptureHistoryItem) {
        // Delete file if exists
        if let path = item.filePath {
            try? FileManager.default.removeItem(atPath: path)
        }

        modelContext.delete(item)
        try? modelContext.save()
        fetchItems()
    }

    func clearOlderThan(_ date: Date) {
        let oldItems = items.filter { $0.captureDate < date }
        for item in oldItems {
            deleteItem(item)
        }
    }

    // MARK: - Thumbnail Generation

    static func generateThumbnail(from image: CGImage, maxSize: CGFloat = 200) -> Data? {
        let aspectRatio = CGFloat(image.width) / CGFloat(image.height)
        let thumbnailSize: CGSize

        if aspectRatio > 1 {
            thumbnailSize = CGSize(width: maxSize, height: maxSize / aspectRatio)
        } else {
            thumbnailSize = CGSize(width: maxSize * aspectRatio, height: maxSize)
        }

        guard let context = CGContext(
            data: nil,
            width: Int(thumbnailSize.width),
            height: Int(thumbnailSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: thumbnailSize))

        guard let thumbnail = context.makeImage() else { return nil }

        let bitmapRep = NSBitmapImageRep(cgImage: thumbnail)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.7])
    }
}
```

---

### 7.3 Implement History View

**File**: `Features/History/HistoryView.swift`

```swift
import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: CaptureHistoryStore

    @State private var selectedItems: Set<UUID> = []
    @State private var viewMode: ViewMode = .grid

    enum ViewMode {
        case grid, list
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HistoryToolbar(
                searchText: $store.searchText,
                filterType: $store.filterType,
                viewMode: $viewMode,
                selectedCount: selectedItems.count,
                onDelete: deleteSelected
            )

            Divider()

            // Content
            if store.filteredItems.isEmpty {
                EmptyHistoryView()
            } else {
                switch viewMode {
                case .grid:
                    HistoryGridView(
                        items: store.filteredItems,
                        selectedItems: $selectedItems
                    )
                case .list:
                    HistoryListView(
                        items: store.filteredItems,
                        selectedItems: $selectedItems
                    )
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            store.fetchItems()
        }
    }

    private func deleteSelected() {
        for id in selectedItems {
            if let item = store.items.first(where: { $0.id == id }) {
                store.deleteItem(item)
            }
        }
        selectedItems.removeAll()
    }
}

struct HistoryToolbar: View {
    @Binding var searchText: String
    @Binding var filterType: String?
    @Binding var viewMode: HistoryView.ViewMode
    let selectedCount: Int
    let onDelete: () -> Void

    var body: some View {
        HStack {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(6)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
            .frame(width: 200)

            // Filter
            Picker("Type", selection: $filterType) {
                Text("All").tag(nil as String?)
                Text("Screenshots").tag("screenshot" as String?)
                Text("Videos").tag("video" as String?)
                Text("GIFs").tag("gif" as String?)
            }
            .pickerStyle(.segmented)
            .frame(width: 250)

            Spacer()

            // View mode
            Picker("View", selection: $viewMode) {
                Image(systemName: "square.grid.2x2").tag(HistoryView.ViewMode.grid)
                Image(systemName: "list.bullet").tag(HistoryView.ViewMode.list)
            }
            .pickerStyle(.segmented)
            .frame(width: 80)

            // Delete
            if selectedCount > 0 {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete (\(selectedCount))", systemImage: "trash")
                }
            }
        }
        .padding()
    }
}

struct HistoryGridView: View {
    let items: [CaptureHistoryItem]
    @Binding var selectedItems: Set<UUID>

    let columns = [GridItem(.adaptive(minimum: 150, maximum: 200))]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items, id: \.id) { item in
                    HistoryGridItem(
                        item: item,
                        isSelected: selectedItems.contains(item.id)
                    )
                    .onTapGesture {
                        if selectedItems.contains(item.id) {
                            selectedItems.remove(item.id)
                        } else {
                            selectedItems.insert(item.id)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

struct HistoryGridItem: View {
    let item: CaptureHistoryItem
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            // Thumbnail
            if let thumbnailData = item.thumbnailData,
               let nsImage = NSImage(data: thumbnailData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 150, height: 100)
                    .clipped()
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 150, height: 100)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: iconForType(item.captureType))
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                    )
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(item.captureDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.primary)

                Text("\(item.width) × \(item.height)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }

    private func iconForType(_ type: String) -> String {
        switch type {
        case "video": return "video"
        case "gif": return "photo.stack"
        default: return "photo"
        }
    }
}

struct HistoryListView: View {
    let items: [CaptureHistoryItem]
    @Binding var selectedItems: Set<UUID>

    var body: some View {
        List(items, id: \.id, selection: $selectedItems) { item in
            HistoryListRow(item: item)
        }
    }
}

struct HistoryListRow: View {
    let item: CaptureHistoryItem

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let thumbnailData = item.thumbnailData,
               let nsImage = NSImage(data: thumbnailData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 40)
                    .clipped()
                    .cornerRadius(4)
            }

            // Info
            VStack(alignment: .leading) {
                Text(item.captureDate, style: .date)
                Text("\(item.width) × \(item.height) • \(formattedFileSize)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Type badge
            Text(item.captureType.capitalized)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }

    private var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: item.fileSize, countStyle: .file)
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No captures yet")
                .font(.headline)

            Text("Your screenshots and recordings will appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

---

### 7.4 Implement Onboarding Flow

**File**: `Features/Onboarding/OnboardingView.swift`

```swift
import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    let permissionManager: PermissionManager

    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            // Pages
            TabView(selection: $currentPage) {
                WelcomePage()
                    .tag(0)

                PermissionsPage(permissionManager: permissionManager)
                    .tag(1)

                ShortcutsPage()
                    .tag(2)

                ReadyPage()
                    .tag(3)
            }
            .tabViewStyle(.automatic)

            // Navigation
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                }

                Spacer()

                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<4) { page in
                        Circle()
                            .fill(page == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }

                Spacer()

                if currentPage < 3 {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }
}

struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("Welcome to ScreenPro")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("The best way to capture and share your screen on macOS")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "camera", text: "Capture screenshots with precision")
                FeatureRow(icon: "record.circle", text: "Record your screen in high quality")
                FeatureRow(icon: "pencil.and.outline", text: "Annotate with powerful tools")
                FeatureRow(icon: "cloud", text: "Share instantly with cloud hosting")
            }
            .padding(.top)
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)

            Text(text)
                .font(.body)
        }
    }
}

struct PermissionsPage: View {
    let permissionManager: PermissionManager

    var body: some View {
        VStack(spacing: 24) {
            Text("Permissions")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("ScreenPro needs a few permissions to work properly")
                .foregroundColor(.secondary)

            VStack(spacing: 16) {
                PermissionCard(
                    icon: "rectangle.dashed.badge.record",
                    title: "Screen Recording",
                    description: "Required to capture your screen",
                    status: permissionManager.screenRecordingStatus,
                    action: permissionManager.openScreenRecordingPreferences
                )

                PermissionCard(
                    icon: "mic",
                    title: "Microphone",
                    description: "Optional, for recording audio narration",
                    status: permissionManager.microphoneStatus,
                    action: permissionManager.openMicrophonePreferences
                )
            }
        }
        .padding()
    }
}

struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionManager.PermissionStatus
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.accentColor)
                .frame(width: 48)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            switch status {
            case .authorized:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .denied:
                Button("Enable") {
                    action()
                }
                .buttonStyle(.bordered)
            case .notDetermined:
                Button("Grant") {
                    action()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ShortcutsPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("Keyboard Shortcuts")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Quick access to all features")
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                ShortcutRow(keys: "⌘⇧4", action: "Capture Area")
                ShortcutRow(keys: "⌘⇧3", action: "Capture Fullscreen")
                ShortcutRow(keys: "⌘⇧5", action: "All-in-One Mode")
                ShortcutRow(keys: "⌘⇧6", action: "Record Screen")
            }

            Text("You can customize these in Settings")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct ShortcutRow: View {
    let keys: String
    let action: String

    var body: some View {
        HStack {
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(6)

            Text(action)

            Spacer()
        }
        .padding(.horizontal)
    }
}

struct ReadyPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("You're all set!")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("ScreenPro is ready to use. Look for the icon in your menu bar.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Image(systemName: "menubar.arrow.up.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
```

---

### 7.5 Implement Accessibility

**File**: `Core/Accessibility/AccessibilitySupport.swift`

```swift
import SwiftUI
import AppKit

// MARK: - Accessibility Labels

extension View {
    func captureAccessibility(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - VoiceOver Announcements

@MainActor
final class AccessibilityAnnouncer {
    static let shared = AccessibilityAnnouncer()

    func announce(_ message: String, priority: NSAccessibilityPriorityLevel = .medium) {
        NSAccessibility.post(
            element: NSApp,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: priority.rawValue
            ]
        )
    }

    func announceCaptureComplete(type: String) {
        announce("\(type) captured successfully")
    }

    func announceRecordingStarted() {
        announce("Recording started")
    }

    func announceRecordingStopped(duration: TimeInterval) {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        announce("Recording stopped. Duration: \(minutes) minutes \(seconds) seconds")
    }
}

// MARK: - Keyboard Navigation

struct KeyboardNavigable: ViewModifier {
    let onEscape: (() -> Void)?
    let onEnter: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .onKeyPress(.escape) {
                onEscape?()
                return .handled
            }
            .onKeyPress(.return) {
                onEnter?()
                return .handled
            }
    }
}

extension View {
    func keyboardNavigable(
        onEscape: (() -> Void)? = nil,
        onEnter: (() -> Void)? = nil
    ) -> some View {
        modifier(KeyboardNavigable(onEscape: onEscape, onEnter: onEnter))
    }
}

// MARK: - Reduce Motion Support

extension View {
    func respectsReduceMotion() -> some View {
        self.transaction { transaction in
            if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                transaction.animation = nil
            }
        }
    }
}
```

---

### 7.6 Performance Optimization

**File**: `Core/Performance/PerformanceMonitor.swift`

```swift
import Foundation
import os.signpost

final class PerformanceMonitor {
    static let shared = PerformanceMonitor()

    private let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Performance")
    private var signpostIDs: [String: OSSignpostID] = [:]

    func begin(_ name: String) {
        let id = OSSignpostID(log: log)
        signpostIDs[name] = id
        os_signpost(.begin, log: log, name: "Operation", signpostID: id, "%{public}s", name)
    }

    func end(_ name: String) {
        guard let id = signpostIDs[name] else { return }
        os_signpost(.end, log: log, name: "Operation", signpostID: id, "%{public}s", name)
        signpostIDs.removeValue(forKey: name)
    }

    func measure<T>(_ name: String, _ operation: () throws -> T) rethrows -> T {
        begin(name)
        defer { end(name) }
        return try operation()
    }

    func measureAsync<T>(_ name: String, _ operation: () async throws -> T) async rethrows -> T {
        begin(name)
        defer { end(name) }
        return try await operation()
    }
}

// MARK: - Memory Management

final class MemoryPressureHandler {
    static let shared = MemoryPressureHandler()

    private var source: DispatchSourceMemoryPressure?

    func startMonitoring(onWarning: @escaping () -> Void) {
        source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )

        source?.setEventHandler { [weak source] in
            guard let source = source else { return }

            if source.data.contains(.critical) {
                // Critical - aggressive cleanup
                onWarning()
            } else if source.data.contains(.warning) {
                // Warning - moderate cleanup
                onWarning()
            }
        }

        source?.resume()
    }

    func stopMonitoring() {
        source?.cancel()
        source = nil
    }
}

// MARK: - Image Cache

actor ImageCache {
    static let shared = ImageCache()

    private var cache: [String: CGImage] = [:]
    private let maxCacheSize = 100

    func get(_ key: String) -> CGImage? {
        cache[key]
    }

    func set(_ key: String, image: CGImage) {
        if cache.count >= maxCacheSize {
            // Remove oldest entries
            let keysToRemove = Array(cache.keys.prefix(maxCacheSize / 2))
            for key in keysToRemove {
                cache.removeValue(forKey: key)
            }
        }
        cache[key] = image
    }

    func clear() {
        cache.removeAll()
    }
}
```

---

## File Structure After Milestone 7

```
ScreenPro/
├── Core/
│   ├── Services/
│   │   └── CloudService.swift
│   ├── Accessibility/
│   │   └── AccessibilitySupport.swift
│   └── Performance/
│       └── PerformanceMonitor.swift
│
├── Features/
│   ├── History/
│   │   ├── CaptureHistoryStore.swift
│   │   └── HistoryView.swift
│   ├── Onboarding/
│   │   └── OnboardingView.swift
│   └── ...
│
├── Resources/
│   ├── Assets.xcassets/
│   │   └── AppIcon.appiconset/
│   ├── Localizable.strings
│   └── Localizable.strings (zh-Hans)
```

---

## Final Testing Checklist

### Functionality
- [ ] All capture modes work
- [ ] All recording modes work
- [ ] Annotation tools complete
- [ ] Cloud upload works
- [ ] History displays correctly
- [ ] Settings persist

### Performance
- [ ] Cold launch < 2 seconds
- [ ] Capture < 50ms
- [ ] Overlay appears < 200ms
- [ ] Memory < 50MB idle
- [ ] No frame drops in recording

### Accessibility
- [ ] All buttons have labels
- [ ] Keyboard navigation works
- [ ] VoiceOver announces actions
- [ ] Respects reduce motion
- [ ] High contrast works

### Edge Cases
- [ ] Multi-monitor support
- [ ] Retina + non-Retina
- [ ] Permission denied gracefully
- [ ] Network failure handled
- [ ] Large file handling

---

## Exit Criteria

| Criterion | Verification |
|-----------|--------------|
| Cloud works | Upload and share |
| History works | Browse and search |
| Onboarding complete | First-run flow |
| Accessibility audit | VoiceOver test |
| Performance targets | All metrics met |
| Ready for release | All tests pass |

---

## Release Checklist

- [ ] App icon finalized
- [ ] Screenshots prepared
- [ ] App Store description written
- [ ] Privacy policy updated
- [ ] Notarization completed
- [ ] TestFlight build tested
- [ ] Release notes drafted

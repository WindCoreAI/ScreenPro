import Foundation
import SwiftUI

// MARK: - CaptureQueue

/// Manages the ordered collection of pending captures in the Quick Access overlay.
/// Thread-safe via @MainActor isolation.
@MainActor
final class CaptureQueue: ObservableObject {
    // MARK: - Published Properties

    /// Ordered list of captures (newest first).
    @Published private(set) var items: [CaptureItem] = []

    /// Currently selected item index for keyboard navigation.
    @Published var selectedIndex: Int = 0

    // MARK: - Constants

    /// Maximum items displayed before scrolling.
    let maxVisibleItems: Int = 5

    /// Maximum items before oldest is evicted.
    let maxQueueSize: Int = 10

    // MARK: - Computed Properties

    /// Whether the queue is empty.
    var isEmpty: Bool {
        items.isEmpty
    }

    /// Number of items in the queue.
    var count: Int {
        items.count
    }

    /// Currently selected item, if any.
    var selected: CaptureItem? {
        guard !items.isEmpty, selectedIndex >= 0, selectedIndex < items.count else {
            return nil
        }
        return items[selectedIndex]
    }

    // MARK: - Queue Operations

    /// Adds a capture result to the queue.
    /// - Parameter result: The capture to add.
    /// - Returns: The created CaptureItem.
    /// - Note: Inserts at index 0 (front), evicts oldest if at capacity.
    @discardableResult
    func add(_ result: CaptureResult) -> CaptureItem {
        let item = CaptureItem(result: result)

        // Insert at front (newest first)
        items.insert(item, at: 0)

        // Evict oldest if at capacity
        if items.count > maxQueueSize {
            items.removeLast()
        }

        // Keep selection at top for new items
        selectedIndex = 0

        return item
    }

    /// Updates the thumbnail for an existing item.
    /// - Parameters:
    ///   - id: The UUID of the item to update.
    ///   - thumbnail: The generated thumbnail image.
    func updateThumbnail(for id: UUID, thumbnail: NSImage) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }
        items[index].thumbnail = thumbnail
    }

    /// Removes a capture from the queue.
    /// - Parameter id: The UUID of the capture to remove.
    func remove(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }

        items.remove(at: index)

        // Adjust selection index if needed
        if items.isEmpty {
            selectedIndex = 0
        } else if selectedIndex >= items.count {
            selectedIndex = items.count - 1
        }
    }

    /// Removes all captures from the queue.
    func clear() {
        items.removeAll()
        selectedIndex = 0
    }

    /// Moves selection to the next item (down in the list).
    func selectNext() {
        guard !items.isEmpty else { return }

        if selectedIndex < items.count - 1 {
            selectedIndex += 1
        }
    }

    /// Moves selection to the previous item (up in the list).
    func selectPrevious() {
        guard !items.isEmpty else { return }

        if selectedIndex > 0 {
            selectedIndex -= 1
        }
    }

    /// Gets item at specific index.
    /// - Parameter index: The index to retrieve.
    /// - Returns: The CaptureItem at that index, or nil if out of bounds.
    func item(at index: Int) -> CaptureItem? {
        guard index >= 0, index < items.count else {
            return nil
        }
        return items[index]
    }

    /// Checks if an item is currently selected.
    /// - Parameter item: The item to check.
    /// - Returns: True if this item is the selected one.
    func isSelected(_ item: CaptureItem) -> Bool {
        guard let selected = selected else { return false }
        return selected.id == item.id
    }
}

import SwiftUI
import AppKit

// MARK: - History View (007-cloud-polish)

/// Browser for past captures and recordings with search, filtering,
/// grid/list display, and per-item actions.
struct HistoryView: View {
    @ObservedObject var store: CaptureHistoryStore

    @State private var selectedItems: Set<UUID> = []
    @State private var viewMode: ViewMode = .grid

    enum ViewMode {
        case grid, list
    }

    var body: some View {
        VStack(spacing: 0) {
            HistoryToolbar(
                searchText: $store.searchText,
                filterType: $store.filterType,
                viewMode: $viewMode,
                selectedCount: selectedItems.count,
                onDelete: deleteSelected
            )

            Divider()

            if store.filteredItems.isEmpty {
                EmptyHistoryView(isFiltered: !store.searchText.isEmpty || store.filterType != nil)
            } else {
                switch viewMode {
                case .grid:
                    HistoryGridView(
                        store: store,
                        items: store.filteredItems,
                        selectedItems: $selectedItems
                    )
                case .list:
                    HistoryListView(
                        store: store,
                        items: store.filteredItems,
                        selectedItems: $selectedItems
                    )
                }
            }
        }
        .frame(minWidth: 640, minHeight: 420)
        .onAppear {
            store.fetchItems()
        }
        .keyboardNavigable(onEscape: { selectedItems.removeAll() })
        .accessibilityLabel("Capture History")
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

// MARK: - Toolbar

struct HistoryToolbar: View {
    @Binding var searchText: String
    @Binding var filterType: CaptureHistoryType?
    @Binding var viewMode: HistoryView.ViewMode
    let selectedCount: Int
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .accessibilityLabel("Search history")
            }
            .padding(6)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)
            .frame(width: 200)

            Picker("Type", selection: $filterType) {
                Text("All").tag(nil as CaptureHistoryType?)
                Text("Screenshots").tag(CaptureHistoryType.screenshot as CaptureHistoryType?)
                Text("Videos").tag(CaptureHistoryType.video as CaptureHistoryType?)
                Text("GIFs").tag(CaptureHistoryType.gif as CaptureHistoryType?)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 280)
            .accessibilityLabel("Filter by capture type")

            Spacer()

            if selectedCount > 0 {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete (\(selectedCount))", systemImage: "trash")
                }
                .accessibilityLabel("Delete \(selectedCount) selected items")
            }

            Picker("View", selection: $viewMode) {
                Image(systemName: "square.grid.2x2").tag(HistoryView.ViewMode.grid)
                Image(systemName: "list.bullet").tag(HistoryView.ViewMode.list)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 80)
            .accessibilityLabel("View mode")
        }
        .padding(12)
    }
}

// MARK: - Grid View

struct HistoryGridView: View {
    let store: CaptureHistoryStore
    let items: [CaptureHistoryItem]
    @Binding var selectedItems: Set<UUID>

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items, id: \.id) { item in
                    HistoryGridItem(
                        item: item,
                        isSelected: selectedItems.contains(item.id)
                    )
                    .onTapGesture {
                        toggleSelection(item.id)
                    }
                    .historyItemActions(item: item, store: store)
                }
            }
            .padding()
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedItems.contains(id) {
            selectedItems.remove(id)
        } else {
            selectedItems.insert(id)
        }
    }
}

struct HistoryGridItem: View {
    let item: CaptureHistoryItem
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            HistoryThumbnail(item: item, width: 160, height: 100)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.captureDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.primary)

                    if item.cloudURL != nil {
                        Image(systemName: "link.circle.fill")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                            .help("Uploaded — shareable link available")
                    }
                }

                Text(item.dimensionsText)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.type.displayName), \(item.dimensionsText)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - List View

struct HistoryListView: View {
    let store: CaptureHistoryStore
    let items: [CaptureHistoryItem]
    @Binding var selectedItems: Set<UUID>

    var body: some View {
        List(items, id: \.id, selection: $selectedItems) { item in
            HistoryListRow(item: item)
                .historyItemActions(item: item, store: store)
        }
    }
}

struct HistoryListRow: View {
    let item: CaptureHistoryItem

    var body: some View {
        HStack(spacing: 12) {
            HistoryThumbnail(item: item, width: 60, height: 40)

            VStack(alignment: .leading) {
                Text(item.filename ?? item.type.displayName)
                    .lineLimit(1)
                Text("\(item.captureDate.formatted(date: .abbreviated, time: .shortened)) • \(item.dimensionsText) • \(item.formattedFileSize)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if item.cloudURL != nil {
                Image(systemName: "link.circle.fill")
                    .foregroundColor(.accentColor)
                    .help("Uploaded — shareable link available")
            }

            Text(item.type.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.type.displayName), \(item.filename ?? ""), \(item.dimensionsText)")
    }
}

// MARK: - Thumbnail

struct HistoryThumbnail: View {
    let item: CaptureHistoryItem
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Group {
            if let thumbnailData = item.thumbnailData,
               let nsImage = NSImage(data: thumbnailData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .overlay(
                        Image(systemName: item.type.iconName)
                            .font(.title2)
                            .foregroundColor(.secondary)
                    )
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .cornerRadius(8)
    }
}

// MARK: - Item Actions

private struct HistoryItemActions: ViewModifier {
    let item: CaptureHistoryItem
    let store: CaptureHistoryStore

    func body(content: Content) -> some View {
        content
            .onDrag {
                if let url = item.fileURL, item.fileExists {
                    return NSItemProvider(contentsOf: url) ?? NSItemProvider()
                }
                return NSItemProvider()
            }
            .contextMenu {
                if let url = item.fileURL, item.fileExists {
                    Button("Open") {
                        NSWorkspace.shared.open(url)
                    }
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                    Button("Copy Image") {
                        if let image = NSImage(contentsOf: url) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.writeObjects([image])
                        }
                    }
                }

                if let shareURL = item.shareURL {
                    Button("Copy Link") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(shareURL.absoluteString, forType: .string)
                    }
                    Button("Open Link in Browser") {
                        NSWorkspace.shared.open(shareURL)
                    }
                }

                Divider()

                Button("Remove from History") {
                    store.deleteItem(item)
                }
                if item.fileExists {
                    Button("Delete File", role: .destructive) {
                        store.deleteItem(item, removeFile: true)
                    }
                }
            }
    }
}

private extension View {
    func historyItemActions(item: CaptureHistoryItem, store: CaptureHistoryStore) -> some View {
        modifier(HistoryItemActions(item: item, store: store))
    }
}

// MARK: - Empty State

struct EmptyHistoryView: View {
    var isFiltered: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(isFiltered ? "No matching captures" : "No captures yet")
                .font(.headline)

            Text(
                isFiltered
                    ? "Try a different search or filter"
                    : "Your screenshots and recordings will appear here"
            )
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

import SwiftUI

// MARK: - ReviewSummaryView (008-review-recording, US4 / FR-012)
//
// Skippable post-stop step: scan captured issues, fix transcription
// mistakes, delete accidental flags. Closing the window = skip = generate
// as-captured.

struct ReviewSummaryView: View {
    @ObservedObject var session: ReviewSessionService

    let onGenerate: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if session.issues.isEmpty {
                emptyState
            } else {
                issueList
            }

            Divider()

            footer
        }
        .frame(minWidth: 560, minHeight: 380)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Review Summary")
                    .font(.headline)
                Text("\(session.issues.count) issue\(session.issues.count == 1 ? "" : "s") captured. Edit or remove before generating the report.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "flag.slash")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("All issues were removed.")
                .foregroundColor(.secondary)
            Text("Generating now will save the recording without a review report.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var issueList: some View {
        List {
            ForEach(session.issues) { issue in
                ReviewSummaryRow(
                    issue: issue,
                    thumbnailURL: session.screenshotURL(for: issue),
                    onNoteChange: { session.setNote($0, for: issue.id) },
                    onTranscriptChange: { session.setTranscript($0, for: issue.id) },
                    onDelete: { session.deleteIssue(issue.id) }
                )
            }
        }
        .listStyle(.inset)
        .accessibilityLabel("Captured review issues")
    }

    private var footer: some View {
        HStack {
            Button("Skip", action: onSkip)
                .keyboardShortcut(.cancelAction)
                .accessibilityHint("Generates the report with the issues as captured")

            Spacer()

            Button("Generate Report", action: onGenerate)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Creates the review report bundle in your save folder")
        }
        .padding()
    }
}

// MARK: - Row

private struct ReviewSummaryRow: View {
    let issue: ReviewIssue
    let thumbnailURL: URL?
    let onNoteChange: (String) -> Void
    let onTranscriptChange: (String) -> Void
    let onDelete: () -> Void

    @State private var note: String
    @State private var transcript: String

    init(
        issue: ReviewIssue,
        thumbnailURL: URL?,
        onNoteChange: @escaping (String) -> Void,
        onTranscriptChange: @escaping (String) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.issue = issue
        self.thumbnailURL = thumbnailURL
        self.onNoteChange = onNoteChange
        self.onTranscriptChange = onTranscriptChange
        self.onDelete = onDelete
        _note = State(initialValue: issue.note ?? "")
        _transcript = State(initialValue: issue.transcript ?? "")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: issue.source == .manual ? "flag.fill" : "waveform")
                        .font(.caption)
                        .foregroundColor(issue.source == .manual ? .orange : .blue)
                        .accessibilityLabel(issue.source == .manual ? "Manually flagged" : "Voice note")
                    Text(issue.timecode)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Delete issue at \(issue.timecode)")
                }

                if issue.source == .voice || !(issue.transcript ?? "").isEmpty {
                    TextField("Transcript", text: $transcript, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .font(.callout)
                        .onChange(of: transcript) { _, newValue in
                            onTranscriptChange(newValue)
                        }
                        .accessibilityLabel("Transcript for issue at \(issue.timecode)")
                }

                TextField("Note", text: $note, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
                    .onChange(of: note) { _, newValue in
                        onNoteChange(newValue)
                    }
                    .accessibilityLabel("Note for issue at \(issue.timecode)")
            }
        }
        .padding(.vertical, 6)
    }

    private var thumbnail: some View {
        Group {
            if let url = thumbnailURL, let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.2))
                    .overlay(Image(systemName: "photo").foregroundColor(.secondary))
            }
        }
        .frame(width: 120, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel("Screenshot at \(issue.timecode)")
    }
}

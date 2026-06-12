import SwiftUI

// MARK: - Onboarding View (007-cloud-polish)

/// First-run experience: welcome, permissions, shortcuts, and ready pages.
struct OnboardingView: View {
    @ObservedObject var permissionManager: PermissionManager

    /// Called when the user finishes (or skips through) onboarding.
    let onComplete: () -> Void

    @State private var currentPage = 0

    private let pageCount = 4

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch currentPage {
                case 0:
                    WelcomePage()
                case 1:
                    PermissionsPage(permissionManager: permissionManager)
                case 2:
                    ShortcutsPage()
                default:
                    ReadyPage()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .respectsReduceMotion()

            Divider()

            // Navigation
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .accessibilityLabel("Previous page")
                }

                Spacer()

                HStack(spacing: 8) {
                    ForEach(0..<pageCount, id: \.self) { page in
                        Circle()
                            .fill(page == currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Page \(currentPage + 1) of \(pageCount)")

                Spacer()

                if currentPage < pageCount - 1 {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityLabel("Next page")
                } else {
                    Button("Get Started") {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityLabel("Finish onboarding")
                }
            }
            .padding()
        }
        .frame(width: 520, height: 440)
    }
}

// MARK: - Welcome Page

struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)

            Text("Welcome to ScreenPro")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("The best way to capture and share your screen on macOS")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                OnboardingFeatureRow(icon: "camera", text: "Capture screenshots with precision")
                OnboardingFeatureRow(icon: "record.circle", text: "Record your screen in high quality")
                OnboardingFeatureRow(icon: "pencil.and.outline", text: "Annotate with powerful tools")
                OnboardingFeatureRow(icon: "cloud", text: "Share instantly with cloud hosting")
            }
            .padding(.top, 4)
        }
        .padding()
    }
}

struct OnboardingFeatureRow: View {
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
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Permissions Page

struct PermissionsPage: View {
    @ObservedObject var permissionManager: PermissionManager

    var body: some View {
        VStack(spacing: 20) {
            Text("Permissions")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("ScreenPro needs a few permissions to work properly")
                .foregroundColor(.secondary)

            VStack(spacing: 16) {
                OnboardingPermissionCard(
                    icon: "rectangle.dashed.badge.record",
                    title: "Screen Recording",
                    description: "Required to capture your screen",
                    status: permissionManager.screenRecordingStatus,
                    onRequest: {
                        permissionManager.requestScreenRecordingPermission()
                    },
                    onOpenSettings: {
                        permissionManager.openScreenRecordingPreferences()
                    }
                )

                OnboardingPermissionCard(
                    icon: "mic",
                    title: "Microphone",
                    description: "Optional, for recording audio narration",
                    status: permissionManager.microphoneStatus,
                    onRequest: {
                        Task {
                            _ = await permissionManager.requestMicrophonePermission()
                        }
                    },
                    onOpenSettings: {
                        permissionManager.openMicrophonePreferences()
                    }
                )
            }
        }
        .padding()
    }
}

struct OnboardingPermissionCard: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
    let onRequest: () -> Void
    let onOpenSettings: () -> Void

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
                    .accessibilityLabel("\(title) authorized")
            case .denied:
                Button("Enable") {
                    onOpenSettings()
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Open System Settings to enable \(title)")
            case .notDetermined:
                Button("Grant") {
                    onRequest()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Grant \(title) permission")
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Shortcuts Page

struct ShortcutsPage: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Keyboard Shortcuts")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Quick access to all features")
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                OnboardingShortcutRow(keys: "⌘⇧4", action: "Capture Area")
                OnboardingShortcutRow(keys: "⌘⇧3", action: "Capture Fullscreen")
                OnboardingShortcutRow(keys: "⌘⇧5", action: "All-in-One Mode")
                OnboardingShortcutRow(keys: "⌘⇧6", action: "Record Screen")
            }

            Text("You can customize these in Settings → Shortcuts")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct OnboardingShortcutRow: View {
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
        .padding(.horizontal, 40)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(action): \(keys)")
    }
}

// MARK: - Ready Page

struct ReadyPage: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 56))
                .foregroundColor(.green)

            Text("You're all set!")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("ScreenPro is ready to use. Look for the icon in your menu bar.")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Image(systemName: "menubar.arrow.up.rectangle")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    OnboardingView(permissionManager: PermissionManager(), onComplete: {})
}

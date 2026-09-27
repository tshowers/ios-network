import SwiftUI

/// "Get the most out of Network" - the checklist shown after sign-in (and
/// from the account menu). Each step checks itself off from real data
/// (`GET /network/getting-started`), so it doubles as the app's help: it
/// tells a new user what to do next and shows their progress. A pushed
/// page, not a popup.
struct GettingStartedView: View {
    let apiClient: NetworkAPIClient
    /// The in-app Profile screen, pushed for the profile step.
    let profileView: () -> AnyView
    /// Opens a Network web page already signed in (import, contact list).
    let onOpenWeb: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(Self.showAtStartupKey) private var showAtStartup = true
    @State private var progress: GettingStarted?
    @State private var errorMessage = ""

    static let showAtStartupKey = "network.gettingStarted.showAtStartup"
    private static let accent = Color(red: 0.07, green: 0.24, blue: 0.55)

    var body: some View {
        let theme = NetworkTheme(colorScheme: colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(progress?.allDone == true ? "You're all set" : "Get the most out of Network")
                        .font(.title.bold())
                        .foregroundStyle(theme.primaryText)
                    Text("Each step checks itself off as you go.")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                }

                if let progress {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(progress.completedSteps) of \(progress.totalSteps) done")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(theme.secondaryText)
                        ProgressView(value: Double(progress.completedSteps), total: Double(max(progress.totalSteps, 1)))
                            .tint(progress.allDone ? .green : Self.accent)
                    }

                    VStack(spacing: 12) {
                        ForEach(progress.steps) { step in
                            stepRow(step, theme: theme)
                        }
                    }
                } else if errorMessage.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else {
                    Text(errorMessage).foregroundStyle(theme.secondaryText)
                }

                Toggle("Show this when I open Network", isOn: $showAtStartup)
                    .font(.subheadline)
                    .foregroundStyle(theme.primaryText)
                    .tint(Self.accent)
                    .padding(.top, 8)
            }
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(20)
        }
        .background(BackgroundView().ignoresSafeArea())
        .navigationTitle("Getting Started")
        .navigationBarTitleDisplayMode(.inline)
        // onAppear, not task: re-checks when coming back from Profile or
        // the web, so finished steps tick off without a manual refresh.
        .onAppear { Task { await load() } }
    }

    @ViewBuilder
    private func stepRow(_ step: GettingStarted.Step, theme: NetworkTheme) -> some View {
        let row = HStack(alignment: .top, spacing: 14) {
            Image(systemName: step.done ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(step.done ? .green : theme.secondaryText)
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)
                    .strikethrough(step.done, color: theme.secondaryText)
                Text(step.detail)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
        }
        .padding(16)
        .background(theme.panelStrong, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(theme.border))
        .accessibilityElement(children: .combine)
        .accessibilityValue(step.done ? "Done" : "Not done")

        switch step.id {
        case "profile":
            NavigationLink { profileView() } label: { row }
                .buttonStyle(.plain)
        case "contacts":
            Button { onOpenWeb("/contact-import") } label: { row }
                .buttonStyle(.plain)
        case "stages":
            Button { onOpenWeb("/contact-list") } label: { row }
                .buttonStyle(.plain)
        default:
            // Reach out: back to the cards to pick someone.
            Button { dismiss() } label: { row }
                .buttonStyle(.plain)
        }
    }

    private func load() async {
        do {
            progress = try await apiClient.fetchGettingStarted()
            errorMessage = ""
        } catch {
            if progress == nil { errorMessage = "Couldn't load your progress. Pull back and try again." }
        }
    }
}

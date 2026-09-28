import SwiftUI
import TODDAuthKit
import TODDAwardsKit
import TODDProfileKit

/// The main screen: a real `UIPageViewController` page curl (`PageCurlView`),
/// not a hand-rolled gesture stack — the "turning a page in a premium
/// business card book" brief, matched literally with forward AND backward
/// swipes. Near-zero chrome on purpose: search + settings only, the card is
/// the interface.
struct CardFeedView: View {
    @StateObject var viewModel: CardFeedViewModel
    @ObservedObject var authService: AuthService
    @ObservedObject var awardsService: AwardsService
    @State private var isShowingSearch = false
    @State private var isShowingStatus = false
    @State private var isShowingProfile = false
    @State private var isShowingGettingStarted = false
    @State private var isShowingAwards = false
    /// Auto-show the Getting Started checklist at most once per launch.
    private static var didAutoShowGettingStarted = false
    @State private var isShowingLogoutConfirmation = false
    @State private var isShowingCreateWarning = false
    @State private var shareItem: IdentifiableURL?
    @State private var isOpeningWebHandoff = false
    @State private var webHandoffErrorMessage: String?

    private static let networkHost = URL(string: "https://network.taliferro.tech")!
    private static let toddHost = URL(string: "https://todd.taliferro.tech")!

    /// Destinations reachable from the account menu via the shared
    /// `TODDAuthKit.WebHandoff` real-token handoff - opens already signed
    /// in, no second login. Mirrors outreach-ios's/docs-ios's account menu.
    /// Profile isn't here - it's in-app (TODDProfileKit's ProfileView).
    private static let webHandoffMenuItems: [(title: String, icon: String, path: String, host: URL)] = [
        (title: "Home", icon: "house", path: "/", host: networkHost),
        (title: "Relationships", icon: "point.3.connected.trianglepath.dotted", path: "/app", host: networkHost),
        (title: "Contacts", icon: "person.crop.rectangle.stack", path: "/contact-list", host: networkHost),
        (title: "Add", icon: "person.crop.circle.badge.plus", path: "/contact-edit", host: networkHost),
        (title: "Import", icon: "square.and.arrow.down", path: "/contact-import", host: networkHost),
        (title: "Pipeline", icon: "chart.bar.xaxis", path: "/contact-deal-flow", host: networkHost),
        (title: "Daily Momentum", icon: "flame", path: "/daily-momentum", host: toddHost),
    ]

    var body: some View {
        // A NavigationStack so Network Status pushes as a regular page (with
        // a back button) rather than a sheet - the other apps don't use
        // popups. The feed keeps its own custom header, so the system bar
        // stays hidden here.
        NavigationStack {
            feed
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: $isShowingStatus) {
                    NetworkStatusView(apiClient: viewModel.apiClient)
                }
                .navigationDestination(isPresented: $isShowingProfile) {
                    profileView
                }
                .navigationDestination(isPresented: $isShowingGettingStarted) {
                    GettingStartedView(
                        apiClient: viewModel.apiClient,
                        profileView: { AnyView(profileView) },
                        onOpenWeb: { path in openWebHandoff(path: path, host: Self.networkHost) }
                    )
                }
                .navigationDestination(isPresented: $isShowingAwards) {
                    AwardsGridView(awardsService: awardsService)
                        .task { await awardsService.sync() }
                }
                // Coming back from Getting Started (where profile/import
                // steps get done) is when new awards are most likely.
                .onChange(of: isShowingGettingStarted) { _, isShowing in
                    if !isShowing { Task { await checkAwards() } }
                }
        }
    }

    private var feed: some View {
        ZStack {
            BackgroundView().ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if viewModel.isLoading && viewModel.cards.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let card = viewModel.currentCard {
                    PageCurlView(
                        cards: viewModel.cards,
                        currentIndex: $viewModel.currentIndex,
                        insight: { viewModel.insight(for: $0) },
                        isSelf: { viewModel.isSelf($0) },
                        onDisplay: { displayed in
                            viewModel.loadInsightIfNeeded(for: displayed)
                            Task { await viewModel.loadMoreIfNeeded() }
                        },
                        // Maya button removed for now (was opening an
                        // in-app "Compose with Maya" email-draft sheet, not
                        // the actual Maya app) - reported/requested 2026-09-21.
                        // Reintroduce later as a deep link into maya-ios
                        // instead, once that's wired up.
                        onMaya: nil,
                        onShare: { card in
                            if let url = ShareCardBuilder.temporaryVCardFile(for: card) {
                                shareItem = IdentifiableURL(url: url)
                                awardsService.recordCardShared()
                            }
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else {
                    emptyState
                }
            }
        }
        .task {
            await viewModel.loadInitial()
            viewModel.loadTotalContactsIfNeeded()
            await autoShowGettingStartedIfNeeded()
            if let card = viewModel.currentCard {
                viewModel.loadInsightIfNeeded(for: card)
            }
        }
        .sheet(item: $shareItem) { item in
            ActivityShareSheet(activityItems: [item.url])
        }
        .alert("Log out of Network?", isPresented: $isShowingLogoutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Log Out", role: .destructive) {
                try? authService.signOut()
            }
        } message: {
            Text("You can sign in again with your TODD account.")
        }
        .alert("You'll leave Network", isPresented: $isShowingCreateWarning) {
            Button("Cancel", role: .cancel) { }
            Button("Continue") {
                openWebHandoff(path: "/contact-edit", host: Self.networkHost)
            }
        } message: {
            Text("Adding a new contact opens network.taliferro.tech in your browser, already signed in. You'll leave the app to do this.")
        }
        .alert("Couldn't open that page", isPresented: .constant(webHandoffErrorMessage != nil)) {
            Button("OK") { webHandoffErrorMessage = nil }
        } message: {
            Text(webHandoffErrorMessage ?? "")
        }
    }

    /// After sign-in/unlock, open the Getting Started checklist once per
    /// launch while steps remain - unless the user switched it off there.
    /// Also checks awards against the same progress fetch.
    private func autoShowGettingStartedIfNeeded() async {
        guard let progress = try? await viewModel.apiClient.fetchGettingStarted() else { return }
        awardsService.recordProgress(progress)
        guard !Self.didAutoShowGettingStarted else { return }
        let showAtStartup = UserDefaults.standard.object(forKey: GettingStartedView.showAtStartupKey) as? Bool ?? true
        guard showAtStartup, !progress.allDone else { return }
        Self.didAutoShowGettingStarted = true
        isShowingGettingStarted = true
    }

    private func checkAwards() async {
        if let progress = try? await viewModel.apiClient.fetchGettingStarted() {
            awardsService.recordProgress(progress)
        }
    }

    /// The shared in-app profile screen (TODDProfileKit), replacing the old
    /// web handoff to todd.taliferro.tech/user-profile. Also where the
    /// App Store-required "Delete account" lives.
    private var profileView: some View {
        let authService = self.authService
        return ProfileView(
            api: ProfileAPI(
                baseURL: AppConfig.fromBundle().apiBaseURL,
                idToken: { try await authService.freshIdToken() }
            ),
            appName: "Network",
            accent: Color(red: 0.07, green: 0.24, blue: 0.55),
            onOpenWebSettings: { openWebHandoff(path: "/update-profile", host: Self.toddHost) },
            onAccountDeleted: {
                OnboardingProfileDraft.clear()
                try? authService.signOut()
            }
        ) {
            BackgroundView()
        }
    }

    /// Opens a web page already signed in via the shared
    /// `TODDAuthKit.WebHandoff` real-token handoff - no second login.
    private func openWebHandoff(path: String, host: URL) {
        isOpeningWebHandoff = true
        Task {
            defer { isOpeningWebHandoff = false }
            do {
                let idToken = try await authService.freshIdToken()
                try await WebHandoff.open(
                    path: path,
                    idToken: idToken,
                    apiBaseURL: AppConfig.fromBundle().apiBaseURL,
                    webBaseURL: host
                )
            } catch {
                webHandoffErrorMessage = "Please try again in a moment."
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                Menu {
                    ForEach(Self.webHandoffMenuItems, id: \.title) { item in
                        Button {
                            openWebHandoff(path: item.path, host: item.host)
                        } label: {
                            Label(item.title, systemImage: item.icon)
                        }
                        .disabled(isOpeningWebHandoff)
                    }
                    Divider()
                    Button {
                        isShowingGettingStarted = true
                    } label: {
                        Label("Getting Started", systemImage: "checklist")
                    }
                    Button {
                        isShowingAwards = true
                    } label: {
                        Label("Awards", systemImage: "rosette")
                    }
                    Button {
                        isShowingProfile = true
                    } label: {
                        Label("Profile", systemImage: "person.crop.circle")
                    }
                    Button {
                        isShowingStatus = true
                    } label: {
                        Label("Network Status", systemImage: "gauge.medium")
                    }
                    Button {
                        isShowingLogoutConfirmation = true
                    } label: {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    Label("Account", systemImage: "person.crop.circle")
                        .labelStyle(.iconOnly)
                        .font(.system(size: 21, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Account menu")

                Spacer(minLength: 0)

                positionCounter

                Spacer(minLength: 0)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isShowingSearch.toggle() }
                } label: {
                    Image(systemName: isShowingSearch ? "xmark" : "magnifyingglass")
                        .font(.system(size: 21, weight: .semibold))
                        .frame(width: 44, height: 44)
                }

                Button {
                    isShowingCreateWarning = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 21, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .disabled(isOpeningWebHandoff)
                .accessibilityLabel("Add contact")
            }
            .padding(.horizontal, 20)
            .padding(.top, 2)

            if isShowingSearch { searchBar }
        }
        .foregroundStyle(.white)
        .frame(minHeight: 50)
        .padding(.bottom, isShowingSearch ? 8 : 0)
        .background(Color(red: 0.02, green: 0.12, blue: 0.25).opacity(0.96))

    }

    /// "N of Total" - matches the position pill in the reference design.
    /// `viewModel.totalContacts` is the tenant's real contact count (from
    /// `/network/stats`), not just how many pages have loaded so far.
    private var positionCounter: some View {
        Group {
            if !viewModel.cards.isEmpty {
                Text("\(viewModel.currentIndex + 1) of \(viewModel.totalContacts.map(String.init) ?? "\(viewModel.cards.count)")")
            }
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .foregroundStyle(.white)
        .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1))
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            TextField("investors in Seattle, or who should I talk to today?", text: $viewModel.searchQuery)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.search)
                .onSubmit { Task { await viewModel.runSearch() } }

            if !viewModel.searchQuery.isEmpty {
                Button("Clear") { Task { await viewModel.clearSearch() } }
                    .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(viewModel.errorMessage.isEmpty ? "No contacts to show yet." : viewModel.errorMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            if viewModel.errorMessage.isEmpty {
                Button("Add a Contact") { isShowingCreateWarning = true }
                    .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
    }
}

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

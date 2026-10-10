import SwiftUI
import TODDAuthKit
import TODDAwardsKit
import TODDProfileKit

/// The signed-in app: Relationships (health), Contacts, Cards (the page-curl
/// feed), and Me. One `ContactStore` is shared by every tab.
struct MainTabView: View {
    enum Tab: Hashable { case relationships, contacts, cards, me }

    @ObservedObject var authService: AuthService
    @ObservedObject var awardsService: AwardsService
    let apiClient: NetworkAPIClient
    @StateObject private var store: ContactStore
    @State private var selection: Tab = .contacts
    @State private var statusFilter: String?

    init(authService: AuthService, awardsService: AwardsService, apiClient: NetworkAPIClient) {
        self.authService = authService
        self.awardsService = awardsService
        self.apiClient = apiClient
        _store = StateObject(wrappedValue: ContactStore(apiClient: apiClient, userId: authService.userId))
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                NetworkStatusView(apiClient: apiClient)
            }
            .tabItem { Label("Relationships", systemImage: "point.3.connected.trianglepath.dotted") }
            .tag(Tab.relationships)

            ContactsListView(store: store, statusFilter: $statusFilter)
                .tabItem { Label("Contacts", systemImage: "person.crop.rectangle.stack") }
                .tag(Tab.contacts)

            CardFeedView(
                viewModel: CardFeedViewModel(apiClient: apiClient, currentUserId: authService.userId),
                authService: authService,
                awardsService: awardsService,
                onContactSaved: { store.upsert($0) }
            )
            .tabItem { Label("Cards", systemImage: "rectangle.stack") }
            .tag(Tab.cards)

            MeView(authService: authService, awardsService: awardsService, apiClient: apiClient)
                .tabItem { Label("Me", systemImage: "person.crop.circle") }
                .tag(Tab.me)
        }
        .tint(RT.blue)
        .task { await store.loadIfNeeded() }
    }
}

/// Account, progress and settings.
struct MeView: View {
    @ObservedObject var authService: AuthService
    @ObservedObject var awardsService: AwardsService
    let apiClient: NetworkAPIClient
    @State private var isConfirmingLogout = false
    @State private var isOpeningWeb = false
    @State private var webError: String?

    private static let networkHost = URL(string: "https://network.taliferro.tech")!
    private static let toddHost = URL(string: "https://todd.taliferro.tech")!

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink { profileView } label: { Label("Profile", systemImage: "person.crop.circle") }
                    NavigationLink {
                        GettingStartedView(
                            apiClient: apiClient,
                            profileView: { AnyView(profileView) },
                            onOpenWeb: { openWeb(path: $0, host: Self.networkHost) }
                        )
                    } label: { Label("Getting Started", systemImage: "checklist") }
                    NavigationLink {
                        AwardsGridView(awardsService: awardsService)
                            .task { await awardsService.sync() }
                    } label: { Label("Awards", systemImage: "rosette") }
                }
                Section("On the web") {
                    Button { openWeb(path: "/contact-import", host: Self.networkHost) } label: {
                        Label("Import a CSV file", systemImage: "square.and.arrow.down")
                    }
                    Button { openWeb(path: "/daily-momentum", host: Self.toddHost) } label: {
                        Label("Daily Momentum in TODD", systemImage: "flame")
                    }
                }
                .disabled(isOpeningWeb)
                Section {
                    Button(role: .destructive) { isConfirmingLogout = true } label: {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Me")
            .alert("Log out?", isPresented: $isConfirmingLogout) {
                Button("Cancel", role: .cancel) {}
                Button("Log Out", role: .destructive) { try? authService.signOut() }
            } message: {
                Text("Contacts saved on this iPhone are removed. You can sign in again with your TODD account.")
            }
            .alert("Couldn't open that page", isPresented: Binding(get: { webError != nil }, set: { if !$0 { webError = nil } })) {
                Button("OK") { webError = nil }
            } message: {
                Text(webError ?? "")
            }
        }
    }

    /// TODDProfileKit's shared profile screen, including Delete Account.
    private var profileView: some View {
        let authService = self.authService
        return ProfileView(
            api: ProfileAPI(
                baseURL: AppConfig.fromBundle().apiBaseURL,
                idToken: { try await authService.freshIdToken() }
            ),
            appName: "Relationships",
            accent: RT.blue,
            onOpenWebSettings: { openWeb(path: "/update-profile", host: Self.toddHost) },
            onAccountDeleted: {
                OnboardingProfileDraft.clear()
                try? authService.signOut()
            }
        ) {
            RT.bg
        }
    }

    /// Opens a page already signed in (TODDAuthKit WebHandoff).
    private func openWeb(path: String, host: URL) {
        isOpeningWeb = true
        Task {
            defer { isOpeningWeb = false }
            do {
                let idToken = try await authService.freshIdToken()
                try await WebHandoff.open(path: path, idToken: idToken, apiBaseURL: AppConfig.fromBundle().apiBaseURL, webBaseURL: host)
            } catch {
                webError = "Please try again in a moment."
            }
        }
    }
}

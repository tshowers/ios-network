import SwiftUI

/// The main screen: a real `UIPageViewController` page curl (`PageCurlView`),
/// not a hand-rolled gesture stack — the "turning a page in a premium
/// business card book" brief, matched literally with forward AND backward
/// swipes. Near-zero chrome on purpose: search + settings only, the card is
/// the interface.
struct CardFeedView: View {
    @StateObject var viewModel: CardFeedViewModel
    @ObservedObject var authService: AuthService
    @State private var isShowingSearch = false
    @State private var isComposing = false
    @State private var isShowingStatus = false
    @State private var shareItem: IdentifiableURL?

    var body: some View {
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
                        }
                    )
                    actionBar(for: card)
                } else {
                    emptyState
                }
            }
        }
        .task {
            await viewModel.loadInitial()
            viewModel.loadTotalContactsIfNeeded()
            if let card = viewModel.currentCard {
                viewModel.loadInsightIfNeeded(for: card)
            }
        }
        .sheet(isPresented: $isComposing) {
            if let card = viewModel.currentCard {
                ComposeWithMayaView(viewModel: ComposeWithMayaViewModel(card: card, apiClient: viewModel.apiClient))
            }
        }
        .sheet(item: $shareItem) { item in
            ActivityShareSheet(activityItems: [item.url])
        }
        .sheet(isPresented: $isShowingStatus) {
            NetworkStatusView(apiClient: viewModel.apiClient)
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Menu {
                Button {
                    isShowingStatus = true
                } label: {
                    Label("Network Status", systemImage: "gauge.medium")
                }
                Button(role: .destructive) {
                    try? authService.signOut()
                } label: {
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "line.3.horizontal")
            }

            Spacer()

            positionCounter

            Spacer()

            Menu {
                Button {
                    isShowingSearch.toggle()
                } label: {
                    Label(isShowingSearch ? "Hide Search" : "Search", systemImage: "magnifyingglass")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
        }
        .font(.title3)
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, isShowingSearch ? 0 : 8)
        .background(
            // White icons/text need a guaranteed-dark patch under them
            // regardless of which part of the background image ends up here
            // (device aspect ratio varies where the wave band lands) -
            // without this the header can go fully invisible, not just hard
            // to read.
            LinearGradient(
                colors: [.black.opacity(0.35), .black.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 90)
            .ignoresSafeArea(edges: .top)
        )

        if isShowingSearch {
            searchBar
        }
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
        .background(.white.opacity(0.15), in: Capsule())
    }

    private var searchBar: some View {
        HStack {
            TextField("investors in Seattle, or who should I talk to today?", text: $viewModel.searchQuery)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.search)
                .onSubmit { Task { await viewModel.runSearch() } }

            if !viewModel.searchQuery.isEmpty {
                Button("Clear") { Task { await viewModel.clearSearch() } }
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private func actionBar(for card: ContactCard) -> some View {
        let isSelf = viewModel.isSelf(card)

        return HStack(spacing: 12) {
            if !isSelf {
                Button {
                    isComposing = true
                } label: {
                    Label("Maya", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            // Two near-identical branches rather than one button with a
            // ternary style - .buttonStyle(.bordered vs .borderedProminent)
            // are different concrete types, which a ternary can't unify.
            // Self gets the prominent style since Share is its only action.
            if isSelf {
                Button {
                    if let url = ShareCardBuilder.temporaryVCardFile(for: card) {
                        shareItem = IdentifiableURL(url: url)
                    }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    if let url = ShareCardBuilder.temporaryVCardFile(for: card) {
                        shareItem = IdentifiableURL(url: url)
                    }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
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
            Spacer()
        }
    }
}

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

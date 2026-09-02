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
                        },
                        onMaya: { isComposing = true },
                        onShare: { card in
                            if let url = ShareCardBuilder.temporaryVCardFile(for: card) {
                                shareItem = IdentifiableURL(url: url)
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
        VStack(spacing: 8) {
            HStack(spacing: 14) {
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
                        .font(.system(size: 21, weight: .semibold))
                        .frame(width: 44, height: 44)
                }

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
            Spacer()
        }
    }
}

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

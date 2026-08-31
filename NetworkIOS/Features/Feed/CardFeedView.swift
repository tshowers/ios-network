import SwiftUI

/// The main screen: a gesture-driven card stack, not a stock paging `TabView` —
/// the current card rises/rotates away and the next one is already peeking
/// underneath, per the "turning a page in a premium business card book" brief.
/// Near-zero chrome on purpose: search + settings only, the card is the interface.
struct CardFeedView: View {
    @StateObject var viewModel: CardFeedViewModel
    @State private var dragOffset: CGSize = .zero
    @State private var isShowingSearch = false
    @State private var isComposing = false
    @State private var shareItem: IdentifiableURL?

    private let swipeDismissThreshold: CGFloat = 120

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if viewModel.isLoading && viewModel.cards.isEmpty {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let card = viewModel.currentCard {
                    cardStack(currentCard: card)
                    actionBar(for: card)
                } else {
                    emptyState
                }
            }
        }
        .task { await viewModel.loadInitial() }
        .sheet(isPresented: $isComposing) {
            if let card = viewModel.currentCard {
                ComposeWithMayaView(viewModel: ComposeWithMayaViewModel(card: card, apiClient: viewModel.apiClient))
            }
        }
        .sheet(item: $shareItem) { item in
            ActivityShareSheet(activityItems: [item.url])
        }
    }

    private var header: some View {
        HStack {
            Button {
                // Settings/menu - deferred, no admin surface in a read-only app yet.
            } label: {
                Image(systemName: "line.3.horizontal")
            }

            Spacer()

            Text("Network")
                .font(.headline)

            Spacer()

            Button {
                isShowingSearch.toggle()
            } label: {
                Image(systemName: isShowingSearch ? "xmark.circle" : "magnifyingglass")
            }
        }
        .font(.title3)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, isShowingSearch ? 0 : 8)

        if isShowingSearch {
            searchBar
        }
    }

    private var searchBar: some View {
        HStack {
            TextField("investors in Seattle, or who should I talk to today?", text: $viewModel.searchQuery)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.search)
                .onSubmit { Task { await viewModel.runSearch() } }

            if !viewModel.searchQuery.isEmpty {
                Button("Clear") { Task { await viewModel.clearSearch() } }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private func cardStack(currentCard: ContactCard) -> some View {
        ZStack {
            if let next = viewModel.nextCard {
                ContactCardView(card: next)
                    .scaleEffect(0.94)
                    .offset(y: 14)
                    .opacity(0.6)
            }

            ContactCardView(card: currentCard, insight: viewModel.insight(for: currentCard))
                .onAppear { viewModel.loadInsightIfNeeded(for: currentCard) }
                .offset(y: dragOffset.height)
                .rotationEffect(.degrees(Double(dragOffset.height / 20)), anchor: .bottom)
                .opacity(1 - min(abs(dragOffset.height) / 400, 0.4))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Only care about vertical intent - this is a swipe-up
                            // stack, not a left/right one.
                            dragOffset = CGSize(width: 0, height: min(value.translation.height, 40))
                        }
                        .onEnded { value in
                            if value.translation.height < -swipeDismissThreshold {
                                withAnimation(.easeIn(duration: 0.22)) {
                                    dragOffset = CGSize(width: 0, height: -900)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                                    viewModel.advance()
                                    dragOffset = .zero
                                }
                            } else {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    dragOffset = .zero
                                }
                            }
                        }
                )
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: dragOffset)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func actionBar(for card: ContactCard) -> some View {
        HStack(spacing: 12) {
            Button {
                isComposing = true
            } label: {
                Label("Email with Maya", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                if let url = ShareCardBuilder.temporaryVCardFile(for: card) {
                    shareItem = IdentifiableURL(url: url)
                }
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
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

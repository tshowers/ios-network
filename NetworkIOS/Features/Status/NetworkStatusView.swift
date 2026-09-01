import SwiftUI

/// Read-only summary of the tenant's whole contact book - the mobile
/// counterpart to `contact/home.component.ts`'s dashboard, minus the email
/// campaign metrics (a different, non-Network domain) and minus anything
/// backed by data this app never asked the backend for (documents,
/// opportunities, notes/ratings/alerts). Tiles, not lists or copy, per the
/// same "gauge/LED cockpit" language the rest of TODD's app homes moved to.
struct NetworkStatusView: View {
    @StateObject private var viewModel: NetworkStatusViewModel
    @Environment(\.dismiss) private var dismiss

    init(apiClient: NetworkAPIClient) {
        _viewModel = StateObject(wrappedValue: NetworkStatusViewModel(apiClient: apiClient))
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundView().ignoresSafeArea()
                Color.black.opacity(0.35).ignoresSafeArea()

                ScrollView {
                    if let stats = viewModel.stats {
                        content(for: stats)
                    } else if viewModel.isLoading {
                        ProgressView().tint(.white).padding(.top, 80)
                    } else if !viewModel.errorMessage.isEmpty {
                        Text(viewModel.errorMessage)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.top, 80)
                    }
                }
            }
            .navigationTitle("Network Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await viewModel.load() }
        .preferredColorScheme(.dark)
    }

    private func content(for stats: NetworkStats) -> some View {
        VStack(spacing: 16) {
            LazyVGrid(columns: columns, spacing: 16) {
                tile(icon: "person.2.fill", value: "\(stats.totalContacts)", label: "Total Contacts", accent: .blue)
                tile(icon: "sparkles", value: "\(stats.contactsAddedToday)", label: "Added Today", accent: .green)
                tile(icon: "star.fill", value: "\(stats.importantContacts)", label: "Important", accent: .yellow)
                tile(icon: "gift.fill", value: "\(stats.birthdaysThisMonth)", label: "Birthdays This Month", accent: .pink)
                tile(icon: "clock.badge.exclamationmark", value: "\(stats.contactsNeedingFollowUp)", label: "Needs Follow-Up", accent: .orange)
                tile(icon: "exclamationmark.triangle.fill", value: "\(stats.staleContacts)", label: "Stale (60+ Days)", accent: .red)
                tile(icon: "envelope.fill", value: "\(stats.contactsWithEmails)", label: "With Email", accent: .blue)
                tile(icon: "link", value: "\(stats.contactsWithLinkedIn)", label: "With LinkedIn", accent: .blue)
            }

            if !stats.contactsByStatus.isEmpty {
                statusBreakdown(stats.contactsByStatus)
            }
        }
        .padding(20)
    }

    private func tile(icon: String, value: String, label: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(accent)
                Spacer()
                Circle().fill(accent).frame(width: 8, height: 8)
            }
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func statusBreakdown(_ byStatus: [String: Int]) -> some View {
        let sorted = byStatus.sorted { $0.value > $1.value }
        return VStack(alignment: .leading, spacing: 12) {
            Text("By Relationship Status")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))

            VStack(spacing: 0) {
                ForEach(sorted, id: \.key) { status, count in
                    HStack {
                        Circle().fill(.blue).frame(width: 6, height: 6)
                        Text(status).foregroundStyle(.white)
                        Spacer()
                        Text("\(count)").foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.vertical, 10)
                    if status != sorted.last?.key {
                        Divider().overlay(.white.opacity(0.1))
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

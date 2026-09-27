import SwiftUI

/// Adaptive dashboard for the Network home/status experience. This view is
/// independent of the fixed contact-page composition and may scroll on iPad.
struct NetworkStatusView: View {
    @StateObject private var viewModel: NetworkStatusViewModel
    @Environment(\.colorScheme) private var colorScheme

    init(apiClient: NetworkAPIClient) {
        _viewModel = StateObject(wrappedValue: NetworkStatusViewModel(apiClient: apiClient))
    }

    var body: some View {
        GeometryReader { geometry in
            let theme = NetworkTheme(colorScheme: colorScheme)
            let columnCount = geometry.size.width > 900 ? 4 : 2
            let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: columnCount)

            ScrollView {
                if let stats = viewModel.stats {
                    dashboard(stats, columns: columns, theme: theme)
                } else if viewModel.isLoading {
                    ProgressView().tint(theme.primaryText).padding(.top, 80)
                } else {
                    Text(viewModel.errorMessage)
                        .foregroundStyle(theme.primaryText)
                        .padding(.top, 80)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BackgroundView().ignoresSafeArea())
        }
        .navigationTitle("Network Status")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    private func dashboard(_ stats: NetworkStats, columns: [GridItem], theme: NetworkTheme) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            commandDeck(stats, theme: theme)

            panel("Business Health", theme: theme) {
                LazyVGrid(columns: columns, spacing: 14) {
                    healthTile("person.2.fill", "Relationship Health", relationshipHealth(stats), "\(stats.contactsNeedingFollowUp) need attention", .red, theme)
                    healthTile("doc.text.magnifyingglass", "Data Readiness", percentage(stats.contactsWithEmails, stats.totalContacts), "\(max(0, stats.totalContacts - stats.contactsWithEmails)) need enrichment", .orange, theme)
                    healthTile("antenna.radiowaves.left.and.right", "Reachability", percentage(stats.contactsWithEmails, stats.totalContacts), "\(stats.contactsWithEmails) with email", .green, theme)
                    healthTile("arrow.up.right", "Relief Progress", percentage(stats.contactsWithLinkedIn, stats.totalContacts), "\(stats.contactsWithLinkedIn) with LinkedIn", .blue, theme)
                }
            }

            panel("Care Cycle", theme: theme) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Symptom, treatment, relief, and proof")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.primaryText)
                    Text("Each signal shows what is happening across the relationship network and where TODD can help next.")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                    diagnosisRow("Relationships need attention", value: stats.contactsNeedingFollowUp, detail: "contacts have not been contacted recently", tone: .orange, theme: theme)
                    diagnosisRow("Contact information is incomplete", value: max(0, stats.totalContacts - stats.contactsWithEmails), detail: "records do not currently have an email path", tone: .red, theme: theme)
                    diagnosisRow("Important relationships", value: stats.importantContacts, detail: "contacts are marked important", tone: .yellow, theme: theme)
                    diagnosisRow("Recent additions", value: stats.contactsAddedToday, detail: "contacts were added today", tone: .green, theme: theme)
                }
            }

            if !stats.contactsByStatus.isEmpty {
                panel("By Relationship Status", theme: theme) {
                    let sorted = stats.contactsByStatus.sorted { $0.value > $1.value }
                    VStack(spacing: 0) {
                        ForEach(sorted, id: \.key) { status, count in
                            HStack {
                                Circle().fill(.blue).frame(width: 7, height: 7)
                                Text(status.isEmpty ? "Unassigned" : status)
                                Spacer()
                                Text("\(count)")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(theme.primaryText)
                            .padding(.vertical, 10)
                            if status != sorted.last?.key {
                                Divider().overlay(theme.border)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
    }

    private func commandDeck(_ stats: NetworkStats, theme: NetworkTheme) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Text("TODD COMMAND DECK")
                    .font(.caption.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(.blue)
                Label("Relationships", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(theme.primaryText)
                Text("Diagnose relationship pain, watch TODD treat it, and see which contacts are moving back toward momentum.")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 20)
            VStack(alignment: .trailing, spacing: 4) {
                Text("NETWORK HEALTH")
                    .font(.caption.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(theme.secondaryText)
                Text("\(relationshipHealth(stats))%")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.primaryText)
            }
        }
        .padding(22)
        .background(theme.panelStrong, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(theme.border, lineWidth: 1))
    }

    private func panel<Content: View>(_ title: String, theme: NetworkTheme, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(theme.secondaryText)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(theme.border, lineWidth: 1))
    }

    private func healthTile(_ icon: String, _ title: String, _ value: Int, _ detail: String, _ accent: Color, _ theme: NetworkTheme) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon).font(.title3).foregroundStyle(accent)
            Text("\(value)%").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(theme.primaryText)
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(theme.primaryText)
            Text(detail).font(.caption).foregroundStyle(theme.secondaryText).fixedSize(horizontal: false, vertical: true)
            ProgressView(value: Double(value), total: 100).tint(accent)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.panelStrong, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(theme.border, lineWidth: 1))
    }

    private func diagnosisRow(_ title: String, value: Int, detail: String, tone: Color, theme: NetworkTheme) -> some View {
        HStack(spacing: 14) {
            Circle().fill(tone).frame(width: 14, height: 14).shadow(color: tone.opacity(0.55), radius: 6)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline).foregroundStyle(theme.primaryText)
                Text("\(value) \(detail)").font(.subheadline).foregroundStyle(theme.secondaryText)
            }
            Spacer()
        }
        .padding(14)
        .background(theme.panelStrong, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func percentage(_ value: Int, _ total: Int) -> Int {
        guard total > 0 else { return 0 }
        return min(100, max(0, Int((Double(value) / Double(total) * 100).rounded())))
    }

    private func relationshipHealth(_ stats: NetworkStats) -> Int {
        percentage(max(0, stats.totalContacts - stats.contactsNeedingFollowUp), stats.totalContacts)
    }
}

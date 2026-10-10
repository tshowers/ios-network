import SwiftUI

/// The Contacts tab (handoff 15c / 15m): every contact, searchable, filtered
/// by status, sortable, with a floating Add button.
struct ContactsListView: View {
    @ObservedObject var store: ContactStore
    /// Set by other tabs (e.g. a Pipeline lane) to open filtered.
    @Binding var statusFilter: String?
    @State private var path: [String] = []
    @State private var searchText = ""
    @State private var sort: ContactSort = .name
    @State private var isAdding = false
    @State private var pendingDelete: ContactSummary?
    @State private var deleteError: String?
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Contacts")
                .searchable(text: $searchText, prompt: "Search name, company, or email")
                .toolbar { toolbar }
                .refreshable { await store.refresh() }
                .task {
                    await store.loadIfNeeded()
                    if let target = RelationshipsDemo.startTarget, path.isEmpty {
                        if target == "new" { isAdding = true } else { path = [target] }
                    }
                }
                .navigationDestination(for: String.self) { contactId in
                    ContactDetailView(contactId: contactId, store: store)
                }
                .overlay(alignment: .bottomTrailing) { addButton }
                .sheet(isPresented: $isAdding) {
                    ContactEditorView(mode: .create, apiClient: store.apiClient) { created in
                        store.upsert(created)
                        path.append(created.contactId)
                    }
                }
                .confirmationDialog(
                    "Delete \(pendingDelete?.displayName ?? "this contact")?",
                    isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                    titleVisibility: .visible
                ) {
                    Button("Delete Contact", role: .destructive) {
                        if let contact = pendingDelete { delete(contact) }
                    }
                } message: {
                    Text("This removes the contact everywhere you use TODD, including the web.")
                }
                .alert("Couldn't delete", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
                    Button("OK") { deleteError = nil }
                } message: {
                    Text(deleteError ?? "")
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !store.hasLoadedOnce && store.isLoading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.contacts.isEmpty {
            emptyState
        } else {
            list
        }
    }

    private var list: some View {
        let rows = visibleContacts
        return List {
            Section {
                ForEach(rows) { contact in
                    NavigationLink(value: contact.contactId) {
                        ContactRow(contact: contact)
                    }
                    .swipeActions(edge: .trailing) {
                        if !contact.isSelf {
                            Button(role: .destructive) { pendingDelete = contact } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .swipeActions(edge: .leading) {
                        if !contact.phone.isEmpty {
                            Button { reach(contact, type: "call") } label: { Label("Call", systemImage: "phone.fill") }
                                .tint(.green)
                        }
                        if !contact.email.isEmpty {
                            Button { reach(contact, type: "email") } label: { Label("Email", systemImage: "envelope.fill") }
                                .tint(.blue)
                        }
                    }
                }
            } header: {
                header(count: rows.count)
            }
        }
        .listStyle(.plain)
    }

    private func header(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let statusFilter {
                Button {
                    self.statusFilter = nil
                } label: {
                    RTPill(text: statusFilter.isEmpty ? "No status" : statusFilter, tint: RT.statusTint(statusFilter), systemImage: "xmark")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear status filter")
            }
            Text("\(count) of \(store.contacts.count) contacts")
                .font(.footnote)
                .foregroundStyle(RT.muted)
            if !store.errorMessage.isEmpty {
                Text(store.errorMessage).font(.footnote).foregroundStyle(RT.tintRed.fg)
            }
        }
        .textCase(nil)
        .padding(.vertical, 4)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Sort", selection: $sort) {
                    ForEach(ContactSort.allCases) { option in
                        Label(option.label, systemImage: option.icon).tag(option)
                    }
                }
                Divider()
                Picker("Status", selection: $statusFilter) {
                    Text("All statuses").tag(String?.none)
                    ForEach(statusOptions, id: \.self) { status in
                        Text("\(status.isEmpty ? "No status" : status) (\(store.countsByStatus[status] ?? 0))")
                            .tag(String?.some(status))
                    }
                }
            } label: {
                Image(systemName: statusFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
            }
            .accessibilityLabel("Sort and filter")
        }
    }

    private var addButton: some View {
        Button {
            isAdding = true
        } label: {
            Label("Add", systemImage: "plus")
                .font(.system(size: 17, weight: .bold))
                .padding(.horizontal, 22)
                .frame(height: 56)
                .foregroundStyle(RT.bg)
                .background(RT.text, in: Capsule())
                .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 16)
        .accessibilityLabel("Add contact")
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.crop.rectangle.stack")
                .font(.system(size: 44))
                .foregroundStyle(RT.muted)
            Text(store.errorMessage.isEmpty ? "No contacts yet" : store.errorMessage)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Add the people you work with, and Relationships keeps track of who needs attention next.")
                .font(.subheadline)
                .foregroundStyle(RT.muted)
                .multilineTextAlignment(.center)
            Button("Add a Contact") { isAdding = true }
                .buttonStyle(.borderedProminent)
                .tint(RT.blue)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data

    /// Pipeline stages first (in order), then any custom statuses in use.
    private var statusOptions: [String] {
        let inUse = Set(store.countsByStatus.keys)
        let pipeline = PipelineStage.all.filter { inUse.contains($0) }
        let custom = inUse.subtracting(PipelineStage.all).filter { !$0.isEmpty }.sorted()
        return pipeline + custom + (inUse.contains("") ? [""] : [])
    }

    private var visibleContacts: [ContactSummary] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let terms = query.split(separator: " ").map(String.init)
        let filtered = store.contacts.filter { contact in
            if let statusFilter, contact.status != statusFilter { return false }
            guard !terms.isEmpty else { return true }
            let haystack = [contact.displayName, contact.companyName, contact.email, contact.profession, contact.city, contact.status]
                .joined(separator: " ")
                .lowercased()
            return terms.allSatisfy { haystack.contains($0) }
        }
        return sort.sorted(filtered)
    }

    private func reach(_ contact: ContactSummary, type: String) {
        let url: URL?
        if type == "call" {
            url = URL(string: "tel:\(contact.phone.filter { $0.isNumber || $0 == "+" })")
        } else {
            url = URL(string: "mailto:\(contact.email)")
        }
        guard let url else { return }
        openURL(url)
        Task {
            if let updated = try? await store.apiClient.logInteraction(contactId: contact.contactId, type: type) {
                store.upsert(updated)
            }
        }
    }

    private func delete(_ contact: ContactSummary) {
        pendingDelete = nil
        Task {
            do {
                try await store.delete(id: contact.contactId)
            } catch {
                deleteError = error.localizedDescription
            }
        }
    }
}

enum ContactSort: String, CaseIterable, Identifiable {
    case name, recentlyAdded, lastContacted, needsAttention

    var id: String { rawValue }

    var label: String {
        switch self {
        case .name: return "Name"
        case .recentlyAdded: return "Recently added"
        case .lastContacted: return "Recently contacted"
        case .needsAttention: return "Needs attention"
        }
    }

    var icon: String {
        switch self {
        case .name: return "textformat"
        case .recentlyAdded: return "clock"
        case .lastContacted: return "phone.arrow.up.right"
        case .needsAttention: return "exclamationmark.circle"
        }
    }

    func sorted(_ contacts: [ContactSummary]) -> [ContactSummary] {
        switch self {
        case .name:
            return contacts.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .recentlyAdded:
            return contacts.sorted { ($0.dateAddedDate ?? .distantPast) > ($1.dateAddedDate ?? .distantPast) }
        case .lastContacted:
            return contacts.sorted { ($0.lastContactedDate ?? .distantPast) > ($1.lastContactedDate ?? .distantPast) }
        case .needsAttention:
            // Never contacted first, then longest since last contact.
            return contacts.sorted { ($0.lastContactedDate ?? .distantPast) < ($1.lastContactedDate ?? .distantPast) }
        }
    }
}

/// A Contacts row (handoff 15m): avatar, name, role · company, status pill.
struct ContactRow: View {
    let contact: ContactSummary

    var body: some View {
        HStack(spacing: 12) {
            RTAvatar(initials: contact.initials, logoURL: contact.logoUrl.flatMap(URL.init(string:)), size: 40)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(contact.displayName.isEmpty ? "Unnamed contact" : contact.displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(RT.text)
                        .lineLimit(1)
                    if contact.isSelf {
                        Text("You").font(.caption.bold()).foregroundStyle(RT.muted)
                    }
                    if contact.important {
                        Image(systemName: "star.fill").font(.caption2).foregroundStyle(RT.tintYellow.fg)
                            .accessibilityLabel("Important")
                    }
                }
                if !contact.subtitle.isEmpty {
                    Text(contact.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(RT.muted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if !contact.status.isEmpty {
                RTPill(text: contact.status, tint: RT.statusTint(contact.status))
            }
        }
        .padding(.vertical, 4)
    }
}

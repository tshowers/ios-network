import SwiftUI

/// One contact (handoff 15u / 15v). Loads the full record; until it
/// arrives, the list row's data fills the header so the screen never blanks.
struct ContactDetailView: View {
    let contactId: String
    @ObservedObject var store: ContactStore
    @State private var detail: ContactDetail?
    @State private var errorMessage = ""
    @State private var isEditing = false
    @State private var editingNote: NoteDraft?
    @State private var isConfirmingDelete = false
    @State private var isWorking = false
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    private var summary: ContactSummary? { store.contact(id: contactId) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                identity
                quickActions
                if let detail {
                    stageCard(detail)
                    if !detail.storedInsight.isEmpty { insightCard(detail.storedInsight) }
                    notesCard(detail)
                    if detail.company.hasDetails { companyCard(detail.company) }
                    if !detail.profileTypes.isEmpty { profileTypesCard(detail.profileTypes) }
                    if !detail.emailAddresses.isEmpty || !detail.phoneNumbers.isEmpty { communicationCard(detail) }
                    if !detail.recentInteractions.isEmpty { activityCard(detail) }
                } else if !errorMessage.isEmpty {
                    Text(errorMessage).font(.subheadline).foregroundStyle(RT.tintRed.fg)
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(RT.bg)
        .navigationTitle(detail?.displayName ?? summary?.displayName ?? "Contact")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isEditing = true } label: { Label("Edit", systemImage: "square.and.pencil") }
                    .disabled(detail == nil)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { editingNote = NoteDraft() } label: { Label("Add Note", systemImage: "note.text.badge.plus") }
                    Button { log("meeting") } label: { Label("Log a Meeting", systemImage: "person.2") }
                    if detail?.isSelf == false {
                        Divider()
                        Button(role: .destructive) { isConfirmingDelete = true } label: { Label("Delete Contact", systemImage: "trash") }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(detail == nil)
                .accessibilityLabel("More actions")
            }
        }
        .task(id: contactId) { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $isEditing) {
            if let detail {
                ContactEditorView(mode: .edit(detail), apiClient: store.apiClient) { updated in
                    apply(updated)
                }
            }
        }
        .sheet(item: $editingNote) { draft in
            NoteEditorView(draft: draft) { subject, body in
                try await saveNote(draft: draft, subject: subject, body: body)
            }
        }
        .confirmationDialog("Delete this contact?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Contact", role: .destructive) { deleteContact() }
        } message: {
            Text("This removes the contact everywhere you use TODD, including the web.")
        }
    }

    // MARK: - Header

    private var identity: some View {
        let name = detail?.displayName ?? summary?.displayName ?? ""
        let companyName = detail?.company.name ?? summary?.companyName ?? ""
        let status = detail?.status ?? summary?.status ?? ""
        let logo = (detail?.company.logoUrl ?? summary?.logoUrl).flatMap(URL.init(string:))
        return VStack(alignment: .leading, spacing: 8) {
            RTAvatar(initials: ContactFormatting.initials(name), logoURL: logo, size: 72)
            if !companyName.isEmpty {
                if let url = detail?.company.url.flatMap(URL.init(string:)) {
                    Link(companyName, destination: url)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(RT.tintBlue.fg)
                } else {
                    Text(companyName).font(.system(size: 14, weight: .bold)).foregroundStyle(RT.tintBlue.fg)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(name.isEmpty ? "Unnamed contact" : name)
                    .font(.system(size: 34, weight: .bold))
                    .tracking(-1.2)
                    .foregroundStyle(RT.text)
                if detail?.isSelf ?? summary?.isSelf ?? false {
                    Text("(You)").font(.headline).foregroundStyle(RT.muted)
                }
            }
            if let profession = detail?.profession ?? summary?.profession, !profession.isEmpty {
                Text(profession).font(.system(size: 16)).foregroundStyle(RT.muted)
            }
            HStack(spacing: 6) {
                if let category = detail?.category, !category.isEmpty {
                    RTPill(text: category, tint: RT.tintGrey)
                }
                statusMenu(current: status)
            }
            if let address = detail?.addresses.first(where: { !$0.isEmpty }) {
                Text(address.singleLine).font(.system(size: 14)).foregroundStyle(RT.muted).lineLimit(1)
            }
            if let last = ContactFormatting.relative(detail?.lastContacted ?? summary?.lastContacted) {
                Text("Last contacted \(last == "Today" || last == "Yesterday" ? last.lowercased() : last)").font(.system(size: 13)).foregroundStyle(RT.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    /// The status pill is the control: tap to move the contact to another stage.
    private func statusMenu(current: String) -> some View {
        Menu {
            ForEach(PipelineStage.all, id: \.self) { stage in
                Button { setStatus(stage) } label: {
                    if stage == current { Label(stage, systemImage: "checkmark") } else { Text(stage) }
                }
            }
            if !current.isEmpty && !PipelineStage.all.contains(current) {
                Divider()
                Label(current, systemImage: "checkmark")
            }
        } label: {
            RTPill(text: current.isEmpty ? "Set status" : current, tint: RT.statusTint(current), systemImage: "chevron.down")
        }
        .disabled(detail == nil || isWorking)
        .accessibilityLabel("Status: \(current.isEmpty ? "none" : current). Change status")
    }

    @ViewBuilder
    private var quickActions: some View {
        let phone = detail?.phoneNumbers.first?.phoneNumber ?? summary?.phone ?? ""
        let email = detail?.emailAddresses.first?.emailAddress ?? summary?.email ?? ""
        if !phone.isEmpty || !email.isEmpty {
            HStack(spacing: 8) {
                if !phone.isEmpty {
                    quickAction("Call", icon: "phone.fill", tint: RT.tintGreen) { reach(phone: phone, type: "call") }
                    quickAction("Text", icon: "message.fill", tint: RT.tintCyan) { reach(phone: phone, type: "text") }
                }
                if !email.isEmpty {
                    quickAction("Email", icon: "envelope.fill", tint: RT.tintBlue) { reach(email: email) }
                }
            }
        }
    }

    private func quickAction(_ title: String, icon: String, tint: RT.Tint, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 15, weight: .bold))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(tint.fg)
                .background(tint.bg, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Cards

    @ViewBuilder
    private func stageCard(_ detail: ContactDetail) -> some View {
        if let stage = detail.stage {
            RTCard {
                HStack {
                    RTEyebrow(text: "Communication stage")
                    Spacer()
                    Text("\(stage.number) of \(EmailStage.allCases.count)").font(.system(size: 14)).foregroundStyle(RT.muted)
                }
                HStack(spacing: 3) {
                    ForEach(EmailStage.allCases) { step in
                        Capsule()
                            .fill(barColor(step: step, current: stage))
                            .frame(height: 8)
                    }
                }
                .accessibilityHidden(true)
                HStack(alignment: .firstTextBaseline) {
                    Text(stage.label).font(.system(size: 17, weight: .bold)).foregroundStyle(RT.text)
                    Spacer()
                    if let next = stage.next {
                        Text("Next: \(next.label)").font(.system(size: 13)).foregroundStyle(RT.muted)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func barColor(step: EmailStage, current: EmailStage) -> Color {
        if step.number > current.number { return RT.surface2 }
        if step == .won { return RT.tintGreen.fg }
        if step == .lost { return RT.tintRed.fg }
        return RT.blue
    }

    private func insightCard(_ insight: String) -> some View {
        RTCard {
            Label {
                Text(insight).font(.system(size: 15)).foregroundStyle(RT.text)
            } icon: {
                Image(systemName: "sparkles").foregroundStyle(RT.tintViolet.fg)
            }
        }
    }

    private func notesCard(_ detail: ContactDetail) -> some View {
        RTCard {
            HStack {
                Text("Notes").font(.system(size: 20, weight: .bold)).foregroundStyle(RT.text)
                Spacer()
                Button { editingNote = NoteDraft() } label: { Label("Add", systemImage: "plus") }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(RT.tintBlue.fg)
            }
            if detail.notes.isEmpty {
                Text("Capture what you learn after a call or meeting, while it's fresh.")
                    .font(.system(size: 14)).foregroundStyle(RT.muted)
            }
            ForEach(detail.notes) { note in
                Button { editingNote = NoteDraft(note: note) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        if !note.subject.isEmpty || note.lastUpdated != nil {
                            HStack {
                                if !note.subject.isEmpty { Text(note.subject).font(.system(size: 15, weight: .bold)) }
                                Spacer()
                                if let when = ContactFormatting.relative(note.lastUpdated) {
                                    Text(when).font(.system(size: 13)).foregroundStyle(RT.muted)
                                }
                            }
                        }
                        Text(note.body).font(.system(size: 16)).multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(RT.text)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RT.bg, in: RoundedRectangle(cornerRadius: RT.panelRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button { editingNote = NoteDraft(note: note) } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { deleteNote(note) } label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
    }

    private func companyCard(_ company: ContactCompany) -> some View {
        RTCard {
            Text("Company").font(.system(size: 20, weight: .bold)).foregroundStyle(RT.text)
            if !company.publicInfo.isEmpty {
                panel {
                    RTEyebrow(text: "Public info")
                    Text(company.publicInfo).font(.system(size: 15))
                }
            }
            let facts = [("DBA", company.dba), ("Employees", company.numberOfEmployees), ("SIC code", company.sicCode)].filter { !$0.1.isEmpty }
            if !facts.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(facts, id: \.0) { fact in
                        panel {
                            Text(fact.0).font(.system(size: 12)).foregroundStyle(RT.muted)
                            Text(fact.1).font(.system(size: 18, weight: .bold))
                        }
                    }
                }
            }
            if !company.capabilities.isEmpty {
                RTEyebrow(text: "Capabilities")
                FlowLayout(spacing: 6) {
                    ForEach(company.capabilities, id: \.self) { RTPill(text: $0, tint: RT.tintBlue) }
                }
            }
            ForEach(Array(company.addresses.filter { !$0.isEmpty }.enumerated()), id: \.offset) { _, address in
                panel {
                    RTEyebrow(text: address.addressType.isEmpty ? "Address" : address.addressType)
                    if !address.streetAddress.isEmpty { Text(address.streetAddress) }
                    Text([address.cityLine, address.country].filter { !$0.isEmpty }.joined(separator: ", "))
                }
                .font(.system(size: 14))
            }
        }
        .foregroundStyle(RT.text)
    }

    private func profileTypesCard(_ types: [String]) -> some View {
        RTCard {
            Text("Profile types").font(.system(size: 20, weight: .bold)).foregroundStyle(RT.text)
            FlowLayout(spacing: 6) {
                ForEach(types, id: \.self) { RTPill(text: $0, tint: RT.tintViolet) }
            }
        }
    }

    private func communicationCard(_ detail: ContactDetail) -> some View {
        RTCard {
            Text("Communication").font(.system(size: 20, weight: .bold)).foregroundStyle(RT.text)
            ForEach(detail.emailAddresses, id: \.self) { email in
                commRow(icon: "envelope.fill", tint: RT.tintBlue, label: email.emailAddressType.isEmpty ? "Email" : email.emailAddressType, value: email.emailAddress) {
                    reach(email: email.emailAddress)
                }
            }
            ForEach(detail.phoneNumbers, id: \.self) { phone in
                commRow(icon: "phone.fill", tint: RT.tintGreen, label: phone.phoneNumberType.isEmpty ? "Phone" : phone.phoneNumberType, value: phone.phoneNumber) {
                    reach(phone: phone.phoneNumber, type: "call")
                }
            }
        }
    }

    private func commRow(icon: String, tint: RT.Tint, label: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(tint.fg)
                    .frame(width: 36, height: 36)
                    .background(tint.bg, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(label).font(.system(size: 12)).foregroundStyle(RT.muted)
                    Text(value).font(.system(size: 14, weight: .bold)).foregroundStyle(RT.text).lineLimit(1).truncationMode(.middle)
                }
                Spacer()
            }
            .padding(12)
            .background(RT.bg, in: RoundedRectangle(cornerRadius: RT.panelRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func activityCard(_ detail: ContactDetail) -> some View {
        RTCard {
            HStack {
                Text("Recent activity").font(.system(size: 20, weight: .bold)).foregroundStyle(RT.text)
                Spacer()
                Text("\(detail.interactionsCount) total").font(.system(size: 13)).foregroundStyle(RT.muted)
            }
            ForEach(Array(detail.recentInteractions.prefix(5).enumerated()), id: \.offset) { _, interaction in
                HStack(spacing: 10) {
                    Image(systemName: Self.icon(forInteraction: interaction.type))
                        .foregroundStyle(RT.muted)
                        .frame(width: 22)
                    Text(interaction.type.capitalized).font(.system(size: 15, weight: .semibold))
                    if !interaction.notes.isEmpty {
                        Text(interaction.notes).font(.system(size: 14)).foregroundStyle(RT.muted).lineLimit(1)
                    }
                    Spacer()
                    if let when = ContactFormatting.relative(interaction.date) {
                        Text(when).font(.system(size: 13)).foregroundStyle(RT.muted)
                    }
                }
                .foregroundStyle(RT.text)
            }
        }
    }

    private static func icon(forInteraction type: String) -> String {
        switch type {
        case "call": return "phone"
        case "text": return "message"
        case "email": return "envelope"
        case "meeting": return "person.2"
        default: return "circle"
        }
    }

    private func panel<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) { content() }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RT.bg, in: RoundedRectangle(cornerRadius: RT.panelRadius, style: .continuous))
    }

    // MARK: - Actions

    private func load() async {
        if let demo = RelationshipsDemo.detail(id: contactId) {
            detail = demo
            return
        }
        do {
            let fresh = try await store.apiClient.fetchContact(id: contactId)
            detail = fresh
            errorMessage = ""
            store.upsert(fresh)
        } catch {
            if detail == nil { errorMessage = error.localizedDescription }
        }
    }

    private func apply(_ updated: ContactDetail) {
        detail = updated
        store.upsert(updated)
    }

    private func reach(phone: String, type: String) {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        guard let url = URL(string: "\(type == "text" ? "sms" : "tel"):\(digits)") else { return }
        openURL(url)
        log(type)
    }

    private func reach(email: String) {
        guard let url = URL(string: "mailto:\(email)") else { return }
        openURL(url)
        log("email")
    }

    /// Records the interaction so lastContacted and the activity list stay true.
    private func log(_ type: String) {
        Task {
            if let updated = try? await store.apiClient.logInteraction(contactId: contactId, type: type) {
                apply(updated)
            }
        }
    }

    private func setStatus(_ status: String) {
        guard status != detail?.status else { return }
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                apply(try await store.apiClient.setContactStatus(id: contactId, status: status))
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func saveNote(draft: NoteDraft, subject: String, body: String) async throws {
        let updated: ContactDetail
        if let noteId = draft.noteId {
            updated = try await store.apiClient.updateNote(contactId: contactId, noteId: noteId, subject: subject, body: body)
        } else {
            updated = try await store.apiClient.addNote(contactId: contactId, subject: subject, body: body)
        }
        apply(updated)
    }

    private func deleteNote(_ note: ContactNote) {
        Task {
            if let updated = try? await store.apiClient.deleteNote(contactId: contactId, noteId: note.noteId) {
                apply(updated)
            }
        }
    }

    private func deleteContact() {
        Task {
            do {
                try await store.delete(id: contactId)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// A note being written or edited.
struct NoteDraft: Identifiable {
    let id = UUID()
    var noteId: String?
    var subject = ""
    var body = ""

    init() {}

    init(note: ContactNote) {
        noteId = note.noteId
        subject = note.subject
        body = note.body
    }
}

struct NoteEditorView: View {
    let draft: NoteDraft
    let onSave: (String, String) async throws -> Void
    @State private var subject: String
    @State private var bodyText: String
    @State private var isSaving = false
    @State private var errorMessage = ""
    @FocusState private var bodyFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(draft: NoteDraft, onSave: @escaping (String, String) async throws -> Void) {
        self.draft = draft
        self.onSave = onSave
        _subject = State(initialValue: draft.subject)
        _bodyText = State(initialValue: draft.body)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Subject (optional)", text: $subject)
                TextEditor(text: $bodyText)
                    .frame(minHeight: 180)
                    .focused($bodyFocused)
                if !errorMessage.isEmpty {
                    Text(errorMessage).foregroundStyle(RT.tintRed.fg)
                }
            }
            .navigationTitle(draft.noteId == nil ? "New Note" : "Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .onAppear { bodyFocused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await onSave(subject, bodyText)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

/// Wrapping row layout for pills.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row(y: current.y + current.height + spacing)
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

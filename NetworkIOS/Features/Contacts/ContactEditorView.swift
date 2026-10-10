import SwiftUI

/// Create or edit a contact (handoff 15d / 15n): section chips across the
/// top, a live preview, section cards, and Save. Only "a first name or a
/// company name" blocks saving - the same rule web Network and the backend use.
struct ContactEditorView: View {
    enum Mode {
        case create
        case edit(ContactDetail)
    }

    enum Section: String, CaseIterable, Identifiable {
        case name = "Name", company = "Company", contact = "Contact", status = "Status", notes = "Notes"
        var id: String { rawValue }
    }

    let mode: Mode
    let apiClient: NetworkAPIClient
    let onSaved: (ContactDetail) -> Void

    @State private var input: ContactInput
    @State private var firstNote = ""
    @State private var capabilitiesText: String
    @State private var address: ContactAddress
    @State private var original: String
    @State private var attemptedSave = false
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var isConfirmingDiscard = false
    @Environment(\.dismiss) private var dismiss

    init(mode: Mode, apiClient: NetworkAPIClient, onSaved: @escaping (ContactDetail) -> Void) {
        self.mode = mode
        self.apiClient = apiClient
        self.onSaved = onSaved
        var start: ContactInput
        if case .edit(let detail) = mode {
            start = ContactInput(detail: detail)
        } else {
            start = ContactInput()
            start.emailAddresses = [ContactEmail(emailAddress: "", emailAddressType: "Work")]
            start.phoneNumbers = [ContactPhone(phoneNumber: "", phoneNumberType: "Mobile")]
        }
        _input = State(initialValue: start)
        _capabilitiesText = State(initialValue: start.company.capabilities.joined(separator: ", "))
        _address = State(initialValue: start.addresses.first ?? ContactAddress(addressType: "Office"))
        _original = State(initialValue: Self.fingerprint(start, "", start.addresses.first ?? ContactAddress(addressType: "Office")))
    }

    private var isCreating: Bool {
        if case .create = mode { return true }
        return false
    }

    private var sections: [Section] {
        isCreating ? Section.allCases : Section.allCases.filter { $0 != .notes }
    }

    private var isDirty: Bool { Self.fingerprint(input, firstNote, address) != original }
    private var showsNameError: Bool { attemptedSave && !input.hasIdentity }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    sectionChips(proxy: proxy)
                    ScrollView {
                        VStack(spacing: 12) {
                            preview
                            nameSection.id(Section.name)
                            companySection.id(Section.company)
                            contactSection.id(Section.contact)
                            statusSection.id(Section.status)
                            if isCreating { notesSection.id(Section.notes) }
                            if !errorMessage.isEmpty {
                                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(RT.tintRed.fg)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(16)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .background(RT.bg)
            .navigationTitle(isCreating ? "New contact" : (input.displayName.isEmpty ? "Edit contact" : input.displayName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isDirty { isConfirmingDiscard = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { save() }.fontWeight(.bold)
                    }
                }
            }
            .confirmationDialog("Discard your changes?", isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            }
        }
        .interactiveDismissDisabled(isDirty)
    }

    // MARK: - Chrome

    private func sectionChips(proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(sections.enumerated()), id: \.element) { index, section in
                    Button {
                        withAnimation { proxy.scrollTo(section, anchor: .top) }
                    } label: {
                        HStack(spacing: 6) {
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .frame(width: 22, height: 22)
                                .foregroundStyle(section == .name && showsNameError ? RT.tintRed.fg : RT.text)
                                .background(section == .name && showsNameError ? RT.tintRed.bg : RT.bg, in: Circle())
                            Text(section.rawValue).font(.system(size: 14, weight: .semibold))
                        }
                        .padding(.leading, 6)
                        .padding(.trailing, 12)
                        .frame(height: 36)
                        .foregroundStyle(RT.text)
                        .background(RT.surface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    /// Live preview (handoff "Live preview" card): updates as you type.
    private var preview: some View {
        HStack(spacing: 12) {
            RTAvatar(initials: ContactFormatting.initials(input.displayName), size: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(input.displayName.isEmpty ? "New contact" : input.displayName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(input.displayName.isEmpty ? RT.muted : RT.text)
                let role = [input.profession, input.company.name].map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: ", ")
                if !role.isEmpty { Text(role).font(.system(size: 13)).foregroundStyle(RT.muted) }
                HStack(spacing: 6) {
                    RTPill(text: input.status.isEmpty ? "No status yet" : input.status, tint: RT.statusTint(input.status))
                    if !input.emailAddresses.contains(where: { !$0.emailAddress.trimmingCharacters(in: .whitespaces).isEmpty }) {
                        Text("No email").font(.system(size: 12)).foregroundStyle(RT.muted)
                    }
                    if !input.phoneNumbers.contains(where: { !$0.phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty }) {
                        Text("No phone").font(.system(size: 12)).foregroundStyle(RT.muted)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RT.bg, in: RoundedRectangle(cornerRadius: RT.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: RT.cardRadius, style: .continuous).stroke(RT.surface2, lineWidth: 1))
    }

    // MARK: - Sections

    private var nameSection: some View {
        RTCard {
            sectionTitle(.name)
            EditorField(label: "First name", text: $input.firstName, contentType: .givenName, isError: showsNameError)
            EditorField(label: "Middle name", text: $input.middleName, placeholder: "Optional", contentType: .middleName)
            EditorField(label: "Last name", text: $input.lastName, contentType: .familyName)
            if showsNameError {
                Label("Add a first name or a company name", systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RT.tintRed.fg)
            }
            Toggle("Important contact", isOn: $input.important)
                .font(.system(size: 15, weight: .semibold))
                .tint(RT.blue)
        }
    }

    private var companySection: some View {
        RTCard {
            sectionTitle(.company)
            EditorField(label: "Company", text: $input.company.name, contentType: .organizationName, isError: showsNameError)
            EditorField(label: "Profession or title", text: $input.profession, contentType: .jobTitle)
            EditorField(label: "Website", text: $input.company.url, placeholder: "https://", contentType: .URL, keyboard: .URL)
            EditorField(label: "Capabilities", text: $capabilitiesText, placeholder: "Comma separated, e.g. Design, Staffing")
            VStack(alignment: .leading, spacing: 4) {
                Text("About the company").font(.system(size: 13, weight: .semibold)).foregroundStyle(RT.muted)
                TextField("What they do, who they serve", text: $input.company.publicInfo, axis: .vertical)
                    .lineLimit(2...6)
                    .padding(12)
                    .background(RT.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var contactSection: some View {
        RTCard {
            sectionTitle(.contact)
            ForEach($input.emailAddresses.indices, id: \.self) { index in
                typedRow(
                    value: $input.emailAddresses[index].emailAddress,
                    type: $input.emailAddresses[index].emailAddressType,
                    types: ["Work", "Home", "Other"],
                    placeholder: "Email",
                    keyboard: .emailAddress,
                    contentType: .emailAddress
                ) { input.emailAddresses.remove(at: index) }
            }
            addRowButton("Add email") { input.emailAddresses.append(ContactEmail(emailAddress: "", emailAddressType: "Work")) }
            ForEach($input.phoneNumbers.indices, id: \.self) { index in
                typedRow(
                    value: $input.phoneNumbers[index].phoneNumber,
                    type: $input.phoneNumbers[index].phoneNumberType,
                    types: ["Mobile", "Work", "Home", "Other"],
                    placeholder: "Phone",
                    keyboard: .phonePad,
                    contentType: .telephoneNumber
                ) { input.phoneNumbers.remove(at: index) }
            }
            addRowButton("Add phone") { input.phoneNumbers.append(ContactPhone(phoneNumber: "", phoneNumberType: "Mobile")) }
            EditorField(label: "LinkedIn", text: $input.linkedInUrl, placeholder: "https://linkedin.com/in/…", contentType: .URL, keyboard: .URL)
            EditorField(label: "Street address", text: $address.streetAddress, contentType: .fullStreetAddress)
            HStack(spacing: 8) {
                EditorField(label: "City", text: $address.city, contentType: .addressCity)
                EditorField(label: "State", text: $address.state, contentType: .addressState)
                    .frame(maxWidth: 90)
                EditorField(label: "ZIP", text: $address.zip, contentType: .postalCode, keyboard: .numbersAndPunctuation)
                    .frame(maxWidth: 100)
            }
        }
    }

    private var statusSection: some View {
        RTCard {
            sectionTitle(.status)
            Text("Where this relationship is in your pipeline.").font(.system(size: 14)).foregroundStyle(RT.muted)
            FlowLayout(spacing: 6) {
                statusChoice("", label: "No status")
                ForEach(PipelineStage.all, id: \.self) { statusChoice($0, label: $0) }
                if !input.status.isEmpty && !PipelineStage.all.contains(input.status) {
                    statusChoice(input.status, label: input.status)
                }
            }
        }
    }

    private var notesSection: some View {
        RTCard {
            sectionTitle(.notes)
            TextField("How you met, what they need, what to do next", text: $firstNote, axis: .vertical)
                .lineLimit(3...8)
                .padding(12)
                .background(RT.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Pieces

    private func sectionTitle(_ section: Section) -> some View {
        Text(section.rawValue).font(.system(size: 20, weight: .bold)).foregroundStyle(RT.text)
    }

    private func statusChoice(_ value: String, label: String) -> some View {
        let selected = input.status == value
        return Button {
            input.status = value
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 12)
                .frame(height: 34)
                .foregroundStyle(selected ? RT.bg : RT.text)
                .background(selected ? RT.text : RT.bg, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func typedRow(
        value: Binding<String>,
        type: Binding<String>,
        types: [String],
        placeholder: String,
        keyboard: UIKeyboardType,
        contentType: UITextContentType,
        onRemove: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Menu {
                Picker("Type", selection: type) {
                    ForEach(types, id: \.self) { Text($0).tag($0) }
                }
            } label: {
                HStack(spacing: 2) {
                    Text(type.wrappedValue.isEmpty ? types[0] : type.wrappedValue)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 10))
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(RT.tintBlue.fg)
                .frame(width: 76, alignment: .leading)
            }
            TextField(placeholder, text: value)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill").foregroundStyle(RT.muted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(placeholder.lowercased())")
        }
        .padding(12)
        .background(RT.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func addRowButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "plus.circle.fill").font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(RT.tintBlue.fg)
    }

    // MARK: - Save

    private func save() {
        attemptedSave = true
        errorMessage = ""
        guard input.hasIdentity else { return }

        var payload = input
        payload.company.capabilities = capabilitiesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        // The editor shows one address; keep any others the contact already has.
        var addresses = input.addresses
        if addresses.isEmpty { addresses = [address] } else { addresses[0] = address }
        payload.addresses = addresses.filter { !$0.isEmpty }
        let note = firstNote.trimmingCharacters(in: .whitespacesAndNewlines)
        payload.note = isCreating && !note.isEmpty ? note : nil

        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                let saved: ContactDetail
                if case .edit(let detail) = mode {
                    saved = try await apiClient.updateContact(id: detail.contactId, payload)
                } else {
                    saved = try await apiClient.createContact(payload)
                }
                onSaved(saved)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private static func fingerprint(_ input: ContactInput, _ note: String, _ address: ContactAddress) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let body = (try? encoder.encode(input)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let place = (try? encoder.encode(address)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        return body + note + place
    }
}

/// Labeled text field on a `--bg` panel, with the handoff's red error ring.
struct EditorField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var contentType: UITextContentType?
    var keyboard: UIKeyboardType = .default
    var isError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 13, weight: .semibold)).foregroundStyle(RT.muted)
            TextField(placeholder.isEmpty ? label : placeholder, text: $text)
                .textContentType(contentType)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .default ? .words : .never)
                .autocorrectionDisabled(keyboard != .default)
                .padding(12)
                .background(RT.bg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isError ? RT.tintRed.fg : .clear, lineWidth: 2)
                )
        }
    }
}

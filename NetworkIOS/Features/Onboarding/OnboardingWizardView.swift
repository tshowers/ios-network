import SwiftUI
import TODDAuthKit

/// Pre-sign-in onboarding, shown instead of a cold sign-in wall - the same
/// idea as pulse-ios's `PreAuthSurveyBuilderView`: the user invests a few
/// answers first and signs in at the very end. One question per screen,
/// under a 4-segment progress bar whose first segment ("Download") is
/// already complete - installing the app *was* step one, so everyone
/// starts a quarter of the way done (the endowed-progress effect).
///
/// The questions mirror TODD's first-login profile wizard
/// (`update-profile.component.ts`'s `wizardSteps`); answers are saved to
/// the TODD profile after sign-in by `AuthService.submitOnboardingProfileIfNeeded()`.
/// Returning users skip straight to `SignInView` via "Already have an
/// account?" - shown in place, not as a popup.
struct OnboardingWizardView: View {
    @ObservedObject var authService: AuthService
    @Environment(\.colorScheme) private var colorScheme
    @State private var draft = OnboardingProfileDraft.load()
    @State private var step: Step = .firstName
    @State private var isShowingSignInOnly = false
    @State private var isBootstrapping = false
    @State private var errorMessage = ""
    @State private var isChangingTimezone = false
    @State private var timezoneSearch = ""
    @FocusState private var isFieldFocused: Bool

    private static let accent = Color(red: 0.07, green: 0.24, blue: 0.55)

    var body: some View {
        ZStack {
            BackgroundView().ignoresSafeArea()

            if isShowingSignInOnly {
                VStack(spacing: 0) {
                    HStack {
                        Button {
                            isShowingSignInOnly = false
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                                .font(.body.weight(.semibold))
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    SignInView(authService: authService)
                }
            } else {
                wizard
            }
        }
        .onChange(of: draft) { _, newValue in newValue.save() }
    }

    // MARK: - Wizard

    private var wizard: some View {
        let theme = NetworkTheme(colorScheme: colorScheme)
        return VStack(spacing: 0) {
            header(theme)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    content(theme)
                }
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            footer(theme)
        }
        .animation(.easeInOut(duration: 0.2), value: step)
        .onAppear { isFieldFocused = step.isTextEntry }
        .onChange(of: step) { _, newStep in
            isFieldFocused = newStep.isTextEntry
            if newStep == .signIn {
                draft.isReadyToSubmit = true
            }
        }
    }

    private func header(_ theme: NetworkTheme) -> some View {
        VStack(spacing: 12) {
            HStack {
                if let previous = step.previous {
                    Button {
                        step = previous
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .frame(width: 44, height: 32, alignment: .leading)
                    }
                    .accessibilityLabel("Back")
                }
                Spacer()
                Text("Step \(step.section.rawValue + 1) of \(Section.allCases.count)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
            }
            .frame(height: 32)

            OnboardingProgressBar(step: step, accent: Self.accent, track: theme.border)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func content(_ theme: NetworkTheme) -> some View {
        switch step {
        case .firstName:
            Text("You're already 1 step in - the app is on your phone. Let's set up the rest.")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
            question("What's your first name?", hint: "Network and Maya use it to personalize everything you send.", theme: theme)
            textField("First name", text: $draft.firstName, contentType: .givenName)

        case .lastName:
            question("And your last name?", hint: nil, theme: theme)
            textField("Last name", text: $draft.lastName, contentType: .familyName)

        case .role:
            question("What's your role?", hint: "Pick the closest fit.", theme: theme)
            ChipFlowLayout(spacing: 10) {
                ForEach(OnboardingProfileDraft.roleOptions, id: \.self) { option in
                    chip(option, isSelected: draft.role == option, theme: theme) {
                        draft.role = option
                        isFieldFocused = false
                    }
                }
                chip("Other", isSelected: draft.hasCustomRole, theme: theme) {
                    if !draft.hasCustomRole { draft.role = "" }
                    isFieldFocused = true
                }
            }
            if draft.hasCustomRole {
                textField("Your role", text: $draft.role, contentType: .jobTitle)
            }

        case .company:
            question("What's your company called?", hint: "We'll use it when Maya drafts outreach for you.", theme: theme)
            textField("Company name", text: $draft.companyName, contentType: .organizationName)

        case .helpWith:
            question("What do you want Network to help you with?", hint: "Pick as many as you like.", theme: theme)
            ChipFlowLayout(spacing: 10) {
                ForEach(OnboardingProfileDraft.helpOptions, id: \.self) { option in
                    chip(option, isSelected: draft.helpWith.contains(option), theme: theme) {
                        if draft.helpWith.contains(option) {
                            draft.helpWith.removeAll { $0 == option }
                        } else {
                            draft.helpWith.append(option)
                        }
                    }
                }
            }
            TextField("Anything else? (optional)", text: $draft.helpNote, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(theme.panelStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(theme.border))

        case .timezone:
            question("What timezone is your workday in?", hint: "So reminders and follow-ups land during your business hours.", theme: theme)
            timezonePicker(theme)

        case .signIn:
            question("Last step: create your account", hint: "Sign in to save your answers and open Network.", theme: theme)
            VStack(spacing: 12) {
                SignInWithAppleButtonView(
                    onSignedIn: { Task { await bootstrap() } },
                    onError: { errorMessage = $0.localizedDescription }
                )
                SignInWithGoogleButtonView(
                    onSignedIn: { Task { await bootstrap() } },
                    onError: { errorMessage = $0.localizedDescription }
                )
            }
            .disabled(isBootstrapping)
            .padding(.top, 8)

            if isBootstrapping {
                ProgressView().frame(maxWidth: .infinity)
            }
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func footer(_ theme: NetworkTheme) -> some View {
        VStack(spacing: 12) {
            if step != .signIn {
                HStack(spacing: 12) {
                    if step.isOptional {
                        Button("Skip") { advance() }
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .foregroundStyle(theme.primaryText)
                            .background(theme.panel, in: Capsule())
                    }
                    Button {
                        advance()
                    } label: {
                        Text("Next")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .foregroundStyle(.white)
                            .background(Self.accent.opacity(canAdvance ? 1 : 0.4), in: Capsule())
                    }
                    .disabled(!canAdvance)
                }
            }

            Button("Already have an account? Sign in") {
                isShowingSignInOnly = true
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Pieces

    private func question(_ title: String, hint: String?, theme: NetworkTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title.bold())
                .foregroundStyle(theme.primaryText)
            if let hint {
                Text(hint)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }
        }
    }

    private func textField(_ placeholder: String, text: Binding<String>, contentType: UITextContentType) -> some View {
        let theme = NetworkTheme(colorScheme: colorScheme)
        return TextField(placeholder, text: text)
            .textContentType(contentType)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .font(.title3)
            .padding(14)
            .background(theme.panelStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(theme.border))
            .focused($isFieldFocused)
            .submitLabel(.next)
            .onSubmit { if canAdvance { advance() } }
    }

    private func chip(_ option: String, isSelected: Bool, theme: NetworkTheme, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected { Image(systemName: "checkmark") }
                Text(option)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(isSelected ? .white : theme.primaryText)
            .background(isSelected ? Self.accent : theme.panelStrong, in: Capsule())
            .overlay(Capsule().stroke(isSelected ? Self.accent : theme.border))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func timezonePicker(_ theme: NetworkTheme) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(Self.displayName(for: draft.timezone))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                Text(draft.timezone)
                    .font(.footnote)
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer()
            Button(isChangingTimezone ? "Done" : "Change") {
                isChangingTimezone.toggle()
                timezoneSearch = ""
            }
            .font(.body.weight(.semibold))
        }
        .padding(14)
        .background(theme.panelStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(theme.border))

        if isChangingTimezone {
            TextField("Search cities or regions", text: $timezoneSearch)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(12)
                .background(theme.panelStrong, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(theme.border))

            LazyVStack(spacing: 0) {
                ForEach(filteredTimezones, id: \.self) { identifier in
                    Button {
                        draft.timezone = identifier
                        isChangingTimezone = false
                    } label: {
                        HStack {
                            Text(identifier.replacingOccurrences(of: "_", with: " "))
                                .foregroundStyle(theme.primaryText)
                            Spacer()
                            if identifier == draft.timezone {
                                Image(systemName: "checkmark").foregroundStyle(Self.accent)
                            }
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
    }

    private var filteredTimezones: [String] {
        let query = timezoneSearch.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " ", with: "_")
        let all = TimeZone.knownTimeZoneIdentifiers
        guard !query.isEmpty else { return all }
        return all.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    private static func displayName(for identifier: String) -> String {
        TimeZone(identifier: identifier)?.localizedName(for: .generic, locale: .current) ?? identifier
    }

    // MARK: - Flow

    private var canAdvance: Bool {
        switch step {
        case .firstName: return !draft.firstName.trimmingCharacters(in: .whitespaces).isEmpty
        case .lastName: return !draft.lastName.trimmingCharacters(in: .whitespaces).isEmpty
        case .role: return !draft.role.trimmingCharacters(in: .whitespaces).isEmpty
        case .helpWith: return !draft.helpWith.isEmpty || !draft.helpNote.trimmingCharacters(in: .whitespaces).isEmpty
        case .timezone: return !draft.timezone.isEmpty
        default: return true
        }
    }

    private func advance() {
        if let next = step.next { step = next }
    }

    @MainActor
    private func bootstrap() async {
        errorMessage = ""
        isBootstrapping = true
        defer { isBootstrapping = false }

        do {
            // Also saves the wizard answers - see submitOnboardingProfileIfNeeded().
            try await authService.bootstrapTenant()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Steps

extension OnboardingWizardView {
    /// The 4 segments of the progress bar. `.download` is never a screen -
    /// it's complete before the wizard opens.
    enum Section: Int, CaseIterable {
        case download, aboutYou, business, setUp

        var title: String {
            switch self {
            case .download: return "Download"
            case .aboutYou: return "About you"
            case .business: return "Business"
            case .setUp: return "Get set up"
            }
        }
    }

    enum Step: Int, CaseIterable {
        case firstName, lastName, role, company, helpWith, timezone, signIn

        var section: Section {
            switch self {
            case .firstName, .lastName, .role: return .aboutYou
            case .company, .helpWith: return .business
            case .timezone, .signIn: return .setUp
            }
        }

        var isTextEntry: Bool { [.firstName, .lastName, .company].contains(self) }
        var isOptional: Bool { self == .company }
        var next: Step? { Step(rawValue: rawValue + 1) }
        var previous: Step? { Step(rawValue: rawValue - 1) }

        /// How far through its own section this screen is, 0...1 - drives
        /// the partial fill of the active progress segment.
        var sectionProgress: Double {
            let siblings = Step.allCases.filter { $0.section == section }
            guard let index = siblings.firstIndex(of: self) else { return 0 }
            return Double(index + 1) / Double(siblings.count + 1)
        }
    }
}

private struct OnboardingProgressBar: View {
    let step: OnboardingWizardView.Step
    let accent: Color
    let track: Color

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(OnboardingWizardView.Section.allCases, id: \.rawValue) { section in
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(track)
                            Capsule()
                                .fill(accent)
                                .frame(width: geometry.size.width * fill(for: section))
                        }
                    }
                    .frame(height: 6)

                    HStack(spacing: 4) {
                        if fill(for: section) >= 1 {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(accent)
                        }
                        Text(section.title)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .font(.caption2.weight(section == step.section ? .bold : .medium))
                    .foregroundStyle(section.rawValue <= step.section.rawValue ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: step)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step.section.rawValue + 1) of \(OnboardingWizardView.Section.allCases.count), \(step.section.title)")
    }

    private func fill(for section: OnboardingWizardView.Section) -> Double {
        if section.rawValue < step.section.rawValue { return 1 }
        if section == step.section { return step.sectionProgress }
        return 0
    }
}

/// Wrapping row layout for the "help with" chips.
private struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews: subviews, maxWidth: proposal.width ?? .infinity)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(subviews: subviews, maxWidth: bounds.width) {
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

    private func arrange(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let proposedWidth = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if proposedWidth > maxWidth, !current.indices.isEmpty {
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

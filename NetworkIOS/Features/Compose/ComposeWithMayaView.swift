import SwiftUI

struct ComposeWithMayaView: View {
    @StateObject var viewModel: ComposeWithMayaViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Email with Maya")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
        }
        .task { await viewModel.loadDraft() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.stage {
        case .drafting:
            VStack(spacing: 16) {
                ProgressView()
                Text("Maya is drafting a note to \(viewModel.card.displayName.isEmpty ? "this contact" : viewModel.card.displayName)…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .previewing, .sending:
            previewForm

        case .sent:
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)
                Text("Sent to \(viewModel.card.displayName).")
                    .font(.headline)
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button("Try again") { Task { await viewModel.loadDraft() } }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var previewForm: some View {
        Form {
            if let summary = viewModel.summary, !summary.isEmpty {
                Section("Why Maya suggests this") {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("To") {
                Text(viewModel.card.email.isEmpty ? "No email on file" : viewModel.card.email)
                    .foregroundStyle(viewModel.card.email.isEmpty ? .red : .primary)
            }

            Section("Subject") {
                TextField("Subject", text: $viewModel.subject)
            }

            Section("Message") {
                // Editing raw HTML inline is a deliberate v1 simplification —
                // a WYSIWYG editor is a real follow-up, not core to shipping
                // "preview, then send."
                TextEditor(text: $viewModel.bodyHTML)
                    .frame(minHeight: 220)
                    .font(.system(.body, design: .monospaced))
            }

            Section {
                Button {
                    Task { await viewModel.send() }
                } label: {
                    if case .sending = viewModel.stage {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Send")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSendDisabled)
            }
        }
    }

    private var isSendDisabled: Bool {
        if case .sending = viewModel.stage { return true }
        return viewModel.subject.trimmingCharacters(in: .whitespaces).isEmpty
            || viewModel.card.email.isEmpty
    }
}

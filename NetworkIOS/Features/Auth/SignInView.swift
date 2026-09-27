import SwiftUI
import TODDAuthKit

/// Native sign-in (Apple + Google), replacing the web-redirect HostedLogin
/// flow removed 2026-09-20 after it proved unreliable on a real device
/// (Safari ITP breaking the Google redirect round trip) - see
/// docs/app-store-exclusive-billing-plan.md's "Native sign-in" section.
/// Phone auth is deliberately not included yet - a separate, larger scope
/// with no existing native precedent (needs a reCAPTCHA fallback UI since
/// no APNs silent-push verification is configured).
struct SignInView: View {
    @ObservedObject var authService: AuthService
    @State private var errorMessage = ""
    @State private var isBootstrapping = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image("NetworkLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            Text("Network")
                .font(.largeTitle.bold())
            Text("Sign in with your TODD account to browse your contacts.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 12) {
                SignInWithAppleButtonView(
                    onSignedIn: { Task { await bootstrap() } },
                    onError: { handle($0) }
                )
                SignInWithGoogleButtonView(
                    onSignedIn: { Task { await bootstrap() } },
                    onError: { handle($0) }
                )
            }
            .padding(.horizontal, 32)
            .disabled(isBootstrapping)

            if isBootstrapping {
                ProgressView()
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }

    @MainActor
    private func bootstrap() async {
        errorMessage = ""
        isBootstrapping = true
        defer { isBootstrapping = false }

        do {
            try await authService.bootstrapTenant()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func handle(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}

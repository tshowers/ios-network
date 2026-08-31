import SwiftUI
import TODDAuthKit

struct SignInView: View {
    @ObservedObject var authService: AuthService
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Network")
                .font(.largeTitle.bold())
            Text("Sign in with your TODD account to browse your contacts.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            SignInWithAppleButtonView(
                onSignedIn: { errorMessage = "" },
                onError: { errorMessage = $0.localizedDescription }
            )
            .padding(.horizontal, 32)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            #if DEBUG
            DebugEmailSignInView(onSignedIn: { errorMessage = "" })
            #endif

            Spacer()
            Spacer()
        }
        .padding()
    }
}

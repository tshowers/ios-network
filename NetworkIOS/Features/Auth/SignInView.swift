import SwiftUI
import TODDAuthKit

struct SignInView: View {
    @ObservedObject var authService: AuthService
    @State private var errorMessage = ""

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

            SignInWithAppleButtonView(
                onSignedIn: { errorMessage = "" },
                onError: { errorMessage = $0.localizedDescription }
            )
            .padding(.horizontal, 32)

            SignInWithGoogleButtonView(
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

import SwiftUI
import StoreKit
import TODDEntitlementKit

/// Shown after sign-in + biometric unlock when the signed-in tenant has no
/// active App Store entitlement for Network. Not reachable until Network's
/// billing toggle flips server-side - see the doc comment on
/// EntitlementService.
struct PaywallView: View {
    @ObservedObject var entitlementService: EntitlementService
    let onSignOut: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image("NetworkLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text("Subscribe to Network")
                .font(.title2.bold())
            Text("An active subscription is required to browse your contacts.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if entitlementService.products.isEmpty {
                ProgressView()
                    .padding(.top, 24)
            } else {
                VStack(spacing: 12) {
                    ForEach(entitlementService.products) { product in
                        Button {
                            Task { await entitlementService.purchase(product) }
                        } label: {
                            HStack {
                                Text(product.displayName)
                                Spacer()
                                Text(product.displayPrice)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(entitlementService.isPurchasing)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 16)
            }

            Button("Restore Purchases") {
                Task { await entitlementService.restorePurchases() }
            }
            .font(.footnote)
            .disabled(entitlementService.isPurchasing)
            .padding(.top, 4)

            if let errorMessage = entitlementService.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            SubscriptionLegalFooter()
                .padding(.top, 8)

            Spacer()

            Button("Sign out", role: .destructive, action: onSignOut)
                .font(.footnote)
                .padding(.bottom, 8)
        }
        .padding()
        .task {
            await entitlementService.loadProducts()
        }
    }
}

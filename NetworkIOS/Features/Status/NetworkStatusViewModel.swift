import Foundation

@MainActor
final class NetworkStatusViewModel: ObservableObject {
    @Published var stats: NetworkStats?
    @Published var isLoading = false
    @Published var errorMessage = ""

    private let apiClient: NetworkAPIClient

    init(apiClient: NetworkAPIClient) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        errorMessage = ""
        do {
            stats = try await apiClient.fetchStats()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

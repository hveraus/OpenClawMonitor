import Foundation

// MARK: - Live price entry (shown in All Models view)

struct LiveModelPrice: Identifiable, Codable {
    var id: String { modelName }
    let modelName: String
    let vendorName: String
    let inputPer1M: Double    // ⚡ per 1M input tokens
    let outputPer1M: Double   // ⚡ per 1M output tokens
    let tags: [String]
    let perRequest: Bool      // quota_type != 0  → flat per-request billing
}

// MARK: - Cache file

private struct PriceCacheFile: Codable {
    let fetchedAt: Double     // Unix timestamp
    let models: [LiveModelPrice]
}

// MARK: - API response shapes

private struct YunwuPricingResponse: Decodable {
    let data: [YunwuModel]
    let groupRatio: [String: Double]
    let vendors: [YunwuVendor]
    let success: Bool

    enum CodingKeys: String, CodingKey {
        case data, success, vendors
        case groupRatio = "group_ratio"
    }
}

private struct YunwuModel: Decodable {
    let modelName: String
    let modelRatio: Double
    let completionRatio: Double
    let quotaType: Int
    let vendorId: Int
    let tags: String?

    enum CodingKeys: String, CodingKey {
        case modelName      = "model_name"
        case modelRatio     = "model_ratio"
        case completionRatio = "completion_ratio"
        case quotaType      = "quota_type"
        case vendorId       = "vendor_id"
        case tags
    }
}

private struct YunwuVendor: Decodable {
    let id: Int
    let name: String
}

// MARK: - PriceRefreshService

@MainActor
final class PriceRefreshService: ObservableObject {

    static let shared = PriceRefreshService()
    private init() {}

    // MARK: - Published

    @Published private(set) var prices: [String: LiveModelPrice] = [:]
    @Published private(set) var byVendor: [(vendor: String, models: [LiveModelPrice])] = []
    @Published private(set) var lastUpdated: Date? = nil
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastError: String? = nil

    // MARK: - Cache URL

    private lazy var cacheURL: URL = {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OpenClawMonitor")
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent("price-cache.json")
    }()

    private let apiURL = URL(string: "https://yunwu.ai/api/pricing_new")!
    private let refreshInterval: TimeInterval = 24 * 60 * 60   // 24 h
    private var refreshTask: Task<Void, Never>?

    // MARK: - Public API

    /// Call once on app launch. Loads cache then refreshes if stale.
    func loadCacheAndRefresh() {
        loadCache()
        refreshIfStale()
    }

    /// Force a manual refresh.
    func forceRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { await doRefresh() }
    }

    // MARK: - Cache

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheURL),
              let cache = try? JSONDecoder().decode(PriceCacheFile.self, from: data) else { return }
        apply(models: cache.models, fetchedAt: Date(timeIntervalSince1970: cache.fetchedAt))
    }

    private func saveCache(_ models: [LiveModelPrice], fetchedAt: Date) {
        let cache = PriceCacheFile(fetchedAt: fetchedAt.timeIntervalSince1970, models: models)
        if let data = try? JSONEncoder().encode(cache) {
            try? data.write(to: cacheURL)
        }
    }

    private func refreshIfStale() {
        if let last = lastUpdated, Date().timeIntervalSince(last) < refreshInterval { return }
        refreshTask?.cancel()
        refreshTask = Task { await doRefresh() }
    }

    // MARK: - Fetch & parse

    private func doRefresh() async {
        isRefreshing = true
        lastError = nil
        defer { isRefreshing = false }

        do {
            var req = URLRequest(url: apiURL, timeoutInterval: 20)
            req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: req)
            let response = try JSONDecoder().decode(YunwuPricingResponse.self, from: data)
            guard response.success else {
                lastError = "API returned success=false"
                return
            }

            let vendorMap: [Int: String] = Dictionary(
                uniqueKeysWithValues: response.vendors.map { ($0.id, $0.name) }
            )
            let defaultGroupRatio = response.groupRatio["default"] ?? 1.0

            let models: [LiveModelPrice] = response.data.compactMap { m in
                let vendor = vendorMap[m.vendorId] ?? "Other"
                let perRequest = m.quotaType != 0
                let input  = perRequest ? 0 : m.modelRatio * defaultGroupRatio
                let output = perRequest ? 0 : m.modelRatio * m.completionRatio * defaultGroupRatio
                let tagList = m.tags.map { $0.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } } ?? []
                return LiveModelPrice(
                    modelName: m.modelName,
                    vendorName: vendor,
                    inputPer1M: input,
                    outputPer1M: output,
                    tags: tagList,
                    perRequest: perRequest
                )
            }

            let now = Date()
            saveCache(models, fetchedAt: now)
            apply(models: models, fetchedAt: now)

        } catch {
            lastError = error.localizedDescription
        }
    }

    private func apply(models: [LiveModelPrice], fetchedAt: Date) {
        prices = Dictionary(uniqueKeysWithValues: models.map { ($0.modelName, $0) })

        // Group by vendor, sorted by vendor name then model name
        let grouped = Dictionary(grouping: models, by: \.vendorName)
        byVendor = grouped
            .map { vendor, list in
                (vendor: vendor, models: list.sorted { $0.modelName < $1.modelName })
            }
            .sorted { $0.vendor < $1.vendor }

        lastUpdated = fetchedAt
    }
}

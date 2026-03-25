import Foundation

// MARK: - Model entry

struct LiteLLMEntry: Identifiable, Codable {
    var id: String { modelName }
    let modelName: String
    let provider: String
    let inputPerMillion: Double    // USD / 1M input tokens
    let outputPerMillion: Double   // USD / 1M output tokens
    let maxInputTokens: Int?
    let maxOutputTokens: Int?
    let supportsVision: Bool
    let supportsReasoning: Bool
    let supportsFunctions: Bool
    let mode: String               // "chat" | "completion" | "image_generation" | …
}

// MARK: - Cache

private struct LiteLLMCache: Codable {
    let fetchedAt: Double
    let entries: [LiteLLMEntry]
}

// MARK: - LiteLLMService

@MainActor
final class LiteLLMService: ObservableObject {

    static let shared = LiteLLMService()
    private init() {}

    // MARK: - Published

    @Published private(set) var byProvider: [(provider: String, entries: [LiteLLMEntry])] = []
    @Published private(set) var lastUpdated: Date? = nil
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastError: String? = nil

    // MARK: - Config

    private let sourceURL = URL(string:
        "https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json"
    )!
    private let refreshInterval: TimeInterval = 24 * 60 * 60
    private var refreshTask: Task<Void, Never>?

    private var cacheURL: URL {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OpenClawMonitor")
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support.appendingPathComponent("litellm-cache.json")
    }

    // MARK: - Public API

    func loadCacheAndRefresh() {
        loadCache()
        refreshIfStale()
    }

    func forceRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { await doRefresh() }
    }

    // MARK: - Cache

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheURL),
              let cache = try? JSONDecoder().decode(LiteLLMCache.self, from: data)
        else { return }
        apply(entries: cache.entries, fetchedAt: Date(timeIntervalSince1970: cache.fetchedAt))
    }

    private func saveCache(_ entries: [LiteLLMEntry], fetchedAt: Date) {
        let cache = LiteLLMCache(fetchedAt: fetchedAt.timeIntervalSince1970, entries: entries)
        if let data = try? JSONEncoder().encode(cache) { try? data.write(to: cacheURL) }
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
            let (data, _) = try await URLSession.shared.data(from: sourceURL)
            guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                lastError = "JSON 解析失败"
                return
            }

            var entries: [LiteLLMEntry] = []
            for (key, value) in raw {
                guard key != "sample_spec",
                      let m = value as? [String: Any],
                      let provider = m["litellm_provider"] as? String,
                      // Only keep entries with token-based pricing
                      let inputCostPerToken  = m["input_cost_per_token"]  as? Double,
                      let outputCostPerToken = m["output_cost_per_token"] as? Double
                else { continue }

                // Skip image/audio/video-only modes
                let mode = m["mode"] as? String ?? "chat"
                if ["image_generation", "audio_transcription", "audio_speech",
                    "moderation", "rerank", "embedding"].contains(mode) { continue }

                // Skip obvious duplicates (provider_specific_entry == true)
                if let pse = m["provider_specific_entry"] as? Bool, pse { continue }

                entries.append(LiteLLMEntry(
                    modelName:        key,
                    provider:         provider,
                    inputPerMillion:  inputCostPerToken  * 1_000_000,
                    outputPerMillion: outputCostPerToken * 1_000_000,
                    maxInputTokens:   m["max_input_tokens"]  as? Int,
                    maxOutputTokens:  (m["max_output_tokens"] ?? m["max_tokens"]) as? Int,
                    supportsVision:      (m["supports_vision"]             as? Bool) ?? false,
                    supportsReasoning:   (m["supports_reasoning"]          as? Bool) ?? false,
                    supportsFunctions:   (m["supports_function_calling"]   as? Bool) ?? false,
                    mode: mode
                ))
            }

            let now = Date()
            saveCache(entries, fetchedAt: now)
            apply(entries: entries, fetchedAt: now)

        } catch {
            lastError = error.localizedDescription
        }
    }

    private func apply(entries: [LiteLLMEntry], fetchedAt: Date) {
        // Group by provider, sort providers and models alphabetically
        let grouped = Dictionary(grouping: entries, by: \.provider)
        byProvider = grouped
            .map { p, list in (provider: p, entries: list.sorted { $0.modelName < $1.modelName }) }
            .sorted { $0.provider < $1.provider }
        lastUpdated = fetchedAt
    }
}

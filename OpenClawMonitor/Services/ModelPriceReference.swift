import Foundation

/// Reference prices per 1M tokens.
/// Sources: yunwu.ai/pricing (⚡ credit unit) and LiteLLM (USD).
/// Shown in ModelsView when a model's config cost is zero.
struct ModelPriceReference {

    struct Price {
        let input: Double    // per 1M tokens
        let output: Double   // per 1M tokens
        let unit: String     // "⚡" for yunwu credits, "$" for USD
        let source: String   // display label
    }

    // Convenience initializers
    static func yunwu(_ input: Double, _ output: Double) -> Price {
        Price(input: input, output: output, unit: "⚡", source: "yunwu")
    }
    static func usd(_ input: Double, _ output: Double) -> Price {
        Price(input: input, output: output, unit: "$", source: "官方")
    }

    // MARK: - Reference table

    private static let table: [String: Price] = [

        // ── Anthropic Claude ─────────────────────────────────────────────────
        "claude-sonnet-4-6":                    yunwu(1.80,  9.00),
        "claude-sonnet-4-6-thinking":           yunwu(15.00, 75.00),
        "claude-opus-4-6":                      yunwu(3.00,  15.00),
        "claude-opus-4-6-thinking":             yunwu(3.00,  15.00),
        "claude-sonnet-4-5-20250929":           yunwu(1.80,  9.00),
        "claude-sonnet-4-5-20250929-thinking":  yunwu(1.80,  9.00),
        "claude-opus-4-5-20251101":             yunwu(3.00,  15.00),
        "claude-opus-4-5-20251101-thinking":    yunwu(3.00,  15.00),
        "claude-haiku-4-5-20251001":            yunwu(0.60,  3.00),
        "claude-haiku-4-5-20251001-thinking":   yunwu(0.60,  3.00),
        "claude-opus-4-1-20250805":             yunwu(9.00,  45.00),
        "claude-opus-4-1-20250805-thinking":    yunwu(9.00,  45.00),
        "claude-opus-4-20250514":               yunwu(9.00,  45.00),
        "claude-opus-4-20250514-thinking":      yunwu(9.00,  45.00),
        "claude-sonnet-4-20250514":             yunwu(1.80,  9.00),
        "claude-sonnet-4-20250514-thinking":    yunwu(1.80,  9.00),
        "claude-3-5-sonnet-20241022":           yunwu(1.80,  9.00),
        "claude-3-5-haiku-20241022":            yunwu(0.60,  3.00),
        "claude-3-opus-20240229":               yunwu(9.00,  45.00),

        // ── OpenAI ────────────────────────────────────────────────────────────
        "gpt-5":                    yunwu(0.75,  6.00),
        "gpt-5-2025-08-07":         yunwu(0.75,  6.00),
        "gpt-5-mini-2025-08-07":    yunwu(0.15,  1.20),
        "gpt-5-nano-2025-08-07":    yunwu(0.03,  0.24),
        "gpt-5-pro":                yunwu(9.00,  72.00),
        "gpt-5-codex":              yunwu(0.75,  6.00),
        "gpt-5.4":                  yunwu(1.50,  9.00),
        "gpt-5.4-mini":             yunwu(0.45,  2.70),
        "gpt-5.4-nano":             yunwu(0.12,  0.72),
        "gpt-5.4-pro":              yunwu(18.00, 108.00),
        "gpt-5.1":                  yunwu(0.75,  6.00),
        "gpt-5.2":                  yunwu(1.05,  8.40),
        "gpt-5.3-codex":            yunwu(1.05,  8.40),
        "gpt-4o":                   usd(2.50,   10.00),
        "gpt-4o-mini":              usd(0.15,   0.60),
        "o1":                       usd(15.00,  60.00),
        "o3":                       usd(20.00,  80.00),
        "o3-mini":                  usd(1.21,   4.84),
        "o4-mini":                  usd(1.10,   4.40),

        // ── Google Gemini ─────────────────────────────────────────────────────
        "gemini-2.5-pro":                   yunwu(1.00,  8.00),
        "gemini-2.5-pro-thinking":          yunwu(1.875, 15.00),
        "gemini-2.5-flash":                 usd(0.30,    2.50),
        "gemini-2.5-flash-image":           yunwu(0.00,  0.09),
        "gemini-3-pro-preview":             yunwu(1.60,  9.60),
        "gemini-3-flash-preview":           yunwu(0.40,  2.40),
        "gemini-3.1-pro-preview":           yunwu(1.60,  9.60),
        "gemini-3.1-flash-lite-preview":    yunwu(0.375, 2.25),
        "gemini-2.0-flash":                 usd(0.10,    0.40),
        "gemini-1.5-pro":                   usd(1.25,    5.00),

        // ── DeepSeek ──────────────────────────────────────────────────────────
        "deepseek-v3.2":            yunwu(1.20, 1.80),
        "deepseek-v3.2-thinking":   yunwu(2.00, 3.00),
        "deepseek-chat":            usd(0.27,   1.10),
        "deepseek-reasoner":        usd(0.55,   2.19),

        // ── Moonshot / Kimi ───────────────────────────────────────────────────
        "kimi-k2.5":            yunwu(4.00,  21.00),
        "moonshot-v1-128k":     usd(1.00,   3.00),
        "moonshot-v1-32k":      usd(0.40,   1.20),

        // ── Alibaba Qwen ──────────────────────────────────────────────────────
        "qwen3.5-plus":         yunwu(0.80, 4.80),
        "qwen3.5-397b-a17b":    yunwu(1.20, 7.20),
        "qwen3-max":            yunwu(2.50, 10.00),
        "qwen-plus":            yunwu(0.80, 2.00),

        // ── Zhipu ChatGLM ─────────────────────────────────────────────────────
        "glm-4.7":              yunwu(2.00, 8.00),
        "glm-4.7-thinking":     yunwu(2.00, 8.00),
        "glm-5":                yunwu(4.00, 18.00),

        // ── MiniMax ───────────────────────────────────────────────────────────
        "minimax-m2.5":         yunwu(2.10, 8.40),
        "minimax-m2.7":         yunwu(2.10, 8.40),

        // ── Doubao / ByteDance ────────────────────────────────────────────────
        "doubao-seed-1-8":      yunwu(1.20, 12.00),

        // ── Grok / xAI ───────────────────────────────────────────────────────
        "grok-4.2":             yunwu(3.00, 15.00),

        // ── Mistral ───────────────────────────────────────────────────────────
        "mistral-large":        usd(3.00, 9.00),
        "mistral-medium":       usd(2.70, 8.10),

        // ── Xiaomi MiMo ───────────────────────────────────────────────────────
        "mimo-v2-flash":        yunwu(0.70, 2.10),
    ]

    // MARK: - Alias / fuzzy map
    private static let aliases: [String: String] = [
        // Kimi / Moonshot
        "k2p5":              "kimi-k2.5",
        "k2.5":              "kimi-k2.5",
        "kimi":              "kimi-k2.5",
        "kimi-k2":           "kimi-k2.5",
        "kimi-coding":       "kimi-k2.5",
        // Claude short names
        "claude-sonnet-4":   "claude-sonnet-4-20250514",
        "claude-opus-4":     "claude-opus-4-20250514",
        "claude-haiku-4":    "claude-haiku-4-5-20251001",
        "claude-3.5-sonnet": "claude-3-5-sonnet-20241022",
        "claude-3.5-haiku":  "claude-3-5-haiku-20241022",
        "claude-3-opus":     "claude-3-opus-20240229",
        "claude-sonnet":     "claude-sonnet-4-20250514",
        "claude-opus":       "claude-opus-4-20250514",
        "claude-haiku":      "claude-haiku-4-5-20251001",
        // GPT
        "gpt4o":             "gpt-4o",
        "gpt4o-mini":        "gpt-4o-mini",
        "chatgpt-4o":        "gpt-4o",
        // Gemini
        "gemini-pro":        "gemini-2.5-pro",
        "gemini-flash":      "gemini-2.5-flash",
        // DeepSeek
        "deepseek-v3":       "deepseek-chat",
        "deepseek-r1":       "deepseek-reasoner",
        // Qwen
        "qwen3-plus":        "qwen3.5-plus",
        "qwen-turbo":        "qwen-plus",
    ]

    // MARK: - Provider map  (model-id prefix → display provider name)

    private static let providerMap: [(prefix: String, provider: String)] = [
        ("claude-",         "Anthropic"),
        ("gpt-",            "OpenAI"),
        ("o1",              "OpenAI"),
        ("o3",              "OpenAI"),
        ("o4",              "OpenAI"),
        ("gemini-",         "Google"),
        ("deepseek-",       "DeepSeek"),
        ("kimi-",           "Moonshot / Kimi"),
        ("moonshot-",       "Moonshot / Kimi"),
        ("qwen",            "Alibaba Qwen"),
        ("glm-",            "Zhipu"),
        ("minimax-",        "MiniMax"),
        ("doubao-",         "ByteDance"),
        ("grok-",           "xAI"),
        ("mistral-",        "Mistral"),
        ("mimo-",           "Xiaomi MiMo"),
    ]

    static func provider(for modelId: String) -> String {
        let id = modelId.lowercased()
        for (prefix, name) in providerMap where id.hasPrefix(prefix) { return name }
        return "Other"
    }

    // MARK: - All entries (for the All Models view)

    struct ModelEntry: Identifiable {
        let id: String          // model id
        let provider: String
        let price: Price
    }

    /// All known models sorted by provider then model id.
    static var allEntries: [ModelEntry] {
        table.map { id, price in
            ModelEntry(id: id, provider: provider(for: id), price: price)
        }
        .sorted {
            if $0.provider != $1.provider { return $0.provider < $1.provider }
            return $0.id < $1.id
        }
    }

    /// Entries grouped by provider, order matching providerMap.
    static var entriesByProvider: [(provider: String, models: [ModelEntry])] {
        let dict = Dictionary(grouping: allEntries, by: \.provider)
        // Sort providers in providerMap order, then alphabetically for unknowns
        let ordered = providerMap.map(\.provider) + ["Other"]
        return ordered.compactMap { p in
            guard let models = dict[p], !models.isEmpty else { return nil }
            return (provider: p, models: models.sorted { $0.id < $1.id })
        }
    }

    // MARK: - Lookup
    static func lookup(_ modelId: String) -> Price? {
        let id = modelId.lowercased()
        // 1. Exact match
        if let p = table[id] { return p }
        // 2. Alias map
        if let canonical = aliases[id], let p = table[canonical] { return p }
        // 3. Prefix / contains match
        for (key, price) in table {
            if id.hasPrefix(key) || key.hasPrefix(id) { return price }
        }
        for (key, price) in table {
            if id.contains(key) || key.contains(id) { return price }
        }
        return nil
    }
}

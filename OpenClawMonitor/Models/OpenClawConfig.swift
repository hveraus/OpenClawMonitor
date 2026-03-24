import Foundation

// MARK: - Root

struct OpenClawConfig: Codable {
    let gateway: GatewayConfig
    let agents: AgentsContainer
    let models: ModelsConfig?
    let channels: [String: ChannelConfig]?

    var port: Int { gateway.port }

    /// All agents from the list.
    var agentList: [AgentConfig] { agents.list }

    /// The shared default model ID (from agents.defaults.model.primary).
    var defaultModelId: String? { agents.defaults?.model?.primary }

    /// Flatten all models from every provider into a single list.
    var allModels: [ModelInfo] {
        (models?.providers ?? [:]).flatMap { providerName, provider in
            (provider.models ?? []).map { raw in
                ModelInfo(
                    id: "\(providerName)/\(raw.id)",
                    name: raw.name ?? raw.id,
                    provider: providerName,
                    reasoning: raw.reasoning ?? false,
                    vision: raw.input?.contains("image") ?? false,
                    contextWindow: raw.contextWindow,
                    maxTokens: raw.maxTokens,
                    cost: raw.cost
                )
            }
        }
    }
}

// MARK: - Gateway

struct GatewayConfig: Codable {
    let port: Int
    let mode: String?
    let auth: AuthConfig?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        port = (try? c.decode(Int.self, forKey: .port)) ?? 18789
        mode = try? c.decode(String.self, forKey: .mode)
        auth = try? c.decode(AuthConfig.self, forKey: .auth)
    }

    enum CodingKeys: CodingKey { case port, mode, auth }
}

struct AuthConfig: Codable { let token: String? }

// MARK: - Agents

struct AgentsContainer: Codable {
    let list: [AgentConfig]
    let defaults: AgentDefaults?
}

struct AgentDefaults: Codable {
    let model: AgentModelConfig?
    let models: [String: AgentModelAlias]?
    let maxConcurrent: Int?
}

struct AgentModelConfig: Codable {
    let primary: String?
    let fallbacks: [String]?
}

struct AgentModelAlias: Codable {
    let alias: String?
}

struct AgentConfig: Codable, Identifiable {
    let id: String
    var name: String?
    var emoji: String?
    var model: String?          // may be nil; enriched from defaults in AppViewModel
    var platforms: [String]?
    var description: String?
    let isDefault: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, model, platforms, description
        case isDefault = "default"
    }

    /// Custom decoder: `model` can be a plain String OR `{primary: String, fallbacks: [...]}`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try  c.decode(String.self,   forKey: .id)
        name        = try? c.decode(String.self,   forKey: .name)
        emoji       = try? c.decode(String.self,   forKey: .emoji)
        platforms   = try? c.decode([String].self, forKey: .platforms)
        description = try? c.decode(String.self,   forKey: .description)
        isDefault   = try? c.decode(Bool.self,     forKey: .isDefault)
        // model can be a plain String or a {primary, fallbacks} object
        if let s = try? c.decode(String.self, forKey: .model) {
            model = s
        } else if let obj = try? c.decode(AgentModelConfig.self, forKey: .model) {
            model = obj.primary
        } else {
            model = nil
        }
    }

    var displayName:  String { name  ?? id }
    var displayEmoji: String { emoji ?? "🤖" }

    /// Convenience init for mock data (no isDefault required).
    init(id: String, name: String? = nil, emoji: String? = nil, model: String? = nil,
         platforms: [String]? = nil, description: String? = nil) {
        self.id = id; self.name = name; self.emoji = emoji; self.model = model
        self.platforms = platforms; self.description = description; self.isDefault = nil
    }
}

// MARK: - Models

struct ModelsConfig: Codable {
    let mode: String?
    /// Keyed by provider slug, e.g. "kimi-coding", "anthropic".
    let providers: [String: ProviderConfig]
}

struct ProviderConfig: Codable {
    let baseUrl: String?
    let models: [RawModelConfig]?
}

struct RawModelConfig: Codable {
    let id: String
    let name: String?
    let reasoning: Bool?
    let input: [String]?
    let contextWindow: Int?
    let maxTokens: Int?
    let cost: CostInfo?
}

struct CostInfo: Codable {
    let input: Double?
    let output: Double?
    let cacheRead: Double?
    let cacheWrite: Double?

    /// Convenience init for mock data.
    init(input: Double?, output: Double?) {
        self.input = input; self.output = output; self.cacheRead = nil; self.cacheWrite = nil
    }
}

// MARK: - Channels

struct ChannelConfig: Codable {
    let type: String?
    let token: String?
}

// MARK: - ModelInfo (display-ready, derived from raw config)

struct ModelInfo: Identifiable {
    let id: String
    let name: String
    let provider: String
    let reasoning: Bool
    let vision: Bool
    let contextWindow: Int?
    let maxTokens: Int?
    let cost: CostInfo?

    var providerDisplayName: String {
        ["anthropic": "Anthropic",
         "openai": "OpenAI",
         "deepseek": "DeepSeek",
         "google": "Google",
         "mistral": "Mistral",
         "groq": "Groq"][provider.lowercased()] ?? provider.capitalized
    }

    var contextWindowFormatted: String {
        contextWindow.map { $0 >= 1000 ? "\($0 / 1000)k" : "\($0)" } ?? "—"
    }

    var maxTokensFormatted: String {
        maxTokens.map { $0 >= 1000 ? "\($0 / 1000)k" : "\($0)" } ?? "—"
    }

    /// True when config has all-zero costs (self-hosted / no billing).
    var hasZeroCost: Bool {
        guard let cost else { return true }
        return (cost.input ?? 0) == 0 && (cost.output ?? 0) == 0
    }

    /// Format per-1M-token price for display.
    private func fmtCost(_ perToken: Double?) -> String {
        guard let v = perToken else { return "?" }
        let perM = v * 1_000_000
        if perM == 0 { return "$0" }
        if perM < 0.10 { return String(format: "$%.4f", perM) }
        if perM < 1.00 { return String(format: "$%.3f", perM) }
        return String(format: "$%.2f", perM)
    }

    /// Configured cost string (per 1M tokens). Falls through to reference price.
    var costFormatted: String {
        if !hasZeroCost, let cost {
            return "\(fmtCost(cost.input)) / \(fmtCost(cost.output))"
        }
        if let ref = ModelPriceReference.lookup(id) {
            let i = String(format: "%.2f", ref.input)
            let o = String(format: "%.2f", ref.output)
            return "\(ref.unit)\(i) / \(ref.unit)\(o) ※"
        }
        return "—"
    }

    /// Source label for cost column tooltip / legend.
    var costSource: String {
        if !hasZeroCost { return "来自配置" }
        if let ref = ModelPriceReference.lookup(id) { return "参考价 (\(ref.source))" }
        return ""
    }
}

// MARK: - AgentRuntime (gateway-reported live state)

struct AgentRuntime: Identifiable {
    let id: String   // matches AgentConfig.id
    var status: AgentStatus
    var sessionCount: Int
    var totalTokens: Int
    var avgResponseMs: Int
    var provider: String = ""  // populated from gateway session data

    enum AgentStatus: String {
        case online, idle, offline

        var label: String {
            switch self {
            case .online:  return "在线"
            case .idle:    return "空闲"
            case .offline: return "离线"
            }
        }
    }
}

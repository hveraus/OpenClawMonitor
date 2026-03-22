import Foundation

// MARK: - Root

struct OpenClawConfig: Codable {
    let gateway: GatewayConfig
    let models: ModelsConfig?
    let agents: [AgentConfig]
    let channels: [String: ChannelConfig]?

    var port: Int { gateway.port }

    /// Flatten all models from every provider into a single list.
    var allModels: [ModelInfo] {
        (models?.providers ?? []).flatMap { provider in
            (provider.models ?? []).map { raw in
                ModelInfo(
                    id: raw.id,
                    name: raw.name ?? raw.id,
                    provider: provider.name,
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
    let bind: String?
    let auth: AuthConfig?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        port  = (try? c.decode(Int.self, forKey: .port)) ?? 18789
        mode  = try? c.decode(String.self, forKey: .mode)
        bind  = try? c.decode(String.self, forKey: .bind)
        auth  = try? c.decode(AuthConfig.self, forKey: .auth)
    }

    enum CodingKeys: CodingKey { case port, mode, bind, auth }
}

struct AuthConfig: Codable { let token: String? }

// MARK: - Agents

struct AgentConfig: Codable, Identifiable {
    let id: String
    let name: String
    let emoji: String?
    let model: String?
    let platforms: [String]?
    let description: String?

    var displayEmoji: String { emoji ?? "🤖" }
}

// MARK: - Models

struct ModelsConfig: Codable {
    let providers: [ProviderConfig]
}

struct ProviderConfig: Codable {
    let name: String
    let baseUrl: String?
    let apiKey: String?
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
    let input: Double?    // $ per million tokens
    let output: Double?
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

    var costFormatted: String {
        guard let cost else { return "—" }
        let i = cost.input.map  { String(format: "$%.1f", $0) } ?? "?"
        let o = cost.output.map { String(format: "$%.1f", $0) } ?? "?"
        return "\(i) / \(o)"
    }
}

// MARK: - AgentRuntime (gateway-reported live state)

struct AgentRuntime: Identifiable {
    let id: String   // matches AgentConfig.id
    var status: AgentStatus
    var sessionCount: Int
    var totalTokens: Int
    var avgResponseMs: Int

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

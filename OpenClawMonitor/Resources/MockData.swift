import Foundation

// MARK: - Mock Data Provider
// All demo data used when ~/.openclaw/openclaw.json is absent.

enum MockData {

    // MARK: - Agents

    static let agents: [AgentConfig] = [
        AgentConfig(id: "aria",    name: "Aria",    emoji: "🌸", model: "claude-sonnet-4-5",    platforms: ["feishu", "discord"],    description: "通用助手，擅长写作和分析"),
        AgentConfig(id: "bolt",    name: "Bolt",    emoji: "⚡", model: "gpt-4o",               platforms: ["discord", "slack"],     description: "代码专家，快速响应"),
        AgentConfig(id: "sage",    name: "Sage",    emoji: "🌿", model: "deepseek-chat",        platforms: ["feishu"],               description: "知识库问答专家"),
        AgentConfig(id: "nova",    name: "Nova",    emoji: "✨", model: "gemini-2.0-flash",     platforms: ["telegram"],             description: "多模态助手，支持图像理解"),
        AgentConfig(id: "echo",    name: "Echo",    emoji: "🔊", model: "claude-opus-4-5",      platforms: ["feishu", "discord"],    description: "深度推理专家"),
        AgentConfig(id: "pixel",   name: "Pixel",   emoji: "🎮", model: "gpt-4o-mini",         platforms: ["discord"],              description: "轻量级 Bot，高频互动"),
    ]

    static let agentRuntimes: [AgentRuntime] = [
        AgentRuntime(id: "aria",  status: .online,  sessionCount: 12, totalTokens: 1_058_420, avgResponseMs: 1240),
        AgentRuntime(id: "bolt",  status: .online,  sessionCount:  8, totalTokens:   412_880, avgResponseMs:  890),
        AgentRuntime(id: "sage",  status: .idle,    sessionCount:  5, totalTokens:   237_100, avgResponseMs: 2100),
        AgentRuntime(id: "nova",  status: .online,  sessionCount: 15, totalTokens:   780_350, avgResponseMs: 1560),
        AgentRuntime(id: "echo",  status: .offline, sessionCount:  3, totalTokens:   192_000, avgResponseMs: 4200),
        AgentRuntime(id: "pixel", status: .idle,    sessionCount: 20, totalTokens:   103_760, avgResponseMs:  430),
    ]

    // MARK: - Models

    static let models: [ModelInfo] = [
        ModelInfo(id: "claude-opus-4-5",     name: "Claude Opus 4.5",      provider: "anthropic",
                  reasoning: true,  vision: true,  contextWindow: 200_000, maxTokens: 32_000,
                  cost: CostInfo(input: 15.0, output: 75.0)),
        ModelInfo(id: "claude-sonnet-4-5",   name: "Claude Sonnet 4.5",    provider: "anthropic",
                  reasoning: false, vision: true,  contextWindow: 200_000, maxTokens: 8_192,
                  cost: CostInfo(input: 3.0, output: 15.0)),
        ModelInfo(id: "gpt-4o",              name: "GPT-4o",                provider: "openai",
                  reasoning: false, vision: true,  contextWindow: 128_000, maxTokens: 16_384,
                  cost: CostInfo(input: 5.0, output: 15.0)),
        ModelInfo(id: "gpt-4o-mini",         name: "GPT-4o mini",           provider: "openai",
                  reasoning: false, vision: true,  contextWindow: 128_000, maxTokens: 16_384,
                  cost: CostInfo(input: 0.15, output: 0.6)),
        ModelInfo(id: "deepseek-chat",       name: "DeepSeek Chat",         provider: "deepseek",
                  reasoning: false, vision: false, contextWindow: 64_000,  maxTokens: 8_192,
                  cost: CostInfo(input: 0.27, output: 1.1)),
        ModelInfo(id: "gemini-2.0-flash",    name: "Gemini 2.0 Flash",      provider: "google",
                  reasoning: false, vision: true,  contextWindow: 1_048_576, maxTokens: 8_192,
                  cost: CostInfo(input: 0.1, output: 0.4)),
    ]

    // MARK: - Sessions

    static let sessions: [SessionInfo] = {
        let cal = Calendar.current
        func daysAgo(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: .now)! }
        return [
            SessionInfo(id: "s01", agentId: "aria",  type: .dm,    platform: "feishu",
                        userName: "张三", channelName: nil,
                        tokens: 42_800, messages: 138, lastActive: daysAgo(0),  status: .active),
            SessionInfo(id: "s02", agentId: "aria",  type: .group, platform: "discord",
                        userName: nil, channelName: "#design-review",
                        tokens: 98_200, messages: 312, lastActive: daysAgo(1),  status: .idle),
            SessionInfo(id: "s03", agentId: "bolt",  type: .dm,    platform: "discord",
                        userName: "Alice", channelName: nil,
                        tokens: 28_400, messages:  91, lastActive: daysAgo(0),  status: .active),
            SessionInfo(id: "s04", agentId: "bolt",  type: .dm,    platform: "slack",
                        userName: "Bob", channelName: nil,
                        tokens: 15_700, messages:  54, lastActive: daysAgo(2),  status: .idle),
            SessionInfo(id: "s05", agentId: "sage",  type: .group, platform: "feishu",
                        userName: nil, channelName: "#tech-qa",
                        tokens: 57_100, messages: 204, lastActive: daysAgo(3),  status: .idle),
            SessionInfo(id: "s06", agentId: "nova",  type: .dm,    platform: "telegram",
                        userName: "Carlos", channelName: nil,
                        tokens: 33_900, messages:  88, lastActive: daysAgo(0),  status: .active),
            SessionInfo(id: "s07", agentId: "nova",  type: .group, platform: "telegram",
                        userName: nil, channelName: "@nova_support",
                        tokens: 121_000, messages: 440, lastActive: daysAgo(1),  status: .active),
            SessionInfo(id: "s08", agentId: "echo",  type: .dm,    platform: "feishu",
                        userName: "李四", channelName: nil,
                        tokens: 88_500, messages: 210, lastActive: daysAgo(14), status: .inactive),
            SessionInfo(id: "s09", agentId: "pixel", type: .cron,  platform: "discord",
                        userName: nil, channelName: "#daily-report",
                        tokens:  8_200, messages:  28, lastActive: daysAgo(0),  status: .active),
            SessionInfo(id: "s10", agentId: "pixel", type: .group, platform: "discord",
                        userName: nil, channelName: "#general",
                        tokens: 22_400, messages: 184, lastActive: daysAgo(2),  status: .idle),
        ]
    }()

    // MARK: - Stats (14 days)

    static let statPoints: [StatPoint] = {
        let cal = Calendar.current
        let seed: [(tokens: Int, messages: Int, ms: Int)] = [
            (24_200,  82, 1100),
            (31_800, 104, 1240),
            (19_500,  67,  980),
            (42_100, 138, 1380),
            (38_700, 121, 1260),
            (56_400, 187, 1490),
            ( 8_200,  31,  870),
            (12_600,  44,  920),
            (47_300, 158, 1320),
            (61_800, 199, 1560),
            (35_100, 112, 1180),
            (28_900,  96, 1040),
            (72_400, 234, 1680),
            (58_200, 191, 1520),
        ]
        return seed.enumerated().map { idx, s in
            let date = cal.date(byAdding: .day, value: -(13 - idx), to: .now)!
            return StatPoint(date: date, tokens: s.tokens, messages: s.messages, avgResponseMs: s.ms)
        }
    }()

    // MARK: - Alerts

    static let alerts: [AlertItem] = {
        let cal = Calendar.current
        func ago(_ h: Int) -> Date { cal.date(byAdding: .hour, value: -h, to: .now)! }
        return [
            AlertItem(type: .error,   message: "Echo (🔊) 已离线超过 14 天，请检查 OpenClaw 配置",
                      timestamp: ago(2),  status: .active),
            AlertItem(type: .warning, message: "Aria (🌸) 模型响应时间超过阈值：avg 1240ms > 1000ms",
                      timestamp: ago(6),  status: .active),
            AlertItem(type: .info,    message: "Nova (✨) Token 消耗较昨日增加 87%",
                      timestamp: ago(18), status: .active),
            AlertItem(type: .error,   message: "Gateway 在 3 小时前短暂中断，已自动恢复",
                      timestamp: ago(72), status: .resolved),
        ]
    }()

    // MARK: - Skills

    static let skills: [SkillInfo] = [
        SkillInfo(id: "web-search",    name: "Web Search",       description: "使用搜索引擎检索实时信息",                         type: .builtin,  isEnabled: true,  version: "1.2.0", author: "OpenClaw"),
        SkillInfo(id: "code-exec",     name: "Code Executor",    description: "在沙盒环境中执行 Python / JS 代码",               type: .builtin,  isEnabled: true,  version: "1.0.3", author: "OpenClaw"),
        SkillInfo(id: "file-reader",   name: "File Reader",      description: "读取本地文件内容并解析",                           type: .builtin,  isEnabled: true,  version: "0.9.1", author: "OpenClaw"),
        SkillInfo(id: "image-gen",     name: "Image Generator",  description: "调用 DALL-E / Stability AI 生成图像",            type: .extended, isEnabled: true,  version: "2.1.0", author: "Community"),
        SkillInfo(id: "calendar",      name: "Calendar Sync",    description: "读写 Google Calendar 事件",                      type: .extended, isEnabled: false, version: "1.0.0", author: "Community"),
        SkillInfo(id: "jira",          name: "Jira Connector",   description: "查询和创建 Jira 工单",                            type: .extended, isEnabled: true,  version: "1.3.2", author: "Community"),
        SkillInfo(id: "notion",        name: "Notion Writer",    description: "向 Notion 页面写入内容",                          type: .extended, isEnabled: true,  version: "0.8.0", author: "Community"),
        SkillInfo(id: "summarizer",    name: "Doc Summarizer",   description: "自动摘要长文档，支持 PDF / DOCX",                  type: .custom,   isEnabled: true,  version: "1.0.0", author: "Local"),
        SkillInfo(id: "daily-report",  name: "Daily Reporter",   description: "每日定时生成团队周报并推送至飞书群",                type: .custom,   isEnabled: true,  version: "2.0.1", author: "Local"),
        SkillInfo(id: "sentry-alert",  name: "Sentry Watcher",   description: "监听 Sentry 错误并在 Discord 发送告警",           type: .custom,   isEnabled: false, version: "0.5.0", author: "Local"),
    ]

    // MARK: - Synthetic OpenClawConfig (for ConfigService fallback)

    static var config: OpenClawConfig {
        // Build a synthetic config from the mock data above so the rest of the
        // app can treat mock mode and real mode identically.
        let providers = Dictionary(grouping: models, by: \.provider).map { name, infos in
            ProviderConfig(
                name: name,
                baseUrl: nil,
                apiKey: nil,
                models: infos.map { m in
                    RawModelConfig(
                        id: m.id, name: m.name,
                        reasoning: m.reasoning,
                        input: m.vision ? ["text", "image"] : ["text"],
                        contextWindow: m.contextWindow,
                        maxTokens: m.maxTokens,
                        cost: m.cost
                    )
                }
            )
        }
        return OpenClawConfig(
            gateway: GatewayConfig(port: 18789, mode: "local", bind: "loopback", auth: nil),
            models: ModelsConfig(providers: providers),
            agents: agents,
            channels: nil
        )
    }
}

// MARK: - GatewayConfig memberwise init (needed by MockData)
extension GatewayConfig {
    init(port: Int, mode: String?, bind: String?, auth: AuthConfig?) {
        self.port = port
        self.mode = mode
        self.bind = bind
        self.auth = auth
    }
}

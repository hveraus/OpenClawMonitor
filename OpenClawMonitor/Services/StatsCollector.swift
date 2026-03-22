import Foundation

/// Scans OpenClaw JSONL log files, aggregates daily statistics, and caches results.
/// Log location: /tmp/openclaw/openclaw-YYYY-MM-DD.log
/// Cache location: ~/Library/Application Support/OpenClawMonitor/daily-stats.json
@MainActor
final class StatsCollector: ObservableObject {

    static let shared = StatsCollector()
    private init() {}

    // MARK: - Published

    @Published private(set) var statPoints: [StatPoint] = []
    @Published private(set) var isLoading = false

    // MARK: - Private

    private let logDir = URL(fileURLWithPath: "/tmp/openclaw")
    private var refreshTimer: Timer?

    // MARK: - Internal cache model

    fileprivate struct DayStats: Codable {
        var totalTokens: Int   = 0
        var inputTokens: Int   = 0
        var outputTokens: Int  = 0
        var messages: Int      = 0
        var totalResponseMs: Int = 0
        var responseCount: Int = 0
        var byModel: [String: Int] = [:]
    }

    // Mirrors the JSONL log line structure
    private struct LogEntry: Decodable {
        let timestamp: String?
        let model: String?
        let usage: Usage?
        let durationMs: Int?

        struct Usage: Decodable {
            let input: Int?
            let output: Int?
            let cacheRead: Int?
            let cacheWrite: Int?
            let total: Int?
        }
    }

    // MARK: - Public API

    /// Perform a full scan on startup (skips already-cached dates, always re-scans today).
    func start() {
        Task { await scanAndPublish(todayOnly: false) }
        startRefreshTimer()
    }

    /// Re-scan only today's log file (called every 5 minutes by the timer).
    func refreshToday() {
        Task { await scanAndPublish(todayOnly: true) }
    }

    // MARK: - Core pipeline

    private func scanAndPublish(todayOnly: Bool) async {
        isLoading = true
        let logDir   = self.logDir
        let cacheURL = Self.cacheFileURL()

        let points = await Task.detached(priority: .utility) { () -> [StatPoint] in
            var cache = Self.loadCache(from: cacheURL)
            Self.scanLogs(in: logDir, cache: &cache, todayOnly: todayOnly)
            Self.saveCache(cache, to: cacheURL)
            return Self.makeStatPoints(from: cache)
        }.value

        statPoints = points
        isLoading  = false
    }

    // MARK: - File scanning (static, no actor isolation)

    nonisolated private static func scanLogs(in dir: URL, cache: inout [String: DayStats], todayOnly: Bool) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }

        let today    = currentDateKey()
        let logFiles = files.filter {
            $0.lastPathComponent.hasPrefix("openclaw-") && $0.pathExtension == "log"
        }

        for file in logFiles {
            guard let fileDate = dateKeyFromFilename(file.lastPathComponent) else { continue }
            // In today-only mode: skip all but today
            if todayOnly && fileDate != today { continue }
            // In full mode: skip dates already cached (except today which keeps updating)
            if !todayOnly && fileDate != today && cache[fileDate] != nil { continue }

            if let stats = parseLog(at: file) {
                cache[fileDate] = stats
            }
        }
    }

    nonisolated private static func parseLog(at url: URL) -> DayStats? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }

        var stats   = DayStats()
        let decoder = JSONDecoder()

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty,
                  let data  = trimmed.data(using: .utf8),
                  let entry = try? decoder.decode(LogEntry.self, from: data) else { continue }

            let inputT  = entry.usage?.input      ?? 0
            let outputT = entry.usage?.output     ?? 0
            let cacheR  = entry.usage?.cacheRead  ?? 0
            let cacheW  = entry.usage?.cacheWrite ?? 0
            let total   = entry.usage?.total ?? (inputT + outputT + cacheR + cacheW)

            stats.totalTokens  += total
            stats.inputTokens  += inputT
            stats.outputTokens += outputT
            stats.messages     += 1

            if let ms = entry.durationMs, ms > 0 {
                stats.totalResponseMs += ms
                stats.responseCount   += 1
            }
            if let model = entry.model, !model.isEmpty {
                stats.byModel[model, default: 0] += total
            }
        }

        return stats.messages > 0 ? stats : nil
    }

    // MARK: - Cache I/O

    nonisolated private static func loadCache(from url: URL) -> [String: DayStats] {
        guard let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: DayStats].self, from: data)
        else { return [:] }
        return dict
    }

    nonisolated private static func saveCache(_ cache: [String: DayStats], to url: URL) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Data conversion

    nonisolated private static func makeStatPoints(from cache: [String: DayStats]) -> [StatPoint] {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone   = .current

        return cache.compactMap { key, stats -> StatPoint? in
            guard let date = df.date(from: key) else { return nil }
            let avg = stats.responseCount > 0 ? stats.totalResponseMs / stats.responseCount : 0
            return StatPoint(
                date: date,
                tokens: stats.totalTokens,
                inputTokens: stats.inputTokens,
                outputTokens: stats.outputTokens,
                messages: stats.messages,
                avgResponseMs: avg,
                byModel: stats.byModel
            )
        }
        .sorted { $0.date < $1.date }
    }

    // MARK: - Helpers

    nonisolated private static func cacheFileURL() -> URL {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("OpenClawMonitor")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("daily-stats.json")
    }

    nonisolated private static func currentDateKey() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone   = .current
        return df.string(from: Date())
    }

    nonisolated private static func dateKeyFromFilename(_ name: String) -> String? {
        // "openclaw-2026-03-22.log" → "2026-03-22"
        let prefix = "openclaw-"
        let suffix = ".log"
        guard name.hasPrefix(prefix), name.hasSuffix(suffix) else { return nil }
        let key = String(name.dropFirst(prefix.count).dropLast(suffix.count))
        guard key.split(separator: "-").count == 3 else { return nil }
        return key
    }

    // MARK: - 5-minute refresh timer

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshToday() }
        }
    }
}

import Foundation

@MainActor
final class CronService: ObservableObject {

    static let shared = CronService()
    private init() {}

    // MARK: - Published

    @Published private(set) var jobs: [CronJob] = []

    // MARK: - Private

    private var fileWatcher: FileWatcher?
    private var jobsURL: URL?

    // MARK: - Load

    func loadJobs() {
        let url = resolveJobsURL()
        jobsURL = url
        readJobs(from: url)
        startWatching(url: url)
    }

    func reload() {
        guard let url = jobsURL else { return }
        readJobs(from: url)
    }

    // MARK: - File location

    private func resolveJobsURL() -> URL {
        let fm = FileManager.default
        // Honour OPENCLAW_HOME env var first
        if let envHome = ProcessInfo.processInfo.environment["OPENCLAW_HOME"] {
            let url = URL(fileURLWithPath: envHome)
                .appendingPathComponent("cron")
                .appendingPathComponent("jobs.json")
            if fm.fileExists(atPath: url.path) { return url }
        }
        // Default ~/.openclaw/cron/jobs.json
        return fm.homeDirectoryForCurrentUser
            .appendingPathComponent(".openclaw")
            .appendingPathComponent("cron")
            .appendingPathComponent("jobs.json")
    }

    // MARK: - JSON reading

    private func readJobs(from url: URL) {
        guard let data = try? Data(contentsOf: url) else {
            jobs = []
            return
        }
        let decoder = JSONDecoder()
        if let list = try? decoder.decode([CronJob].self, from: data) {
            jobs = list
        } else if let dict = try? decoder.decode([String: CronJob].self, from: data) {
            jobs = Array(dict.values).sorted { $0.name < $1.name }
        } else {
            jobs = []
        }
    }

    // MARK: - Run history

    func loadRuns(for jobId: String) -> [CronRun] {
        let runsURL = resolveRunsURL(for: jobId)
        guard let data = try? Data(contentsOf: runsURL),
              let text = String(data: data, encoding: .utf8) else { return [] }
        let lines = text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let decoder = JSONDecoder()
        return lines.compactMap { line in
            guard let lineData = line.data(using: .utf8) else { return nil }
            return try? decoder.decode(CronRun.self, from: lineData)
        }.sorted { ($0.startedAt ?? 0) > ($1.startedAt ?? 0) }   // newest first
    }

    private func resolveRunsURL(for jobId: String) -> URL {
        let fm = FileManager.default
        let base: URL
        if let envHome = ProcessInfo.processInfo.environment["OPENCLAW_HOME"] {
            base = URL(fileURLWithPath: envHome)
        } else {
            base = fm.homeDirectoryForCurrentUser.appendingPathComponent(".openclaw")
        }
        return base
            .appendingPathComponent("cron")
            .appendingPathComponent("runs")
            .appendingPathComponent("\(jobId).jsonl")
    }

    // MARK: - CLI operations

    /// Enable a disabled cron job via `openclaw cron enable <jobId>`
    func enableJob(_ jobId: String) async -> Bool {
        await runCLI("cron", "enable", jobId)
    }

    /// Disable a cron job via `openclaw cron disable <jobId>`
    func disableJob(_ jobId: String) async -> Bool {
        await runCLI("cron", "disable", jobId)
    }

    /// Trigger an immediate run via `openclaw cron run <jobId>`
    func runJobNow(_ jobId: String) async -> Bool {
        await runCLI("cron", "run", jobId)
    }

    private func runCLI(_ args: String...) async -> Bool {
        let openclaw = resolveOpenclawBinary()
        guard let binary = openclaw else { return false }
        let result = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: binary)
            proc.arguments = args
            proc.terminationHandler = { p in
                cont.resume(returning: p.terminationStatus == 0)
            }
            do {
                try proc.run()
            } catch {
                cont.resume(returning: false)
            }
        }
        // Refresh after CLI action
        if result { reload() }
        return result
    }

    private func resolveOpenclawBinary() -> String? {
        let candidates = [
            "/usr/local/bin/openclaw",
            "/opt/homebrew/bin/openclaw",
            "\(ProcessInfo.processInfo.environment["HOME"] ?? "")/.nvm/versions/node/\(ProcessInfo.processInfo.environment["NODE_VERSION"] ?? "")/bin/openclaw",
        ]
        let fm = FileManager.default
        for path in candidates where fm.fileExists(atPath: path) { return path }
        // Try `which openclaw` as fallback
        if let path = shellWhich("openclaw") { return path }
        return nil
    }

    private func shellWhich(_ cmd: String) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        proc.arguments = [cmd]
        let pipe = Pipe()
        proc.standardOutput = pipe
        try? proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return path?.isEmpty == false ? path : nil
    }

    // MARK: - FileWatcher

    private func startWatching(url: URL) {
        fileWatcher = FileWatcher { [weak self] in
            Task { @MainActor [weak self] in self?.reload() }
        }
        fileWatcher?.start(watching: url.path)
    }
}

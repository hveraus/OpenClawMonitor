import Foundation

/// Loads and parses the OpenClaw configuration file.
/// Resolution order:
///   1. $OPENCLAW_HOME/openclaw.json
///   2. ~/.openclaw/openclaw.json
///   3. Returns nil → caller falls back to MockData
@MainActor
final class ConfigService {

    static let shared = ConfigService()
    private init() {}

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Public

    /// Returns the parsed config, or nil if no file was found / parse failed.
    func load() -> OpenClawConfig? {
        guard let url = configFileURL() else { return nil }
        return parse(url: url)
    }

    /// The resolved config file path (for display in Settings → About).
    func resolvedPath() -> String? {
        configFileURL()?.path
    }

    // MARK: - Private

    private func configFileURL() -> URL? {
        // 1. Environment variable
        if let home = ProcessInfo.processInfo.environment["OPENCLAW_HOME"] {
            let url = URL(fileURLWithPath: home).appendingPathComponent("openclaw.json")
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        // 2. Default location
        let defaultURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".openclaw/openclaw.json")
        if FileManager.default.fileExists(atPath: defaultURL.path) { return defaultURL }
        return nil
    }

    private func parse(url: URL) -> OpenClawConfig? {
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(OpenClawConfig.self, from: data)
        } catch {
            print("[ConfigService] Parse failed: \(error)")
            return nil
        }
    }
}

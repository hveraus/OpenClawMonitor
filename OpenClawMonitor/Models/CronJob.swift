import Foundation

// MARK: - Top-level file wrapper  { "version": 1, "jobs": [...] }

struct CronJobsFile: Decodable {
    let version: Int?
    let jobs: [CronJob]
}

// MARK: - CronJob

struct CronJob: Identifiable, Decodable {
    let id: String
    let name: String
    let description: String?
    let schedule: CronSchedule
    var enabled: Bool
    let sessionTarget: String?
    let agentId: String?
    let delivery: CronDelivery?
    let state: CronJobState?
    let createdAtMs: Double?
    let updatedAtMs: Double?

    // MARK: - Computed

    var scheduleTypeBadge: String {
        switch schedule.kind {
        case "cron":  return "定时"
        case "every": return "间隔"
        case "at":    return "一次性"
        default:      return schedule.kind
        }
    }

    var humanReadableSchedule: String {
        CronExpressionTranslator.translate(schedule)
    }

    var nextRunDate: Date? {
        guard let ms = state?.nextRunAtMs, ms > 0 else { return nil }
        return Date(timeIntervalSince1970: ms / 1000)
    }

    var sessionTargetDisplay: String {
        switch sessionTarget {
        case "isolated": return "独立会话"
        case nil, "main": return "主会话"
        default: return sessionTarget ?? "主会话"
        }
    }
}

// MARK: - Sub-types

struct CronSchedule: Decodable {
    let kind: String        // "cron" | "every" | "at"
    let expr: String?       // "0 9 * * 1-5"  (cron) or ISO date (at)
    let every: Int?         // milliseconds  (every)
    let tz: String?
}

struct CronJobState: Decodable {
    let nextRunAtMs: Double?
}

struct CronDelivery: Decodable {
    let mode: String?       // "announce" | "reply" | etc.
    let channel: String?
    let to: String?

    var display: String {
        let ch = channel ?? ""
        let target = to ?? ""
        if ch.isEmpty && target.isEmpty { return "—" }
        if ch.isEmpty { return target }
        return "\(ch.capitalized): \(target)"
    }
}

// MARK: - CronRun  (from ~/.openclaw/cron/runs/<jobId>.jsonl)

struct CronRun: Identifiable, Decodable {
    // Use ts as stable id since there's no explicit id field
    var id: String { "\(ts ?? 0)" }

    let ts: Double?          // finished timestamp ms
    let jobId: String?
    let action: String?      // "finished"
    let status: String?      // "ok" | "error"
    let summary: String?
    let error: String?
    let runAtMs: Double?
    let durationMs: Int?
    let model: String?
    let provider: String?
    let usage: CronRunUsage?
    let delivered: Bool?

    var finishedDate: Date? {
        guard let ts, ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts / 1000)
    }

    var succeeded: Bool { status == "ok" }
}

struct CronRunUsage: Decodable {
    let input_tokens: Int?
    let output_tokens: Int?
    let total_tokens: Int?
}

// MARK: - Cron expression translator

enum CronExpressionTranslator {
    static func translate(_ schedule: CronSchedule) -> String {
        switch schedule.kind {
        case "cron":
            return translateCron(schedule.expr ?? "")
        case "every":
            if let ms = schedule.every { return translateInterval(ms) }
            if let expr = schedule.expr { return translateEveryString(expr) }
            return "间隔运行"
        case "at":
            if let expr = schedule.expr {
                let df = ISO8601DateFormatter()
                if let date = df.date(from: expr) {
                    let out = DateFormatter()
                    out.dateStyle = .short
                    out.timeStyle = .short
                    out.locale = Locale(identifier: "zh_CN")
                    return out.string(from: date)
                }
                return expr
            }
            return "一次性"
        default:
            return schedule.expr ?? schedule.kind
        }
    }

    private static func translateCron(_ expr: String) -> String {
        let parts = expr.trimmingCharacters(in: .whitespaces)
                        .split(separator: " ", maxSplits: 4)
                        .map(String.init)
        guard parts.count == 5 else { return expr }
        let (min, hour, dom, month, dow) = (parts[0], parts[1], parts[2], parts[3], parts[4])

        if expr == "* * * * *" { return "每分钟" }

        if min == "0" && hour == "*" && dom == "*" && month == "*" && dow == "*" {
            return "每小时整点"
        }
        if hour == "*" && dom == "*" && month == "*" && dow == "*",
           let n = parseStep(min) { return "每 \(n) 分钟" }

        if min == "0" && dom == "*" && month == "*" && dow == "*",
           let n = parseStep(hour) { return "每 \(n) 小时" }

        if dom == "*" && month == "*" && dow == "*",
           let h = Int(hour), let m = Int(min) {
            return "每天 \(String(format: "%02d:%02d", h, m))"
        }
        if dom == "*" && month == "*" && (dow == "1-5" || dow == "MON-FRI"),
           let h = Int(hour), let m = Int(min) {
            return "工作日 每天 \(String(format: "%02d:%02d", h, m))"
        }
        if dom == "*" && month == "*" && (dow == "0,6" || dow == "6,0"),
           let h = Int(hour), let m = Int(min) {
            return "周末 \(String(format: "%02d:%02d", h, m))"
        }
        if dom == "*" && month == "*",
           let h = Int(hour), let m = Int(min),
           let dayNum = Int(dow) {
            let dayNames = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
            let dn = dayNames[safe: dayNum] ?? "周\(dayNum)"
            return "每\(dn) \(String(format: "%02d:%02d", h, m))"
        }
        if dom == "1" && month == "*" && dow == "*",
           let h = Int(hour), let m = Int(min) {
            return "每月 1 日 \(String(format: "%02d:%02d", h, m))"
        }
        if month == "*" && dow == "*",
           let d = Int(dom), let h = Int(hour), let m = Int(min) {
            return "每月 \(d) 日 \(String(format: "%02d:%02d", h, m))"
        }
        return expr
    }

    private static func translateInterval(_ ms: Int) -> String {
        let sec = ms / 1000
        if sec < 60  { return "每 \(sec) 秒" }
        let min = sec / 60
        if min < 60  { return "每 \(min) 分钟" }
        let hr = min / 60
        if hr < 24   { return "每 \(hr) 小时" }
        return "每 \(hr / 24) 天"
    }

    private static func translateEveryString(_ expr: String) -> String {
        let cleaned = expr.replacingOccurrences(of: "ms", with: "")
                          .replacingOccurrences(of: "every ", with: "")
                          .trimmingCharacters(in: .whitespaces)
        if let ms = Int(cleaned) { return translateInterval(ms) }
        return expr
    }

    private static func parseStep(_ s: String) -> Int? {
        s.hasPrefix("*/") ? Int(s.dropFirst(2)) : nil
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

import Foundation

// MARK: - CronJob (decoded from ~/.openclaw/cron/jobs.json)

struct CronJob: Identifiable, Decodable {
    let id: String
    let name: String
    let schedule: CronSchedule
    var enabled: Bool
    let lastRun: CronLastRun?
    let sessionTarget: String?   // "main" | "isolated" | custom key
    let model: String?
    let delivery: CronDelivery?
    let agentId: String?

    // MARK: - Computed

    var scheduleTypeBadge: String {
        switch schedule.type {
        case "cron":  return "定时"
        case "every": return "间隔"
        case "at":    return "一次性"
        default:      return schedule.type
        }
    }

    var humanReadableSchedule: String {
        CronExpressionTranslator.translate(schedule)
    }

    var lastRunDate: Date? {
        guard let ts = lastRun?.timestamp, ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts / 1000)
    }

    var lastRunSucceeded: Bool? {
        guard let status = lastRun?.status else { return nil }
        return status == "ok" || status == "success"
    }

    var sessionTargetDisplay: String {
        switch sessionTarget {
        case "main":     return "main"
        case "isolated": return "isolated"
        case nil:        return "main"
        default:         return sessionTarget ?? "main"
        }
    }
}

// MARK: - Sub-types

struct CronSchedule: Decodable {
    let type: String           // "cron" | "every" | "at"
    let expression: String?    // "0 9 * * 1-5"
    let interval: Int?         // milliseconds, for "every" type
    let at: String?            // ISO date string, for "at" type
    let tz: String?

    private enum CodingKeys: String, CodingKey {
        case type, expression, interval, at, tz
    }
}

struct CronLastRun: Decodable {
    let timestamp: Double?
    let status: String?       // "ok" | "failed" | "running"
    let error: String?
}

struct CronDelivery: Decodable {
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

// MARK: - CronRun (from ~/.openclaw/cron/runs/<jobId>.jsonl)

struct CronRun: Identifiable, Decodable {
    let id: String
    let startedAt: Double?
    let finishedAt: Double?
    let status: String?       // "ok" | "failed"
    let tokens: Int?
    let error: String?

    var startDate: Date? {
        guard let ts = startedAt, ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts / 1000)
    }

    var durationMs: Int? {
        guard let start = startedAt, let finish = finishedAt else { return nil }
        return Int(finish - start)
    }
}

// MARK: - Cron expression translator

enum CronExpressionTranslator {
    static func translate(_ schedule: CronSchedule) -> String {
        switch schedule.type {
        case "cron":
            return translateCron(schedule.expression ?? "")
        case "every":
            if let ms = schedule.interval {
                return translateInterval(ms)
            }
            if let expr = schedule.expression {
                return translateEveryString(expr)
            }
            return schedule.expression ?? "间隔运行"
        case "at":
            if let at = schedule.at {
                let df = ISO8601DateFormatter()
                if let date = df.date(from: at) {
                    let out = DateFormatter()
                    out.dateStyle = .short
                    out.timeStyle = .short
                    out.locale = Locale(identifier: "zh_CN")
                    return out.string(from: date)
                }
                return at
            }
            return "一次性"
        default:
            return schedule.expression ?? schedule.type
        }
    }

    // Translate common cron patterns to human-readable Chinese
    private static func translateCron(_ expr: String) -> String {
        let parts = expr.trimmingCharacters(in: .whitespaces)
                        .split(separator: " ", maxSplits: 4)
                        .map(String.init)
        guard parts.count == 5 else { return expr }
        let (min, hour, dom, month, dow) = (parts[0], parts[1], parts[2], parts[3], parts[4])

        // Every minute
        if expr == "* * * * *" { return "每分钟" }

        // Hourly: "0 * * * *"
        if min == "0" && hour == "*" && dom == "*" && month == "*" && dow == "*" {
            return "每小时整点"
        }

        // Every N minutes: "*/N * * * *"
        if hour == "*" && dom == "*" && month == "*" && dow == "*",
           let n = parseStep(min) {
            return "每 \(n) 分钟"
        }

        // Every N hours: "0 */N * * *"
        if min == "0" && dom == "*" && month == "*" && dow == "*",
           let n = parseStep(hour) {
            return "每 \(n) 小时"
        }

        // Daily at specific time: "MM HH * * *"
        if dom == "*" && month == "*" && dow == "*",
           let h = Int(hour), let m = Int(min) {
            return "每天 \(String(format: "%02d:%02d", h, m))"
        }

        // Weekdays at time: "MM HH * * 1-5"
        if dom == "*" && month == "*" && (dow == "1-5" || dow == "MON-FRI"),
           let h = Int(hour), let m = Int(min) {
            return "工作日 每天 \(String(format: "%02d:%02d", h, m))"
        }

        // Weekends at time: "MM HH * * 0,6" or "MM HH * * 6,0"
        if dom == "*" && month == "*" && (dow == "0,6" || dow == "6,0" || dow == "SAT,SUN"),
           let h = Int(hour), let m = Int(min) {
            return "周末 \(String(format: "%02d:%02d", h, m))"
        }

        // Weekly on a specific day: "MM HH * * N"
        if dom == "*" && month == "*",
           let h = Int(hour), let m = Int(min),
           let dayNum = Int(dow) {
            let dayName = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
            let dn = dayName[safe: dayNum] ?? "周\(dayNum)"
            return "每\(dn) \(String(format: "%02d:%02d", h, m))"
        }

        // Monthly on day 1: "MM HH 1 * *"
        if dom == "1" && month == "*" && dow == "*",
           let h = Int(hour), let m = Int(min) {
            return "每月 1 日 \(String(format: "%02d:%02d", h, m))"
        }

        // First of month (any dom): "MM HH DD * *"
        if month == "*" && dow == "*",
           let d = Int(dom), let h = Int(hour), let m = Int(min) {
            return "每月 \(d) 日 \(String(format: "%02d:%02d", h, m))"
        }

        return expr
    }

    private static func translateInterval(_ ms: Int) -> String {
        let sec = ms / 1000
        if sec < 60 { return "每 \(sec) 秒" }
        let min = sec / 60
        if min < 60 { return "每 \(min) 分钟" }
        let hr = min / 60
        if hr < 24 { return "每 \(hr) 小时" }
        let day = hr / 24
        return "每 \(day) 天"
    }

    private static func translateEveryString(_ expr: String) -> String {
        // Handle "every 3600000ms" or "3600000"
        let cleaned = expr.replacingOccurrences(of: "ms", with: "")
                          .replacingOccurrences(of: "every ", with: "")
                          .trimmingCharacters(in: .whitespaces)
        if let ms = Int(cleaned) { return translateInterval(ms) }
        return expr
    }

    private static func parseStep(_ s: String) -> Int? {
        if s.hasPrefix("*/"), let n = Int(s.dropFirst(2)) { return n }
        return nil
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

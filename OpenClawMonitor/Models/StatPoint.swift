import Foundation

/// One data point for the statistics charts.
struct StatPoint: Identifiable, Codable {
    let id: UUID
    let date: Date
    let tokens: Int
    let inputTokens: Int
    let outputTokens: Int
    let messages: Int
    let avgResponseMs: Int
    let byModel: [String: Int]

    init(date: Date,
         tokens: Int,
         inputTokens: Int = 0,
         outputTokens: Int = 0,
         messages: Int,
         avgResponseMs: Int,
         byModel: [String: Int] = [:]) {
        self.id            = UUID()
        self.date          = date
        self.tokens        = tokens
        self.inputTokens   = inputTokens
        self.outputTokens  = outputTokens
        self.messages      = messages
        self.avgResponseMs = avgResponseMs
        self.byModel       = byModel
    }

    var tokensK: Double         { Double(tokens) / 1000 }
    var responseSeconds: Double { Double(avgResponseMs) / 1000 }
}

enum StatPeriod: String, CaseIterable, Identifiable {
    case daily   = "按天"
    case weekly  = "按周"
    case monthly = "按月"

    var id: String { rawValue }
}

// MARK: - Period aggregation

extension Array where Element == StatPoint {

    /// Returns points filtered / aggregated for the given period.
    func aggregated(for period: StatPeriod) -> [StatPoint] {
        let sorted = self.sorted { $0.date < $1.date }
        switch period {
        case .daily:
            return Array(sorted.suffix(14))
        case .weekly:
            return grouped(by: .weekOfYear, maxGroups: 12)
        case .monthly:
            return grouped(by: .month, maxGroups: 12)
        }
    }

    private func grouped(by component: Calendar.Component, maxGroups: Int) -> [StatPoint] {
        let cal = Calendar.current
        var groups: [Date: [StatPoint]] = [:]
        for pt in self {
            guard let start = cal.dateInterval(of: component, for: pt.date)?.start else { continue }
            groups[start, default: []].append(pt)
        }
        let result = groups.map { start, pts -> StatPoint in
            let totalTokens  = pts.reduce(0) { $0 + $1.tokens }
            let inputTokens  = pts.reduce(0) { $0 + $1.inputTokens }
            let outputTokens = pts.reduce(0) { $0 + $1.outputTokens }
            let totalMsgs    = pts.reduce(0) { $0 + $1.messages }
            let avgMs        = pts.isEmpty ? 0 : pts.reduce(0) { $0 + $1.avgResponseMs } / pts.count
            var byModel: [String: Int] = [:]
            for pt in pts {
                for (model, count) in pt.byModel { byModel[model, default: 0] += count }
            }
            return StatPoint(date: start, tokens: totalTokens, inputTokens: inputTokens,
                             outputTokens: outputTokens, messages: totalMsgs,
                             avgResponseMs: avgMs, byModel: byModel)
        }
        return Array(result.sorted { $0.date < $1.date }.suffix(maxGroups))
    }
}

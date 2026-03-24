import SwiftUI
import Charts

// MARK: - Dimension

enum StatDimension: String, CaseIterable, Identifiable {
    case overview = "总览"
    case byModel  = "按模型"
    case byAgent  = "按 Agent"
    var id: String { rawValue }
}

// MARK: - Main View

struct StatisticsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var period:    StatPeriod    = .daily
    @State private var dimension: StatDimension = .overview

    private var points: [StatPoint] {
        viewModel.statPoints.aggregated(for: period)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // ── Controls ──────────────────────────────────────────────
                HStack(spacing: 16) {
                    Picker("时间维度", selection: $period) {
                        ForEach(StatPeriod.allCases) { p in Text(p.rawValue).tag(p) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)

                    Spacer()

                    Picker("分析维度", selection: $dimension) {
                        ForEach(StatDimension.allCases) { d in Text(d.rawValue).tag(d) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                }

                // ── Content ───────────────────────────────────────────────
                if viewModel.statPoints.isEmpty {
                    EmptyStatsView()
                } else {
                    switch dimension {
                    case .overview:
                        OverviewSection(points: points, period: period)
                    case .byModel:
                        ByModelSection(points: points, period: period)
                    case .byAgent:
                        ByAgentSection(agentUsage: viewModel.agentUsage)
                    }
                }
            }
            .padding(24)
        }
        .background(Color(.windowBackgroundColor))
    }
}

// MARK: - Shared helpers

private func xUnit(for p: StatPeriod) -> Calendar.Component {
    switch p { case .daily: return .day; case .weekly: return .weekOfYear; case .monthly: return .month }
}
private func xFmt(for p: StatPeriod) -> Date.FormatStyle {
    switch p {
    case .daily, .weekly: return .dateTime.month().day()
    case .monthly:        return .dateTime.year().month()
    }
}
private func nearest(to date: Date, in pts: [StatPoint]) -> StatPoint? {
    pts.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
}
private func fmtTokens(_ n: Int) -> String {
    if n >= 1_000_000 { return String(format: "%.2fM", Double(n) / 1_000_000) }
    if n >= 1_000     { return String(format: "%.0fK", Double(n) / 1_000) }
    return "\(n)"
}

private let palette: [Color] = [.indigo, .cyan, .orange, .green, .pink, .yellow, .purple, .teal]

// MARK: - Empty State

private struct EmptyStatsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("暂无历史数据")
                .font(.title3).fontWeight(.medium)
            Text("连接 Gateway 后自动加载")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }
}

// MARK: - Tooltip Card

private struct TooltipCard: View {
    let date: Date
    let tokens: Int
    let messages: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(date.formatted(.dateTime.month().day()))
                .font(.caption2).fontWeight(.semibold)
                .foregroundStyle(.secondary)
            HStack(spacing: 14) {
                Label(fmtTokens(tokens), systemImage: "bolt.fill")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.indigo)
                Label("\(messages) 条", systemImage: "message.fill")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.purple)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
    }
}

// MARK: - Progress Bar Row (shared)

private struct ProgressRow: View {
    let label: String
    let tokens: Int
    let total: Int
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.callout)
            Spacer()
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.75))
                        .frame(width: total > 0
                               ? geo.size.width * min(CGFloat(tokens) / CGFloat(total), 1)
                               : 0)
                }
            }
            .frame(width: 120, height: 5)
            Text(fmtTokens(tokens))
                .font(.callout).fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(width: 75, alignment: .trailing)
        }
    }
}

// MARK: - Overview Section

private struct OverviewSection: View {
    let points: [StatPoint]
    let period: StatPeriod

    var body: some View {
        VStack(spacing: 20) {
            TokenChart(points: points, period: period)
            MessageChart(points: points, period: period)
        }
    }
}

// MARK: - Token Chart

private struct TokenChart: View {
    let points: [StatPoint]
    let period: StatPeriod
    @State private var rawDate: Date?

    private var selected: StatPoint? { rawDate.flatMap { nearest(to: $0, in: points) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Token 消耗趋势", systemImage: "waveform.path")
                .font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)

            Chart {
                ForEach(points) { p in
                    AreaMark(x: .value("日期", p.date, unit: xUnit(for: period)),
                             y: .value("Token", p.tokensK))
                        .foregroundStyle(.indigo.opacity(0.15))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("日期", p.date, unit: xUnit(for: period)),
                             y: .value("Token", p.tokensK))
                        .foregroundStyle(.indigo)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    PointMark(x: .value("日期", p.date, unit: xUnit(for: period)),
                              y: .value("Token", p.tokensK))
                        .foregroundStyle(.indigo).symbolSize(30)
                }
                if let sel = selected {
                    RuleMark(x: .value("选中", sel.date, unit: xUnit(for: period)))
                        .foregroundStyle(.white.opacity(0.2)).zIndex(-1)
                        .annotation(position: .top, spacing: 0,
                                    overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            TooltipCard(date: sel.date, tokens: sel.tokens, messages: sel.messages)
                        }
                }
            }
            .chartXAxis { AxisMarks { AxisGridLine(); AxisValueLabel(format: xFmt(for: period)) } }
            .chartYAxis {
                AxisMarks { v in
                    AxisValueLabel { if let d = v.as(Double.self) { Text(String(format: "%.0fK", d)) } }
                }
            }
            .frame(height: 200)
            .chartOverlay { proxy in
                GeometryReader { _ in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let loc): rawDate = proxy.value(atX: loc.x)
                            case .ended:           rawDate = nil
                            }
                        }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Message Chart

private struct MessageChart: View {
    let points: [StatPoint]
    let period: StatPeriod
    @State private var rawDate: Date?

    private var selected: StatPoint? { rawDate.flatMap { nearest(to: $0, in: points) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("消息数趋势", systemImage: "chart.bar.fill")
                .font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)

            Chart {
                ForEach(points) { p in
                    BarMark(x: .value("日期", p.date, unit: xUnit(for: period)),
                            y: .value("消息数", p.messages))
                        .foregroundStyle(LinearGradient(colors: [.indigo, .purple],
                                                       startPoint: .bottom, endPoint: .top))
                        .cornerRadius(4)
                }
                if let sel = selected {
                    RuleMark(x: .value("选中", sel.date, unit: xUnit(for: period)))
                        .foregroundStyle(.white.opacity(0.2)).zIndex(-1)
                        .annotation(position: .top, spacing: 0,
                                    overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            TooltipCard(date: sel.date, tokens: sel.tokens, messages: sel.messages)
                        }
                }
            }
            .chartXAxis { AxisMarks { AxisGridLine(); AxisValueLabel(format: xFmt(for: period)) } }
            .frame(height: 160)
            .chartOverlay { proxy in
                GeometryReader { _ in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let loc): rawDate = proxy.value(atX: loc.x)
                            case .ended:           rawDate = nil
                            }
                        }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - By Model Section

private struct ModelPoint: Identifiable {
    let id = UUID()
    let date: Date; let model: String; let tokens: Int
}

private struct ByModelSection: View {
    let points: [StatPoint]
    let period: StatPeriod

    private var modelPoints: [ModelPoint] {
        points.flatMap { p in
            p.byModel.map { ModelPoint(date: p.date, model: $0.key, tokens: $0.value) }
        }.sorted { $0.date < $1.date }
    }
    private var allModels: [String] {
        Array(Set(modelPoints.map(\.model))).sorted()
    }
    private var modelTotals: [(model: String, tokens: Int)] {
        var t: [String: Int] = [:]
        modelPoints.forEach { t[$0.model, default: 0] += $0.tokens }
        return t.map { (model: $0.key, tokens: $0.value) }.sorted { $0.tokens > $1.tokens }
    }
    private var grandTotal: Int { modelTotals.reduce(0) { $0 + $1.tokens } }

    var body: some View {
        VStack(spacing: 20) {
            // ── Stacked bar chart ──────────────────────────────────────
            VStack(alignment: .leading, spacing: 8) {
                Label("每日 Token 消耗（按模型叠加）", systemImage: "square.stack.3d.up")
                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)

                if modelPoints.isEmpty {
                    Text("无模型明细数据").font(.callout).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 100)
                } else {
                    Chart(modelPoints) { mp in
                        BarMark(x: .value("日期", mp.date, unit: xUnit(for: period)),
                                y: .value("Token", mp.tokens / 1000))
                            .foregroundStyle(by: .value("模型", mp.model))
                            .cornerRadius(2)
                    }
                    .chartForegroundStyleScale(
                        domain: allModels,
                        range: allModels.enumerated().map { palette[$0.offset % palette.count] }
                    )
                    .chartXAxis { AxisMarks { AxisGridLine(); AxisValueLabel(format: xFmt(for: period)) } }
                    .chartYAxis {
                        AxisMarks { v in
                            AxisValueLabel { if let d = v.as(Double.self) { Text(String(format: "%.0fK", d)) } }
                        }
                    }
                    .chartLegend(position: .bottom, alignment: .leading, spacing: 8)
                    .frame(height: 230)
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            // ── Per-model breakdown ────────────────────────────────────
            VStack(alignment: .leading, spacing: 14) {
                Label("模型总计", systemImage: "list.bullet")
                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)

                ForEach(Array(modelTotals.enumerated()), id: \.offset) { i, item in
                    ProgressRow(label: item.model, tokens: item.tokens,
                                total: grandTotal, color: palette[i % palette.count])
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - By Agent Section

private struct ByAgentSection: View {
    let agentUsage: [String: Int]

    private var sorted: [(id: String, tokens: Int)] {
        agentUsage.map { (id: $0.key, tokens: $0.value) }.sorted { $0.tokens > $1.tokens }
    }
    private var grandTotal: Int { sorted.reduce(0) { $0 + $1.tokens } }

    var body: some View {
        VStack(spacing: 20) {
            // ── Horizontal bar chart ───────────────────────────────────
            VStack(alignment: .leading, spacing: 8) {
                Label("Agent Token 消耗", systemImage: "person.2.fill")
                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)

                if sorted.isEmpty {
                    Text("暂无 Agent 使用数据").font(.callout).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    Chart(sorted, id: \.id) { item in
                        BarMark(x: .value("Token", item.tokens / 1000),
                                y: .value("Agent", item.id))
                            .foregroundStyle(by: .value("Agent", item.id))
                            .cornerRadius(5)
                            .annotation(position: .trailing, alignment: .leading) {
                                Text(fmtTokens(item.tokens))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                    }
                    .chartForegroundStyleScale(
                        domain: sorted.map(\.id),
                        range: sorted.enumerated().map { palette[$0.offset % palette.count] }
                    )
                    .chartXAxis {
                        AxisMarks { v in
                            AxisValueLabel { if let d = v.as(Double.self) { Text(String(format: "%.0fK", d)) } }
                        }
                    }
                    .chartLegend(.hidden)
                    .frame(height: max(100, CGFloat(sorted.count) * 56))
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            // ── Agent detail list ──────────────────────────────────────
            VStack(alignment: .leading, spacing: 14) {
                Label("Agent 明细", systemImage: "list.bullet")
                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(.secondary)

                ForEach(Array(sorted.enumerated()), id: \.offset) { i, item in
                    ProgressRow(label: item.id, tokens: item.tokens,
                                total: grandTotal, color: palette[i % palette.count])
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

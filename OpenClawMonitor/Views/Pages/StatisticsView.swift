import SwiftUI
import Charts

struct StatisticsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @StateObject private var collector = StatsCollector.shared
    @State private var period: StatPeriod = .daily

    private var points: [StatPoint] {
        viewModel.statPoints.aggregated(for: period)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // ── Period picker ──────────────────────────────────────────
                Picker("时间维度", selection: $period) {
                    ForEach(StatPeriod.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)

                if collector.isLoading && viewModel.statPoints.isEmpty {
                    // Loading state
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("正在扫描日志文件…")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)

                } else if points.isEmpty {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("暂无历史数据")
                            .font(.title3).fontWeight(.medium)
                        Text("OpenClaw 日志文件位于 /tmp/openclaw/openclaw-YYYY-MM-DD.log")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)

                } else {
                    // ── Charts ────────────────────────────────────────────
                    HStack(alignment: .top, spacing: 20) {
                        TokenChart(points: points, period: period)
                        ResponseChart(points: points, period: period)
                    }
                    MessageChart(points: points, period: period)
                }
            }
            .padding(24)
        }
        .background(Color(.windowBackgroundColor))
    }
}

// MARK: - Shared x-axis helper

private func xAxisUnit(for period: StatPeriod) -> Calendar.Component {
    switch period {
    case .daily:   return .day
    case .weekly:  return .weekOfYear
    case .monthly: return .month
    }
}

private func xAxisFormat(for period: StatPeriod) -> Date.FormatStyle {
    switch period {
    case .daily:   return .dateTime.month().day()
    case .weekly:  return .dateTime.month().day()
    case .monthly: return .dateTime.year().month()
    }
}

// MARK: - Token consumption (AreaMark + LineMark + PointMark)

private struct TokenChart: View {
    let points: [StatPoint]
    let period: StatPeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Token 消耗趋势", systemImage: "waveform.path")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Chart(points) { p in
                AreaMark(x: .value("日期", p.date, unit: xAxisUnit(for: period)),
                         y: .value("Token", p.tokensK))
                    .foregroundStyle(.indigo.opacity(0.15))
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("日期", p.date, unit: xAxisUnit(for: period)),
                         y: .value("Token", p.tokensK))
                    .foregroundStyle(.indigo)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                PointMark(x: .value("日期", p.date, unit: xAxisUnit(for: period)),
                          y: .value("Token", p.tokensK))
                    .foregroundStyle(.indigo)
                    .symbolSize(30)
            }
            .chartXAxis {
                AxisMarks {
                    AxisGridLine()
                    AxisValueLabel(format: xAxisFormat(for: period))
                }
            }
            .chartYAxis {
                AxisMarks { v in
                    AxisValueLabel {
                        if let d = v.as(Double.self) {
                            Text(String(format: "%.0fk", d))
                        }
                    }
                }
            }
            .frame(height: 200)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Avg response time (LineMark + PointMark)

private struct ResponseChart: View {
    let points: [StatPoint]
    let period: StatPeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("平均响应时间", systemImage: "timer")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Chart(points) { p in
                LineMark(x: .value("日期", p.date, unit: xAxisUnit(for: period)),
                         y: .value("响应 (s)", p.responseSeconds))
                    .foregroundStyle(.cyan)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                PointMark(x: .value("日期", p.date, unit: xAxisUnit(for: period)),
                          y: .value("响应 (s)", p.responseSeconds))
                    .foregroundStyle(.cyan)
                    .symbolSize(30)
            }
            .chartXAxis {
                AxisMarks {
                    AxisGridLine()
                    AxisValueLabel(format: xAxisFormat(for: period))
                }
            }
            .frame(height: 200)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Message count (BarMark)

private struct MessageChart: View {
    let points: [StatPoint]
    let period: StatPeriod

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("消息数趋势", systemImage: "chart.bar.fill")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Chart(points) { p in
                BarMark(x: .value("日期", p.date, unit: xAxisUnit(for: period)),
                        y: .value("消息数", p.messages))
                    .foregroundStyle(
                        LinearGradient(colors: [.indigo, .purple],
                                       startPoint: .bottom, endPoint: .top)
                    )
                    .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks {
                    AxisGridLine()
                    AxisValueLabel(format: xAxisFormat(for: period))
                }
            }
            .frame(height: 160)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

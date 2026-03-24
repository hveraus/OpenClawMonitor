import SwiftUI

struct CronJobsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @StateObject private var cronService = CronService.shared
    @State private var actionInProgress: String? = nil   // jobId being actioned
    @State private var actionError: String?   = nil

    private var jobs: [CronJob] {
        viewModel.isUsingMockData ? MockData.cronJobs : cronService.jobs
    }

    var body: some View {
        Group {
            if jobs.isEmpty {
                emptyState
            } else {
                jobList
            }
        }
        .background(Color(.windowBackgroundColor))
        .task {
            if !viewModel.isUsingMockData {
                cronService.loadJobs()
            }
        }
        .alert("操作失败", isPresented: .init(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )) {
            Button("确定", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
    }

    // MARK: - Job list

    private var jobList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(jobs) { job in
                    CronJobRow(
                        job: job,
                        isActioning: actionInProgress == job.id,
                        onEnable:  { await toggleJob(job, enable: true) },
                        onDisable: { await toggleJob(job, enable: false) },
                        onRunNow:  { await runJobNow(job) }
                    )
                }
            }
            .padding(16)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.xmark")
                .font(.system(size: 48))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
            Text("暂无 Cron 任务")
                .font(.title3).fontWeight(.medium)
                .foregroundStyle(.secondary)
            Text("在 ~/.openclaw/cron/jobs.json 中添加定时任务后，\n它们将显示在此处。")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func toggleJob(_ job: CronJob, enable: Bool) async {
        actionInProgress = job.id
        defer { actionInProgress = nil }
        let ok = enable
            ? await cronService.enableJob(job.id)
            : await cronService.disableJob(job.id)
        if !ok {
            actionError = enable
                ? "无法启用任务「\(job.name)」，请确认 openclaw CLI 已正确安装。"
                : "无法禁用任务「\(job.name)」。"
        }
    }

    private func runJobNow(_ job: CronJob) async {
        actionInProgress = job.id
        defer { actionInProgress = nil }
        let ok = await cronService.runJobNow(job.id)
        if !ok {
            actionError = "无法立即运行任务「\(job.name)」，请确认 openclaw CLI 已正确安装。"
        }
    }
}

// MARK: - CronJobRow

private struct CronJobRow: View {
    let job: CronJob
    let isActioning: Bool
    let onEnable:  () async -> Void
    let onDisable: () async -> Void
    let onRunNow:  () async -> Void

    @State private var isHovered = false
    @State private var showingRuns = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mainContent
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .opacity(job.enabled ? 1.0 : 0.5)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovered ? Color.accentColor.opacity(0.3) : .clear, lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.005 : 1.0)
        .shadow(color: .black.opacity(isHovered ? 0.12 : 0.04), radius: isHovered ? 10 : 4)
        .animation(.spring(response: 0.3), value: isHovered)
        .onHover { isHovered = $0 }
        .contextMenu { contextMenuItems }
    }

    // MARK: Main row content

    private var mainContent: some View {
        HStack(alignment: .top, spacing: 12) {
            // Status dot
            VStack {
                Circle()
                    .fill(job.enabled ? Color.green : Color(.darkGray))
                    .frame(width: 9, height: 9)
                    .shadow(color: job.enabled ? .green.opacity(0.6) : .clear, radius: 4)
                    .padding(.top, 4)
                Spacer()
            }

            // Main info
            VStack(alignment: .leading, spacing: 6) {
                // Row 1: name + badges
                HStack(spacing: 8) {
                    Text(job.name)
                        .font(.headline).fontWeight(.semibold)

                    ScheduleTypeBadge(type: job.scheduleTypeBadge)

                    if let modelOverride = job.model {
                        Text(modelOverride)
                            .font(.caption2)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(.purple.opacity(0.15), in: Capsule())
                            .foregroundStyle(.purple)
                    }

                    Spacer()

                    // Last run result indicator
                    if let succeeded = job.lastRunSucceeded {
                        Image(systemName: succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(succeeded ? .green : .red)
                            .font(.callout)
                    }
                }

                // Row 2: schedule expression
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(job.humanReadableSchedule)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    if let expr = job.schedule.expression {
                        Text("(\(expr))")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    if let tz = job.schedule.tz {
                        Text(tz)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Color(.quaternaryLabelColor).opacity(0.3), in: Capsule())
                    }
                }

                // Row 3: meta info
                HStack(spacing: 16) {
                    if let lastDate = job.lastRunDate {
                        Label {
                            Text(lastDate, style: .relative) + Text(" 前")
                        } icon: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    } else {
                        Label("从未运行", systemImage: "minus.circle")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Label(sessionTargetDisplay, systemImage: "target")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let delivery = job.delivery, delivery.display != "—" {
                        Label(delivery.display, systemImage: "paperplane")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Action buttons (always visible on hover, always available via context menu)
            if isHovered || isActioning {
                HStack(spacing: 6) {
                    if isActioning {
                        ProgressView().controlSize(.small).frame(width: 26, height: 26)
                    } else {
                        actionButtons
                    }
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
    }

    private var sessionTargetDisplay: String {
        switch job.sessionTarget {
        case "isolated": return "独立会话"
        case nil, "main": return "主会话"
        default: return job.sessionTarget ?? "主会话"
        }
    }

    // MARK: Action buttons

    @ViewBuilder
    private var actionButtons: some View {
        if job.enabled {
            Button {
                Task { await onDisable() }
            } label: {
                Label("禁用", systemImage: "pause.circle")
                    .labelStyle(.iconOnly)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.orange)
            .help("禁用此任务")
        } else {
            Button {
                Task { await onEnable() }
            } label: {
                Label("启用", systemImage: "play.circle")
                    .labelStyle(.iconOnly)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.green)
            .help("启用此任务")
        }

        Button {
            Task { await onRunNow() }
        } label: {
            Label("立即运行", systemImage: "bolt.circle")
                .labelStyle(.iconOnly)
                .font(.title3)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.blue)
        .help("立即运行一次")
    }

    // MARK: Context menu

    @ViewBuilder
    private var contextMenuItems: some View {
        if job.enabled {
            Button {
                Task { await onDisable() }
            } label: {
                Label("禁用任务", systemImage: "pause.circle")
            }
        } else {
            Button {
                Task { await onEnable() }
            } label: {
                Label("启用任务", systemImage: "play.circle")
            }
        }

        Button {
            Task { await onRunNow() }
        } label: {
            Label("立即运行", systemImage: "bolt.circle")
        }

        Divider()

        Button {
            let info = """
            任务: \(job.name)
            调度: \(job.humanReadableSchedule)
            ID: \(job.id)
            """
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(info, forType: .string)
        } label: {
            Label("复制任务信息", systemImage: "doc.on.doc")
        }
    }
}

// MARK: - Schedule type badge

private struct ScheduleTypeBadge: View {
    let type: String

    private var color: Color {
        switch type {
        case "定时":  return .blue
        case "间隔":  return .teal
        case "一次性": return .purple
        default:      return .gray
        }
    }

    var body: some View {
        Text(type)
            .font(.caption2).fontWeight(.semibold)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

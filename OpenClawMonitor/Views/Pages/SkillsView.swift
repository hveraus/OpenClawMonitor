import SwiftUI

struct SkillsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var searchText = ""
    @State private var filterType: SkillTypeFilter = .all

    private enum SkillTypeFilter: String, CaseIterable, Identifiable {
        case all  = "全部"
        case builtin  = "内置"
        case extended = "扩展"
        case custom   = "自定义"
        var id: String { rawValue }
    }

    private let columns = [GridItem(.adaptive(minimum: 240, maximum: 340), spacing: 14)]

    private var filtered: [SkillInfo] {
        viewModel.skills.filter { skill in
            let typeMatch: Bool = {
                switch filterType {
                case .all:      return true
                case .builtin:  return skill.type == .builtin
                case .extended: return skill.type == .extended
                case .custom:   return skill.type == .custom
                }
            }()
            let textMatch = searchText.isEmpty
                || skill.name.localizedCaseInsensitiveContains(searchText)
                || skill.description.localizedCaseInsensitiveContains(searchText)
            return typeMatch && textMatch
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Filter bar ─────────────────────────────────────────────────
            HStack(spacing: 12) {
                Picker("类型", selection: $filterType) {
                    ForEach(SkillTypeFilter.allCases) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)

                Spacer()

                Text("\(filtered.count) 个技能")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            // ── Skill grid ─────────────────────────────────────────────────
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(filtered) { skill in
                        SkillCard(skill: skill)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .padding(20)
                .animation(.spring(response: 0.35), value: filtered.count)
            }
        }
        .searchable(text: $searchText, prompt: "搜索技能名称或描述")
        .background(Color(.windowBackgroundColor))
    }
}

// MARK: - Skill card

private struct SkillCard: View {
    let skill: SkillInfo
    @State private var isHovered = false

    private var statusColor: Color {
        if skill.isEnabled   { return .green }
        if !skill.isEligible { return .orange }
        return Color(.darkGray)
    }

    private var statusLabel: String {
        if skill.isEnabled   { return "可用" }
        if !skill.isEligible { return "缺少依赖" }
        return "已禁用"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let emoji = skill.emoji {
                    Text(emoji)
                        .font(.title3)
                } else {
                    Image(systemName: skill.type.icon)
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.indigo)
                }
                Spacer()
                // Type badge
                Text(skill.type.rawValue)
                    .font(.caption2).fontWeight(.semibold)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.indigo.opacity(0.15), in: Capsule())
                    .foregroundStyle(.indigo)
            }

            Text(skill.name)
                .font(.headline).fontWeight(.semibold)

            Text(skill.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack {
                if let v = skill.version {
                    Text("v\(v)").font(.caption2).foregroundStyle(.tertiary)
                }
                Spacer()
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: skill.isEnabled ? .green.opacity(0.7) : .clear, radius: 4)
                Text(statusLabel)
                    .font(.caption2)
                    .foregroundStyle(statusColor)
            }
        }
        .padding(14)
        .frame(height: 140)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .opacity(skill.isEnabled ? 1.0 : (skill.isEligible ? 0.5 : 0.7))
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .shadow(color: .black.opacity(isHovered ? 0.15 : 0.05), radius: isHovered ? 12 : 4)
        .animation(.spring(response: 0.3), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

import Foundation

enum TokenPeriod: String, CaseIterable, Hashable {
    case all       = "全部"
    case thisYear  = "今年"
    case thisMonth = "本月"
    case thisWeek  = "本周"
    case custom    = "自定义"
}

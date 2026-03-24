import Foundation

struct SkillInfo: Identifiable {
    let id: String
    let name: String
    let description: String
    let type: SkillType
    var isEnabled: Bool     // eligible == 1 && disabled == 0
    var isEligible: Bool    // all requirements met (regardless of disabled)
    let version: String?
    let author: String?
    let emoji: String?

    init(id: String, name: String, description: String,
         type: SkillType, isEnabled: Bool = true, isEligible: Bool = true,
         version: String? = nil, author: String? = nil,
         emoji: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.isEnabled = isEnabled
        self.isEligible = isEligible
        self.version = version
        self.author = author
        self.emoji = emoji
    }
}

enum SkillType: String, CaseIterable {
    case builtin   = "内置"
    case extended  = "扩展"
    case custom    = "自定义"

    var icon: String {
        switch self {
        case .builtin:  return "shippingbox.fill"
        case .extended: return "puzzlepiece.fill"
        case .custom:   return "wrench.and.screwdriver.fill"
        }
    }
}

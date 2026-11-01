import Foundation

// シミュレータでの画面確認用。Debugビルドの起動引数でのみ有効
enum LaunchMode {
    case live
    case demo(showsCarrierSheet: Bool)

    static var current: LaunchMode {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-demo") {
            return .demo(showsCarrierSheet: arguments.contains("-demo-carrier"))
        }
        #endif
        return .live
    }

    static func demoDate(calendar: Calendar) -> Date {
        let now = Date()
        var parts = calendar.dateComponents([.year, .month], from: now)
        parts.day = 15
        parts.hour = 23
        return calendar.date(from: parts) ?? now
    }
}

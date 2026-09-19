import SwiftUI

/// 习惯色 #RRGGBB。app 与 widget 扩展共用（W7 Widget 引入时从 app target 上移）。
extension Color {
    public init(hex: String) {
        var v = hex
        if v.hasPrefix("#") { v.removeFirst() }
        let n = UInt64(v, radix: 16) ?? 0x4F8CFF
        self.init(red: Double((n >> 16) & 0xFF) / 255,
                  green: Double((n >> 8) & 0xFF) / 255,
                  blue: Double(n & 0xFF) / 255)
    }
}

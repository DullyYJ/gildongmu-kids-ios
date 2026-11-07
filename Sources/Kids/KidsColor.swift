import SwiftUI

/// 부모 앱의 Shared/Overlay.swift 에 있는 Color(argb:) — 공유 그리개(UI/NodeView*)가 쓰므로 키즈에도 같은 것을 둔다.
extension Color {
    init(argb: Int) {
        self.init(.sRGB, red: Double((argb >> 16) & 255) / 255, green: Double((argb >> 8) & 255) / 255, blue: Double(argb & 255) / 255, opacity: Double((argb >> 24) & 255) / 255)
    }
}

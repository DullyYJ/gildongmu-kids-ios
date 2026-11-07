import SwiftUI

@main
struct KidsApp: App {
    init() {
        // 시험용(클라우드 맥 화면 캡처): `-kidsDemo 1` 이면 동의를 마친 것으로 시작한다.
        if CommandLine.arguments.contains("-kidsDemo") { UserDefaults.standard.set(2, forKey: "kids.consent"); UserDefaults.standard.set(false, forKey: "kids.share") }
    }
    var body: some Scene {
        WindowGroup { KidsRoot() }
    }
}

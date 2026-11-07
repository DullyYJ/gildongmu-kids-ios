import SwiftUI

/// 키즈 서버가 준 화면·상태를 들고 있는 곳. 앱은 해석하지 않는다 — 받은 blocks 는 그대로 그림판(KidsBlocksView)에 넘기고,
/// 바뀔 때까지 붙들어 두는 긴 대기(/c/wait)로 실시간을 이어 간다(부모가 글을 보내면 바로 뜬다).
@MainActor
final class KidsStore: ObservableObject {
    static let shared = KidsStore()

    @Published private(set) var chat: [String: Any]? = nil
    @Published private(set) var questC: [String: Any]? = nil
    @Published private(set) var questP: [String: Any]? = nil
    @Published private(set) var linked = 0
    @Published private(set) var stars = 0
    @Published private(set) var cheers: [String] = []
    @Published var notice: String? = nil
    @Published private(set) var offline = false
    /// 퀘스트의 칸(c = 자녀 미션, p = 부모님 미션) — 서버가 두 칸을 모두 보내 주니 고르는 건 화면에서만.
    @Published var qt = "c"

    private var rev = 0
    private var tab = "chat"
    private var task: Task<Void, Never>?

    /// 가족대화·퀘스트 탭이 앞에 있는 동안만 서버를 붙들어 둔다.
    func watch(_ tab: String?) {
        task?.cancel(); task = nil
        guard let t = tab else { return }
        self.tab = t; rev = 0
        task = Task { [weak self] in await self?.loop(t) }
    }
    func stop() { watch(nil) }

    private func loop(_ t: String) async {
        var first = true
        while !Task.isCancelled {
            do {
                if t == "quest" {
                    if first { for q in ["p", "c"] { apply(try await KidsServer.bundle(tab: "quest", qt: q, since: nil, fg: true), single: q) } }
                    else { apply(try await KidsServer.bundle(tab: "quest", qt: qt, since: rev, fg: true), single: nil) }
                } else {
                    apply(try await KidsServer.bundle(tab: "chat", qt: qt, since: first ? nil : rev, fg: true), single: nil)
                }
                first = false; offline = false
            } catch {
                if Task.isCancelled { return }
                offline = true
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private func apply(_ o: [String: Any], single: String?) {
        if (o["same"] as? NSNumber)?.intValue == 1 { return }
        if let r = o["rev"] as? NSNumber { rev = r.intValue }
        if let l = o["linked"] as? NSNumber { linked = l.intValue }
        if let s = o["stars"] as? NSNumber { stars = s.intValue }
        if let c = o["cheers"] as? [String] { cheers = c }
        if let s = o["screen"] as? [String: Any] {
            if tab == "chat" { chat = s } else if single == "c" { questC = s } else if single == "p" { questP = s }
        }
        if let ss = o["screens"] as? [String: Any] { questC = ss["c"] as? [String: Any] ?? questC; questP = ss["p"] as? [String: Any] ?? questP }
        if let n = o["notice"] as? String, !n.isEmpty { say(n) }
    }

    /// 눌림·보내기. 새 화면과 상태는 서버가 돌려준다.
    func act(_ v: String, arg: String = "") async {
        do { apply(try await KidsServer.act(v, arg: arg, tab: tab, qt: qt), single: nil) }
        catch { say(error.localizedDescription) }
    }
    /// 홈 화면용 상태만 가볍게(연결 수 · 별 · 응원 문구).
    func refreshState() async {
        if let o = try? await KidsServer.state() { apply(o, single: nil) }
    }
    func noteLinked(_ n: Int) { if linked != n { linked = n } }
    func say(_ m: String) {
        notice = m
        Task { try? await Task.sleep(nanoseconds: 2_800_000_000); if notice == m { notice = nil } }
    }
}

import Foundation
import Security

/// 키즈 서버(gildongmu-kids 워커)와 말한다. 기기마다 처음 한 번 아이디·비밀을 만들어 등록하고(role c), 이후 모든 요청에 x-id / x-sec 를 붙인다.
/// 앱은 판단하지 않는다 — 화면(blocks)·상태·알림 글은 서버가 정해 주고 앱은 그대로 그린다. 서버 규약은 안드로이드 키즈 저장소의 ENGINE.md.
enum KidsServer {
    private static let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
    private static func rand(_ n: Int) -> String { String((0..<n).map { _ in chars[Int.random(in: 0..<chars.count)] }) }

    // ── 열쇠고리(Keychain)에 아이디·비밀 보관 ──
    private static func kcGet(_ k: String) -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.dullyyj.kids", kSecAttrAccount as String: k, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
    private static func kcSet(_ k: String, _ v: String) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.dullyyj.kids", kSecAttrAccount as String: k]
        SecItemDelete(base as CFDictionary)
        var a = base; a[kSecValueData as String] = Data(v.utf8); a[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(a as CFDictionary, nil)
    }
    static var id: String { if let v = kcGet("id") { return v }; let v = "k" + rand(23); kcSet("id", v); return v }
    static var sec: String { if let v = kcGet("sec") { return v }; let v = rand(40); kcSet("sec", v); return v }

    private static let regLock = NSLock()
    private static var registered = UserDefaults.standard.bool(forKey: "kids.reg")

    static func ensureReg() async throws {
        regLock.lock(); let done = registered; regLock.unlock()
        if done { return }
        let body = try JSONSerialization.data(withJSONObject: ["id": id, "sec": sec, "role": "c"])
        let (st, _) = try await send("POST", "/reg", body: body, auth: false)
        if st == 200 { regLock.lock(); registered = true; regLock.unlock(); UserDefaults.standard.set(true, forKey: "kids.reg") }
        else { throw Net.Failure(msg: "등록하지 못했어요 (\(st))") }
    }

    private static func send(_ method: String, _ path: String, body: Data? = nil, auth: Bool = true, timeout: TimeInterval = 12) async throws -> (Int, Data) {
        guard let u = URL(string: Servers.kids + path) else { throw Net.Failure(msg: "주소 오류") }
        var r = URLRequest(url: u, timeoutInterval: timeout)
        r.httpMethod = method
        if auth { r.setValue(id, forHTTPHeaderField: "x-id"); r.setValue(sec, forHTTPHeaderField: "x-sec") }
        if let b = body { r.httpBody = b; r.setValue("application/json", forHTTPHeaderField: "content-type") }
        let (d, resp) = try await URLSession.shared.data(for: r)
        return ((resp as? HTTPURLResponse)?.statusCode ?? 0, d)
    }

    /// 서버 답(JSON 객체). 401 이면 등록이 풀린 것이니 다시 등록하고 한 번 더 묻는다.
    static func call(_ method: String, _ path: String, _ body: [String: Any]? = nil, timeout: TimeInterval = 12) async throws -> [String: Any] {
        try await ensureReg()
        let data = body.flatMap { try? JSONSerialization.data(withJSONObject: $0) }
        var (st, d) = try await send(method, path, body: data, timeout: timeout)
        if st == 401 { UserDefaults.standard.set(false, forKey: "kids.reg"); regLock.lock(); registered = false; regLock.unlock(); try await ensureReg(); (st, d) = try await send(method, path, body: data, timeout: timeout) }
        guard let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { throw Net.Failure(msg: "서버 \(st)") }
        if st >= 400 { throw Net.Failure(msg: (o["err"] as? String) ?? (o["msg"] as? String) ?? "서버 \(st)") }
        return o
    }

    // ── 화면 · 행동 ──
    /// 지금 보는 탭의 묶음을 받는다. since 가 있으면 바뀔 때까지 붙들어 두었다 준다(긴 대기).
    static func bundle(tab: String, qt: String, since: Int?, fg: Bool) async throws -> [String: Any] {
        if let s = since { return try await call("GET", "/c/wait?since=\(s)&tab=\(tab)&qt=\(qt)&fg=\(fg ? 1 : 0)", timeout: 25) }
        return try await call("GET", "/c/screen?tab=\(tab)&qt=\(qt)&fg=\(fg ? 1 : 0)")
    }
    static func act(_ v: String, arg: String, tab: String, qt: String) async throws -> [String: Any] {
        try await call("POST", "/c/act", ["v": v, "arg": arg, "tab": tab, "qt": qt])
    }
    static func pair() async throws -> (code: String, exp: Double) {
        let o = try await call("POST", "/c/pair", [:])
        return ((o["code"] as? String) ?? "", (o["exp"] as? NSNumber)?.doubleValue ?? 0)
    }
    static func state() async throws -> [String: Any] { try await call("GET", "/c/state") }
    static func unlink() async throws { _ = try await call("POST", "/c/unlink", [:]) }
    static func share(_ on: Bool) async { _ = try? await call("POST", "/c/share", ["on": on]) }
    /// 정확한 위치(부모에게 보이는 값). 응답 w = 실시간 보기 주기(1·2·3), nextSec 같은 값은 서버가 정한다.
    static func loc(la: Double, lo: Double, acc: Double, bt: Int, ch: Bool) async -> [String: Any]? {
        try? await call("POST", "/c/loc", ["la": la, "lo": lo, "acc": acc, "bt": bt, "ch": ch ? 1 : 0], timeout: 10)
    }
    /// 길동무 서버의 장면(날씨·친구들). 위치는 5km 칸으로 뭉개서 보낸다. 위치를 모르면 좌표를 아예 보내지 않는다.
    static func scene(lat: Double?, lng: Double?) async -> String? {
        var o: [String: Any] = ["nowMs": Int64(Date().timeIntervalSince1970 * 1000), "tzOffsetMin": TimeZone.current.secondsFromGMT() / 60, "locked": false, "routeShown": false, "key": "kids", "here": 0, "boarded": false, "nodes": [Any]()]
        if let a = lat, let b = lng { o["lat"] = (a * 20).rounded() / 20; o["lng"] = (b * 20).rounded() / 20 }
        guard let body = try? JSONSerialization.data(withJSONObject: o), let u = URL(string: Servers.base + "/scene") else { return nil }
        var r = URLRequest(url: u, timeoutInterval: 8); r.httpMethod = "POST"; r.httpBody = body; r.setValue("application/json", forHTTPHeaderField: "content-type")
        guard let (d, resp) = try? await URLSession.shared.data(for: r), (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return String(data: d, encoding: .utf8)
    }
}

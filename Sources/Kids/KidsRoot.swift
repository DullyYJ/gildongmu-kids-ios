import SwiftUI
import CoreImage.CIFilterBuiltins

/// 길동무 키즈 — 아래 탭: 가족대화 · 노선도 · 홈 · 퀘스트 · 설정. 부모 앱(길동무)과 같은 색(Palette)·글꼴(Typo)을 쓴다.
struct KidsRoot: View {
    @Environment(\.colorScheme) private var scheme
    @AppStorage("theme") private var theme = ""
    @AppStorage("kids.consent") private var consent = 0
    @StateObject private var store = KidsStore.shared
    @State private var tab = KidsRoot.startTab()
    private var pal: Palette { theme == "dark" ? .dark : theme == "light" ? .light : (scheme == .dark ? .dark : .light) }

    static func startTab() -> String {
        let a = CommandLine.arguments
        if let i = a.firstIndex(of: "-tab"), i + 1 < a.count, ["chat", "map", "home", "quest", "settings"].contains(a[i + 1]) { return a[i + 1] }
        return "home"
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                Group {
                    switch tab {
                    case "chat": KidsBlocksTab(pal: pal, tab: "chat")
                    case "quest": KidsBlocksTab(pal: pal, tab: "quest")
                    case "map": KidsMapTab(pal: pal)
                    case "settings": KidsSettingsTab(pal: pal)
                    default: KidsHomeTab(pal: pal)
                    }
                }
                if let n = store.notice {
                    Text(n).font(Typo.font(12)).foregroundColor(.white).padding(10).background(Color.black.opacity(0.8)).cornerRadius(10).padding(.bottom, 12).transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)        // 내용 칸이 화면을 다 채워야 탭바가 맨 아래에 붙는다
            tabBar
        }
        .background((pal.color("bg") ?? Color(.systemBackground)).ignoresSafeArea())
        .preferredColorScheme(theme == "dark" ? .dark : theme == "light" ? .light : nil)
        .fullScreenCover(isPresented: Binding(get: { consent < 2 }, set: { _ in })) { KidsConsent(pal: pal, done: { consent = 2; Task { await KidsConsent.report() }; KidsLocation.shared.sync() }) }
        .onAppear { KidsLocation.shared.sync() }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach([("chat", "가족대화", "bubble.left.and.bubble.right"), ("map", "노선도", "map"), ("home", "홈", "house.fill"), ("quest", "퀘스트", "flag.fill"), ("settings", "설정", "gearshape")], id: \.0) { t in
                Button { tab = t.0 } label: {
                    VStack(spacing: 3) {
                        Image(systemName: t.2).font(.system(size: 19))
                        Text(t.1).font(Typo.font(10.5, bold: tab == t.0))
                    }
                    .foregroundColor(tab == t.0 ? pal.color("gold") : pal.color("sub"))
                    .frame(maxWidth: .infinity).frame(height: 48)
                }.buttonStyle(.plain)
            }
        }
        .background((pal.color("nav") ?? .white).ignoresSafeArea(edges: .bottom))
        .overlay(Rectangle().fill(pal.color("border") ?? .gray).frame(height: 0.5), alignment: .top)
    }
}

/// 가족대화 · 퀘스트: 서버가 준 blocks 를 그대로 그린다(긴 대기로 실시간).
struct KidsBlocksTab: View {
    let pal: Palette
    let tab: String
    @ObservedObject private var store = KidsStore.shared
    var body: some View {
        let scr: [String: Any]? = tab == "chat" ? store.chat : (store.qt == "p" ? store.questP : store.questC)
        ZStack {
            if let s = scr {
                KidsBlocksView(screen: s, pal: pal) { act, arg in
                    if act.hasPrefix("quest.tab:") { store.qt = String(act.dropFirst(10)); return }     // 칸 바꾸기는 화면 안에서만
                    Task { await store.act(act, arg: arg) }
                }
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    if store.offline { Text("서버에 닿지 못했어요 · \(store.lastErr)").font(Typo.font(11)).foregroundColor(pal.color("sub")).multilineTextAlignment(.center).padding(.horizontal, 24) }
                }
            }
            if store.offline && scr != nil { VStack { Text("서버에 닿지 못해 마지막 화면이에요").font(Typo.font(11)).foregroundColor(.white).padding(6).background(Color.black.opacity(0.7)).cornerRadius(8); Spacer() } .padding(.top, 6) }
        }
        .onAppear { store.watch(tab) }
        .onDisappear { store.stop() }
    }
}

/// 노선도 — 길동무와 같은 지도 화면을 붙일 자리(다음 단계).
struct KidsMapTab: View {
    let pal: Palette
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "map").font(.system(size: 34)).foregroundColor(pal.color("sub"))
            Text("노선도는 다음 단계에서 연결돼요").font(Typo.font(13)).foregroundColor(pal.color("sub"))
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 처음 켰을 때 올라오는 동의 창(안드로이드 키즈 Engine.consentScreen 과 같은 글). 부모님과 아이가 둘 다 확인해야 시작한다.
struct KidsConsent: View {
    let pal: Palette
    let done: () -> Void
    @State private var parent = false
    @State private var child = false
    static func report() async { _ = try? await KidsServer.call("POST", "/c/consent", ["v": 2]) }
    private let cards: [(String, String)] = [
        ("알리는 것", "내 휴대폰의 위치와 알린 시각, 배터리 잔량이에요. 평소에는 몇 분마다 알리고, 부모님이 지도를 보는 동안에는 몇 초마다 알려요. 이때는 맨 위 줄과 알림에 '부모님이 지금 내 위치를 보고 있어요'라고 보여요."),
        ("앱을 닫아도 계속돼요", "내가 위치 공유를 켜 두면, 앱을 닫거나 화면을 꺼도 '부모님께 내 위치 알리기'와 '집·학교 도착·출발 알림'을 위해 위치를 계속 사용해요. 위치를 쓰는 동안 상태 표시줄에 표시가 보여요."),
        ("누가 쓸 수 있나요", "만 9살 이상 어린이가 쓸 수 있어요. 부모님(법정대리인)과 함께 읽고 정해요."),
        ("누가 보나요", "내가 QR이나 비밀키로 연결한 부모님만 볼 수 있어요."),
        ("언제든 끌 수 있어요", "설정에서 위치 공유를 끄거나 동의를 거둘 수 있어요."),
        ("보관", "위치 기록은 3일, 지난 길은 7일, 오래 머문 곳은 30일 뒤에 지워져요. 연결을 끊으면 바로 모두 지워져요."),
    ]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("시작하기 전에 읽어 주세요").font(Typo.font(17, bold: true)).foregroundColor(pal.color("text"))
                Text("길동무 키즈는 부모님께 내 위치를 알려 주는 앱이에요. 길동무 친구들과 놀면서 지내요.").font(Typo.font(13)).foregroundColor(pal.color("text"))
                ForEach(cards, id: \.0) { c in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(c.0).font(Typo.font(13, bold: true)).foregroundColor(pal.color("text"))
                        Text(c.1).font(Typo.font(11.5)).foregroundColor(pal.color("sub"))
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(pal.color("card") ?? .white))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(pal.color("border") ?? .gray, lineWidth: 1))
                }
                HStack(spacing: 10) {
                    Link("개인정보 처리방침 보기", destination: URL(string: Servers.kids + "/legal/privacy")!)
                    Link("이용약관 보기", destination: URL(string: Servers.kids + "/legal/terms")!)
                }.font(Typo.font(12.5, bold: true)).foregroundColor(pal.color("gold"))
                Toggle("보호자(부모님)가 위 내용을 확인하고 동의했어요", isOn: $parent).font(Typo.font(13))
                Toggle("나도 위 내용을 이해했고 동의해요", isOn: $child).font(Typo.font(13))
                Button { done() } label: {
                    Text("시작하기").font(Typo.font(14, bold: true)).foregroundColor(pal.color("ongold")).frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Capsule().fill((parent && child) ? (pal.color("gold") ?? .blue) : (pal.color("card2") ?? .gray.opacity(0.3))))
                }.buttonStyle(.plain).disabled(!(parent && child))
            }.padding(16)
        }
        .background((pal.color("bg") ?? Color(.systemBackground)).ignoresSafeArea())
    }
}

/// 홈 — 맨 위 응원 문구 · 별(길동무포인트) · 연결 상태 · 길동무 친구들 장면(길동무 서버가 정한 장면·날씨).
struct KidsHomeTab: View {
    let pal: Palette
    @ObservedObject private var store = KidsStore.shared
    @ObservedObject private var d = SceneDriver.shared
    @State private var sceneJSON = ""
    @State private var sceneErr = ""
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let c = store.cheers.first {
                    Text(c).font(Typo.font(12.5, bold: true)).foregroundColor(pal.color("gold2")).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 8) {
                    pill(store.linked > 0 ? "부모님 \(store.linked)명과 연결됐어요" : "아직 연결된 부모님이 없어요", store.linked > 0)
                    pill("⭐ \(store.stars)", false)
                    Spacer()
                }
                scene(h: 220, r: 14)
                if sceneJSON.isEmpty && !sceneErr.isEmpty { Text("장면을 못 받았어요 · \(sceneErr)").font(Typo.font(11)).foregroundColor(pal.color("sub")).frame(maxWidth: .infinity, alignment: .leading) }
                if CommandLine.arguments.contains("-kidsDemo") {      // CI 화면 확인용 진단 줄(시험 실행에서만 보인다)
                    Text("진단 · 준비 \(d.isReady ? "예" : "아니오") · 실행 \(d.isRunning() ? "예" : "아니오") · 받은 글자 \(sceneJSON.count) · \(sceneJSON.prefix(420))").font(.system(size: 9)).foregroundColor(.gray).frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("길동무 친구들이 오늘도 돌아다니고 있어요. 3초 꾹 누르면 친구들이 인사해요.").font(Typo.font(11)).foregroundColor(pal.color("sub")).frame(maxWidth: .infinity, alignment: .leading)
            }.padding(14)
        }
        .task { await refreshLoop() }
    }
    private func pill(_ t: String, _ lit: Bool) -> some View {
        Text(t).font(Typo.font(11.5, bold: true)).foregroundColor(lit ? pal.color("ongold") : pal.color("text"))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(lit ? (pal.color("gold") ?? .blue) : (pal.color("card2") ?? .gray.opacity(0.2))))
    }
    @ViewBuilder private func scene(h: CGFloat, r: CGFloat) -> some View {
        if d.helloOn {
            TimelineView(.animation) { _ in card(h, r, CGFloat(d.helloExtNow())) }
        } else { card(h, r, 0) }
    }
    private func card(_ h: CGFloat, _ r: CGFloat, _ ext: CGFloat) -> some View {
        SceneView(json: sceneJSON, baseH: h)
            .frame(height: h * (1 + ext))
            .background(RoundedRectangle(cornerRadius: r, style: .continuous).fill(pal.color("card2") ?? .gray.opacity(0.2)))
            .clipShape(RoundedRectangle(cornerRadius: r, style: .continuous))
    }
    /// 장면은 10분마다 새로 받는다(날씨가 바뀌므로). 상태(연결 수 · 별 · 응원)는 30초마다.
    private func refreshLoop() async {
        KidsLocation.shared.once()
        var n = 0
        while !Task.isCancelled {
            if n % 20 == 0 {
                let l = KidsLocation.shared.last?.coordinate
                let r = await KidsServer.scene(lat: l?.latitude, lng: l?.longitude)
                if let s = r.json { sceneJSON = s; sceneErr = "" } else { sceneErr = r.err }
            }
            await store.refreshState()
            n += 1
            try? await Task.sleep(nanoseconds: 30_000_000_000)
        }
    }
}

/// 설정 — 부모 연결(비밀키 · QR) · 위치 공유 · 화면 색 · 약관 · 연결 끊기 · 동의 철회.
struct KidsSettingsTab: View {
    let pal: Palette
    @ObservedObject private var store = KidsStore.shared
    @ObservedObject private var loc = KidsLocation.shared
    @AppStorage("theme") private var theme = ""
    @AppStorage("kids.share") private var share = true
    @AppStorage("kids.consent") private var consent = 0
    @State private var code = ""
    @State private var expAt = Date()
    @State private var asking = false
    @State private var confirmUnlink = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                section("부모님 연결") {
                    Text(store.linked > 0 ? "부모님 \(store.linked)명과 연결돼 있어요." : "길동무 앱에서 아래 QR이나 비밀키를 넣으면 부모님이 내 위치를 볼 수 있어요.").font(Typo.font(12.5)).foregroundColor(pal.color("text"))
                    if !code.isEmpty {
                        if let qr = qrImage("gildongmu-kids://pair?c=\(KidsServer.id)&k=\(code)") { Image(uiImage: qr).interpolation(.none).resizable().scaledToFit().frame(width: 170, height: 170).frame(maxWidth: .infinity) }
                        Text(code).font(.system(size: 24, weight: .bold, design: .monospaced)).foregroundColor(pal.color("text")).frame(maxWidth: .infinity)
                        Text("10분 동안만 쓸 수 있어요").font(Typo.font(11)).foregroundColor(pal.color("sub")).frame(maxWidth: .infinity)
                    }
                    button(asking ? "만드는 중…" : (code.isEmpty ? "연결 비밀키 만들기" : "새 비밀키 만들기")) { Task { await makeCode() } }
                    if store.linked > 0 { button("연결 모두 끊기", warn: true) { confirmUnlink = true } }
                }
                section("위치 공유") {
                    Toggle(isOn: Binding(get: { share }, set: { v in share = v; KidsLocation.shared.sync(); Task { await KidsServer.share(v) } })) {
                        Text("부모님께 내 위치 알리기").font(Typo.font(13))
                    }
                    if loc.denied { Text("위치 권한이 꺼져 있어요. 설정 앱에서 길동무 키즈의 위치를 ‘항상’으로 바꿔 주세요.").font(Typo.font(11)).foregroundColor(pal.color("orange")) }
                    Text("끄면 부모님께 알려지고, 그동안은 위치를 보내지 않아요.").font(Typo.font(11)).foregroundColor(pal.color("sub"))
                }
                section("화면") {
                    Picker("", selection: $theme) { Text("기기 설정").tag(""); Text("밝게").tag("light"); Text("어둡게").tag("dark") }.pickerStyle(.segmented)
                }
                section("약관") {
                    Link("개인정보 처리방침", destination: URL(string: Servers.kids + "/legal/privacy")!)
                    Link("위치기반서비스 이용약관", destination: URL(string: Servers.kids + "/legal/terms")!)
                    button("동의 철회하고 처음으로", warn: true) { consent = 0; KidsLocation.shared.sync() }
                }
            }.padding(14)
        }
        .alert("연결을 모두 끊을까요?", isPresented: $confirmUnlink) {
            Button("끊기", role: .destructive) { Task { try? await KidsServer.unlink(); await store.refreshState(); code = "" } }
            Button("취소", role: .cancel) {}
        } message: { Text("부모님이 더는 내 위치를 볼 수 없고, 서버의 위치 기록은 바로 지워져요.") }
    }
    private func makeCode() async {
        asking = true; defer { asking = false }
        do { let r = try await KidsServer.pair(); code = r.code; expAt = Date().addingTimeInterval(600) }
        catch { store.say(error.localizedDescription) }
    }
    private func section<C: View>(_ title: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(Typo.font(13, bold: true)).foregroundColor(pal.color("text"))
            c()
        }
        .font(Typo.font(12.5)).tint(pal.color("gold"))
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(pal.color("card") ?? .white))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(pal.color("border") ?? .gray, lineWidth: 1))
    }
    private func button(_ t: String, warn: Bool = false, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(t).font(Typo.font(13, bold: true)).foregroundColor(warn ? pal.color("orange") : pal.color("ongold")).frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(Capsule().fill(warn ? (pal.color("card2") ?? .gray.opacity(0.2)) : (pal.color("gold") ?? .blue)))
        }.buttonStyle(.plain)
    }
    private func qrImage(_ s: String) -> UIImage? {
        let f = CIFilter.qrCodeGenerator(); f.message = Data(s.utf8); f.correctionLevel = "M"
        guard let o = f.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)), let cg = CIContext().createCGImage(o, from: o.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

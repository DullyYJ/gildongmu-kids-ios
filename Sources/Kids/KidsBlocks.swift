import SwiftUI

/// 키즈 서버 화면(blocks) 그림판. 블록 종류는 서버가 정한 열 가지뿐 — head · text · box · card · msg · input · stars · chips · btns · i.
/// 글 · 순서 · 강조(on · tone · un)는 모두 서버가 정했고, 앱은 그대로 그린다.
struct KidsBlocksView: View {
    let screen: [String: Any]
    let pal: Palette
    /// (행동 이름, 입력한 글) — 눌림은 arg 가 빈 글.
    let onAct: (String, String) -> Void
    @State private var draft = ""

    private var blocks: [[String: Any]] { screen["blocks"] as? [[String: Any]] ?? [] }
    private func firstInput(_ bl: [[String: Any]]) -> [String: Any]? {
        for b in bl {
            if (b["t"] as? String) == "input" { return b }
            if let k = b["kids"] as? [[String: Any]], let f = firstInput(k) { return f }
        }
        return nil
    }

    var body: some View {
        let bottom = (screen["bottom"] as? String) == "1"
        let input = firstInput(blocks)
        VStack(spacing: 0) {
            ScrollViewReader { sp in
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(Array(blocks.enumerated()), id: \.offset) { _, b in block(b, skipInput: input != nil && bottom) }
                        Color.clear.frame(height: 1).id("end")
                    }.padding(.horizontal, 14).padding(.vertical, 10)
                }
                .onAppear { if bottom { sp.scrollTo("end", anchor: .bottom) } }
                .onChange(of: blocks.count) { _ in if bottom { withAnimation { sp.scrollTo("end", anchor: .bottom) } } }
            }
            if let inp = input, bottom { inputBar(inp).padding(.horizontal, 14).padding(.bottom, 8) }
        }
    }

    private func s(_ b: [String: Any], _ k: String) -> String { (b[k] as? String) ?? "" }
    private func on(_ b: [String: Any], _ k: String = "on") -> Bool { (b[k] as? String) == "1" || (b[k] as? NSNumber)?.boolValue == true }

    @ViewBuilder private func block(_ b: [String: Any], skipInput: Bool) -> some View {
        switch s(b, "t") {
        case "head":
            Text(s(b, "text")).font(Typo.font(17, bold: true)).foregroundColor(pal.color("text")).frame(maxWidth: .infinity, alignment: .leading)
        case "text":
            Text(s(b, "text")).font(Typo.font(on(b, "sub") ? 11 : 13)).foregroundColor(pal.color(on(b, "sub") ? "sub" : "text")).frame(maxWidth: .infinity, alignment: .leading)
        case "box":
            VStack(spacing: on(b, "flush") ? 6 : 10) {
                ForEach(Array((b["kids"] as? [[String: Any]] ?? []).enumerated()), id: \.offset) { _, k in block(k, skipInput: skipInput) }
            }
            .padding(on(b, "flush") ? 0 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        case "card":
            card(b)
        case "msg":
            msg(b)
        case "input":
            if !skipInput { inputBar(b) }
        case "stars":
            stars(b)
        case "chips":
            HStack(spacing: 8) {
                ForEach(Array((b["items"] as? [[String: Any]] ?? []).enumerated()), id: \.offset) { _, it in chip(it) }
            }
        case "btns":
            HStack(spacing: 8) {
                ForEach(Array((b["items"] as? [[String: Any]] ?? []).enumerated()), id: \.offset) { _, it in chip(it) }
            }
        case "i":
            chip(b)
        default:
            EmptyView()
        }
    }

    private func card(_ b: [String: Any]) -> some View {
        let tone = on(b, "tone")
        return VStack(alignment: .leading, spacing: 4) {
            if !s(b, "title").isEmpty { Text(s(b, "title")).font(Typo.font(13, bold: true)).foregroundColor(pal.color("text")) }
            if !s(b, "text").isEmpty { Text(s(b, "text")).font(Typo.font(11.5)).foregroundColor(pal.color(tone ? "gold2" : "sub")) }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(pal.color("card") ?? .white))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(pal.color(tone ? "gold" : "border") ?? .gray, lineWidth: 1))
    }

    private func msg(_ b: [String: Any]) -> some View {
        let me = on(b, "me")
        return HStack(alignment: .bottom, spacing: 5) {
            if me { Spacer(minLength: 40) }
            if me && on(b, "un") { Text("1").font(Typo.font(10, bold: true)).foregroundColor(pal.color("gold")) }
            VStack(alignment: me ? .trailing : .leading, spacing: 2) {
                Text(s(b, "text")).font(Typo.font(13)).foregroundColor(me ? pal.color("ongold") : pal.color("text"))
                    .padding(.horizontal, 11).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 14).fill(me ? (pal.color("gold") ?? .blue) : (pal.color("card2") ?? .gray.opacity(0.2))))
                Text(s(b, "time")).font(Typo.font(9.5)).foregroundColor(pal.color("sub"))
            }
            if !me { Spacer(minLength: 40) }
        }
    }

    private func stars(_ b: [String: Any]) -> some View {
        let n = (b["n"] as? NSNumber)?.intValue ?? 0
        return HStack {
            Text("⭐").font(.system(size: 20))
            VStack(alignment: .leading, spacing: 1) {
                Text("\(s(b, "label")) \(n)").font(Typo.font(14, bold: true)).foregroundColor(pal.color("text"))
                if !s(b, "sub").isEmpty { Text(s(b, "sub")).font(Typo.font(11)).foregroundColor(pal.color("gold2")) }
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(pal.color("card") ?? .white))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(pal.color("border") ?? .gray, lineWidth: 1))
    }

    private func chip(_ it: [String: Any]) -> some View {
        let lit = on(it)
        return Button { onAct(s(it, "act"), "") } label: {
            Text(s(it, "label")).font(Typo.font(12.5, bold: true))
                .foregroundColor(lit ? pal.color("ongold") : pal.color("sub"))
                .frame(maxWidth: .infinity).padding(.vertical, 9)
                .background(Capsule().fill(lit ? (pal.color("gold") ?? .blue) : (pal.color("card2") ?? .gray.opacity(0.2))))
        }.buttonStyle(.plain)
    }

    private func inputBar(_ b: [String: Any]) -> some View {
        HStack(spacing: 8) {
            TextField(s(b, "hint"), text: $draft, axis: .vertical).lineLimit(1...3).font(Typo.font(13))
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 16).fill(pal.color("card2") ?? .gray.opacity(0.2)))
            Button {
                let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return }
                onAct(s(b, "act"), t); draft = ""
            } label: {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 30)).foregroundColor(pal.color("gold"))
            }.buttonStyle(.plain)
        }
    }
}

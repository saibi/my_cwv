import Foundation

// 순수 로직. Foundation만 쓴다 (macOS에서 시뮬레이터 없이 테스트하기 위해). @main을 두지 않는다.

struct Site: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var url: URL
    var zoom: Double = 1.0
}

let zoomRange = 0.5...3.0

func clampZoom(_ z: Double) -> Double {
    (min(max(z, zoomRange.lowerBound), zoomRange.upperBound) * 10).rounded() / 10
}

/// 입력 문자열을 http/https URL로 정규화한다. 허용되지 않으면 nil.
func normalizeURL(_ input: String) -> URL? {
    let s = input.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.isEmpty { return nil }
    let full = s.contains("://") ? s : "https://" + s
    guard var c = URLComponents(string: full),
          let scheme = c.scheme?.lowercased(), scheme == "http" || scheme == "https",
          let host = c.host, !host.isEmpty else { return nil }
    c.scheme = scheme
    return c.url
}

private func bareHost(_ url: URL) -> String {
    let h = (url.host ?? "").lowercased()
    return h.hasPrefix("www.") ? String(h.dropFirst(4)) : h
}

/// base 사이트 기준으로 url이 다른 도메인인가. 같은 host, 하위 도메인, www 차이는 내부로 본다.
func isExternal(_ url: URL, base: URL) -> Bool {
    let h = bareHost(url), b = bareHost(base)
    return !(h == b || h.hasSuffix("." + b))
}

func defaultSites() -> [Site] {
    [Site(name: "다모앙 공감", url: URL(string: "https://damoang.net/empathy")!)]
}

/// 사용자가 직접 누른 외부 도메인 링크만 Safari 시트로 보낸다 (리다이렉트, 로그인 흐름 제외).
func opensInSafariSheet(_ url: URL, base: URL, linkActivated: Bool) -> Bool {
    linkActivated && isExternal(url, base: base)
}

/// 플로팅 버튼이 붙는 모서리.
enum FabCorner: String {
    case topLeading, topTrailing, bottomLeading, bottomTrailing

    /// 화면 크기 size 안의 점 p에서 가장 가까운 모서리 (화면 중심 기준 사분면).
    static func nearest(to p: CGPoint, in size: CGSize) -> FabCorner {
        let top = p.y < size.height / 2, leading = p.x < size.width / 2
        switch (top, leading) {
        case (true, true): return .topLeading
        case (true, false): return .topTrailing
        case (false, true): return .bottomLeading
        case (false, false): return .bottomTrailing
        }
    }
}

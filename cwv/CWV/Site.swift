import Foundation

// 순수 로직. Foundation만 쓴다 (macOS에서 시뮬레이터 없이 테스트하기 위해). @main을 두지 않는다.

struct Site: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var url: URL
    var zoom: Double = 1.0
}

extension Site {
    /// 목록에 보이는 이름: 직접 정한 이름(CSV 제목 포함) > 저장해 둔 페이지 타이틀 > 도메인.
    func displayName(cached: String?) -> String {
        let n = name.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? (cached ?? url.host ?? url.absoluteString) : n
    }
}

/// 페이지 타이틀로 쓸 수 있는 문자열. 비었거나 Cloudflare 확인 화면 제목이면 nil.
func usableTitle(_ raw: String?) -> String? {
    guard let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty,
          !t.lowercased().hasPrefix("just a moment"), !t.lowercased().hasPrefix("attention required") else { return nil }
    return t
}

/// 첫 페이지의 왼쪽 가장자리 스와이프를 "목록으로"로 볼 기준 (충분히 이동했거나 빠르게 밀었을 때).
func shouldCloseOnEdgeSwipe(translation: Double, velocity: Double) -> Bool {
    translation > 80 || velocity > 500
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

/// 기본 페이지 파일이 없거나 유효한 줄이 없을 때 쓰는 항상 접속 가능한 사이트.
func fallbackSites() -> [Site] {
    let u = URL(string: "https://www.google.com")!
    return [Site(id: stableID(for: u), name: "Google", url: u)]
}

/// 주소에서 만든 고정 UUID (FNV-1a 64비트 두 개). 기본 페이지를 매 실행 새로 읽어도 글자 크기 등이 같은 사이트에 붙는다.
func stableID(for url: URL) -> UUID {
    func fnv(_ seed: UInt64) -> UInt64 {
        url.absoluteString.utf8.reduce(seed) { ($0 ^ UInt64($1)) &* 0x100000001b3 }
    }
    let a = fnv(0xcbf29ce484222325), b = fnv(0x84222325cbf29ce4)
    var bytes = [UInt8](repeating: 0, count: 16)
    for i in 0..<8 { bytes[i] = UInt8(truncatingIfNeeded: a >> (8 * UInt64(i))); bytes[8 + i] = UInt8(truncatingIfNeeded: b >> (8 * UInt64(i))) }
    return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                       bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
}

/// CSV의 데이터 줄: 앞뒤 공백을 지우고 빈 줄과 `#` 주석 줄은 뺀다.
private func csvDataLines(_ text: String) -> [String] {
    text.replacingOccurrences(of: "\u{FEFF}", with: "").split(whereSeparator: \.isNewline)
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty && !$0.hasPrefix("#") }
}

/// 한 줄에 `주소[,제목]`, 첫 쉼표 앞이 주소(주소에는 쉼표를 쓸 수 없다). 제목이 없으면 name은 빈 문자열
/// (표시할 때 페이지 타이틀, 없으면 도메인). 잘못된 주소와 중복 주소는 건너뛴다.
private func parseSites(_ lines: [String]) -> [Site] {
    var seen = Set<UUID>()
    return lines.compactMap { line in
        let parts = line.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
        guard let url = normalizeURL(String(parts[0])) else { return nil }
        let id = stableID(for: url)
        guard seen.insert(id).inserted else { return nil }
        let title = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
        return Site(id: id, name: title, url: url)
    }
}

/// default_page.csv 해석 (앱 첫 실행과 초기화에 쓰는 기본 목록).
func parseDefaultPages(_ text: String) -> [Site] { parseSites(csvDataLines(text)) }

/// 목록을 CSV로 (default_page.csv와 같은 형식, 글자 크기는 넣지 않는다). 이름이 비어 있으면 주소만 쓴다.
/// 주소의 쉼표는 %2C로 바꿔 첫 쉼표 규칙이 깨지지 않게 하고, 이름의 줄바꿈은 공백으로 바꾼다.
func exportCSV(_ sites: [Site]) -> String {
    let lines = sites.map { s -> String in
        let u = s.url.absoluteString.replacingOccurrences(of: ",", with: "%2C")
        let n = s.name.components(separatedBy: .newlines).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? u : "\(u),\(n)"
    }
    return (["# CWV site list: one line per site, url[,name]"] + lines).joined(separator: "\n") + "\n"
}

enum CSVImportError: Error, Equatable { case tooLarge, notUTF8, tooManyLines, noValidLines }

struct CSVImport {
    var sites: [Site]
    var skipped: Int  // 잘못된 주소나 중복이라 건너뛴 줄 수
}

let csvImportMaxBytes = 1_000_000
let csvImportMaxLines = 500

/// 가져온 CSV 파일 검사와 해석. 외부 파일이므로 크기/줄 수 제한을 두고, 각 줄은 normalizeURL로 검증한다.
func importCSV(_ data: Data) -> Result<CSVImport, CSVImportError> {
    guard data.count <= csvImportMaxBytes else { return .failure(.tooLarge) }
    guard let text = String(data: data, encoding: .utf8) else { return .failure(.notUTF8) }
    let lines = csvDataLines(text)
    guard lines.count <= csvImportMaxLines else { return .failure(.tooManyLines) }
    let sites = parseSites(lines)
    guard !sites.isEmpty else { return .failure(.noValidLines) }
    return .success(CSVImport(sites: sites, skipped: lines.count - sites.count))
}

/// Safari로 열 주소: 지금 보는 페이지가 http/https면 그것, 아니면 사이트 기본 주소.
func safariTarget(current: URL?, fallback: URL) -> URL {
    if let c = current, let scheme = c.scheme?.lowercased(), scheme == "http" || scheme == "https" { return c }
    return fallback
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

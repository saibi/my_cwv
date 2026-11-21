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

/// 앱을 처음 설치했을 때의 기본 확대% (옵션에서 바꾼다).
let initialDefaultZoom = 1.2

/// CSV의 확대% 토큰("120" 또는 "120%") -> 배율(1.2). 숫자가 아니면 nil. 범위 밖이면 clampZoom으로 맞춘다.
func parseZoomToken(_ raw: String) -> Double? {
    var t = raw.trimmingCharacters(in: .whitespaces)
    if t.hasSuffix("%") { t.removeLast(); t = t.trimmingCharacters(in: .whitespaces) }
    guard !t.isEmpty, t.allSatisfy({ $0.isNumber && $0.isASCII || $0 == "." }), let v = Double(t) else { return nil }
    return clampZoom(v / 100)
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
func fallbackSites(defaultZoom: Double = 1.0) -> [Site] {
    let u = URL(string: "https://www.google.com")!
    return [Site(id: stableID(for: u), name: "Google", url: u, zoom: clampZoom(defaultZoom))]
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

/// 한 줄을 (주소 문자열, 제목)으로 나눈다. 주소가 따옴표로 시작하면 닫는 따옴표까지가 주소(안의 ""는 "), 아니면 첫 쉼표 앞이 주소.
/// 따옴표가 닫히지 않았거나 닫은 뒤 쉼표 말고 다른 글자가 오면 nil.
private func splitLine(_ line: String) -> (url: String, title: String)? {
    guard line.hasPrefix("\"") else {
        let parts = line.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
        return (String(parts[0]), parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : "")
    }
    var url = "", i = line.index(after: line.startIndex)
    while i < line.endIndex {
        if line[i] == "\"" {
            let next = line.index(after: i)
            if next < line.endIndex, line[next] == "\"" { url.append("\""); i = line.index(after: next); continue }
            let rest = line[next...].trimmingCharacters(in: .whitespaces)
            if rest.isEmpty { return (url, "") }
            guard rest.hasPrefix(",") else { return nil }
            return (url, String(rest.dropFirst()).trimmingCharacters(in: .whitespaces))
        }
        url.append(line[i])
        i = line.index(after: i)
    }
    return nil
}

/// CSV 형식 버전. 첫 줄이 `# v2` 같은 주석이면 그 번호, 없으면 1 (v1: `주소[,이름]`, v2: `주소,"이름",확대%`).
let csvCurrentVersion = 2

func csvVersion(_ text: String) -> Int {
    guard let first = text.replacingOccurrences(of: "\u{FEFF}", with: "").split(whereSeparator: \.isNewline).first?.trimmingCharacters(in: .whitespaces),
          first.hasPrefix("#") else { return 1 }
    let t = first.dropFirst().trimmingCharacters(in: .whitespaces).lowercased()
    guard t.hasPrefix("v"), let n = Int(t.dropFirst()), n >= 1 else { return 1 }
    return n
}

/// v2 이름 칸의 이스케이프: `\\` -> `\`, `\"` -> `"`. 그 밖의 `\x`는 글자 그대로 둔다.
private func csvEscape(_ s: String) -> String {
    s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
}

/// v2: 주소 뒤의 나머지 `"이름"[,확대%]`를 (이름, 확대%)로 나눈다. 따옴표가 닫히지 않았거나 닫은 뒤 쉼표 말고 다른 글자가 오면 nil(그 줄은 건너뜀).
/// 따옴표 없이 손으로 쓴 `이름[,확대%]`도 받아 준다 (마지막 쉼표 뒤가 숫자면 확대%).
private func splitNameZoomV2(_ rest: String) -> (name: String, zoom: Double?)? {
    guard rest.hasPrefix("\"") else {
        guard let comma = rest.lastIndex(of: ","), let z = parseZoomToken(String(rest[rest.index(after: comma)...])) else { return (rest, nil) }
        return (rest[..<comma].trimmingCharacters(in: .whitespaces), z)
    }
    var name = "", i = rest.index(after: rest.startIndex)
    while i < rest.endIndex {
        let c = rest[i]
        if c == "\\", case let n = rest.index(after: i), n < rest.endIndex, rest[n] == "\"" || rest[n] == "\\" {
            name.append(rest[n]); i = rest.index(after: n); continue
        }
        if c == "\"" {
            let tail = rest[rest.index(after: i)...].trimmingCharacters(in: .whitespaces)
            if tail.isEmpty { return (name.trimmingCharacters(in: .whitespaces), nil) }
            guard tail.hasPrefix(",") else { return nil }
            return (name.trimmingCharacters(in: .whitespaces), parseZoomToken(String(tail.dropFirst())))
        }
        name.append(c); i = rest.index(after: i)
    }
    return nil
}

/// v1은 한 줄에 `주소[,이름]`(첫 쉼표 뒤가 모두 이름, 확대%는 없음), v2는 `주소,"이름",확대%`. 이름이 없으면 name은 빈 문자열(표시할 때 페이지 타이틀, 없으면 도메인). 확대%가 없으면 defaultZoom.
/// 잘못된 줄은 건너뛴다.
/// keepDuplicates가 false(기본 목록)면 같은 주소는 첫 줄만 남긴다. true(백업 복원)면 주소가 같아도 이름이 다르면 모두 남기고
/// (주소, 이름, 확대%가 모두 같은 줄만 제거) 같은 주소의 두 번째 항목부터는 새 id를 준다.
private func parseSites(_ lines: [String], version: Int, keepDuplicates: Bool = false, defaultZoom: Double) -> [Site] {
    var seenIDs = Set<UUID>(), seenPairs = Set<String>()
    return lines.compactMap { line in
        guard let (urlText, rest) = splitLine(line), let url = normalizeURL(urlText) else { return nil }
        guard let (name, zoom) = version >= 2 ? splitNameZoomV2(rest) : (rest, nil) else { return nil }
        var id = stableID(for: url)
        if keepDuplicates {
            guard seenPairs.insert(url.absoluteString + "\u{0}" + name + "\u{0}" + String(zoom ?? clampZoom(defaultZoom))).inserted else { return nil }
            if !seenIDs.insert(id).inserted { id = UUID() }
        } else {
            guard seenIDs.insert(id).inserted else { return nil }
        }
        return Site(id: id, name: name, url: url, zoom: zoom ?? clampZoom(defaultZoom))
    }
}

/// default_page.csv 해석 (앱 첫 실행과 초기화에 쓰는 기본 목록). 확대%를 쓰려면 첫 줄에 `# v2`가 있어야 한다. 확대%가 없는 줄은 defaultZoom.
func parseDefaultPages(_ text: String, defaultZoom: Double = 1.0) -> [Site] { parseSites(csvDataLines(text), version: csvVersion(text), defaultZoom: defaultZoom) }

/// 목록을 CSV(v2)로: 첫 줄 `# v2`, 한 줄에 `주소,"이름",확대%` (이름은 항상 큰따옴표로 감싸고 안의 `\` `"`는 `\`로 이스케이프). 이름이 비어 있으면 titles(사이트 id -> 저장해 둔 페이지 타이틀)의 값을 쓰고, 그것도 없으면 빈 칸.
/// 주소에 쉼표나 따옴표가 있으면 주소를 따옴표로 감싸고(안의 따옴표는 두 개) 손실 없이 보존한다. 이름의 줄바꿈은 공백으로 바꾼다.
func exportCSV(_ sites: [Site], titles: [String: String] = [:]) -> String {
    let lines = sites.map { s -> String in
        var u = s.url.absoluteString
        if u.contains(",") || u.contains("\"") { u = "\"" + u.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        var n = s.name.trimmingCharacters(in: .whitespaces)
        if n.isEmpty { n = titles[s.id.uuidString] ?? "" }
        n = n.components(separatedBy: .newlines).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return "\(u),\"\(csvEscape(n))\",\(Int((s.zoom * 100).rounded()))"
    }
    return (["# v\(csvCurrentVersion)", "# CWV site list: one line per site, url,\"name\",zoom%"] + lines).joined(separator: "\n") + "\n"
}

enum CSVImportError: Error, Equatable { case tooLarge, notUTF8, tooManyLines, noValidLines }

struct CSVImport {
    var sites: [Site]
    var skipped: Int  // 잘못된 주소나 중복이라 건너뛴 줄 수
}

let csvImportMaxBytes = 1_000_000
let csvImportMaxLines = 500

/// 내보내기 전 검사: 가져오기 제한(크기/줄 수)을 넘는 파일은 만들지 않는다. 백업해 놓고 복원할 수 없는 일을 막는다.
func exportCSVChecked(_ sites: [Site], titles: [String: String] = [:]) -> Result<String, CSVImportError> {
    guard sites.count <= csvImportMaxLines else { return .failure(.tooManyLines) }
    let text = exportCSV(sites, titles: titles)
    return text.utf8.count <= csvImportMaxBytes ? .success(text) : .failure(.tooLarge)
}

/// 파일을 최대 csvImportMaxBytes+1바이트까지만 읽는다 (크기 정보가 없거나 읽는 중 커져도 메모리를 제한).
/// 상한을 넘으면 csvImportMaxBytes+1바이트가 돌아오고 importCSV가 tooLarge로 거부한다.
func readLimited(_ url: URL) -> Data? {
    guard let h = try? FileHandle(forReadingFrom: url) else { return nil }
    defer { try? h.close() }
    return try? h.read(upToCount: csvImportMaxBytes + 1) ?? Data()
}

/// 가져온 CSV 파일 검사와 해석. 외부 파일이므로 크기/줄 수 제한을 두고, 각 줄은 normalizeURL로 검증한다.
func importCSV(_ data: Data, defaultZoom: Double = 1.0) -> Result<CSVImport, CSVImportError> {
    guard data.count <= csvImportMaxBytes else { return .failure(.tooLarge) }
    guard let text = String(data: data, encoding: .utf8) else { return .failure(.notUTF8) }
    let lines = csvDataLines(text)
    guard lines.count <= csvImportMaxLines else { return .failure(.tooManyLines) }
    let sites = parseSites(lines, version: csvVersion(text), keepDuplicates: true, defaultZoom: defaultZoom)
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

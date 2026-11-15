import Foundation

// SiteStore가 쓰는 UIKit 캐시의 테스트용 대체. 실제 WebCache는 WebView.swift에 있다.
enum WebCache { static func drop(_ id: UUID) {} }

// swiftc -parse-as-library cwv/CWV/Site.swift cwv/CWV/SiteStore.swift cwv/test_site.swift -o build/test_site && build/test_site
@main
struct TestSite {
    static func main() throws {
        func url(_ s: String) -> URL { URL(string: s)! }

        // normalizeURL
        assert(normalizeURL("damoang.net/empathy")?.absoluteString == "https://damoang.net/empathy")
        assert(normalizeURL("  https://a.com/x  ")?.absoluteString == "https://a.com/x")
        assert(normalizeURL("HTTP://a.com")?.scheme == "http")
        assert(normalizeURL("ftp://a.com") == nil)
        assert(normalizeURL("") == nil)
        assert(normalizeURL("   ") == nil)
        assert(normalizeURL("https://") == nil)
        assert(normalizeURL("javascript:alert(1)") == nil)
        assert(normalizeURL("a b.com") == nil)

        // isExternal
        let base = url("https://damoang.net/empathy")
        assert(!isExternal(url("https://damoang.net/free/1"), base: base))
        assert(!isExternal(url("https://www.damoang.net/x"), base: base))
        assert(!isExternal(url("https://m.damoang.net/x"), base: base))
        assert(isExternal(url("https://youtube.com/watch?v=1"), base: base))
        assert(isExternal(url("https://evildamoang.net/"), base: base))  // 접미사만 같은 다른 도메인
        assert(!isExternal(url("https://damoang.net/"), base: url("https://www.damoang.net")))

        // clampZoom
        assert(clampZoom(0.4) == 0.5)
        assert(clampZoom(3.5) == 3.0)
        assert(clampZoom(1.0 + 0.1 + 0.1 + 0.1) == 1.3)  // 부동소수 누적 오차 보정
        assert(clampZoom(1.0) == 1.0)

        // FabCorner: 사분면으로 가장 가까운 모서리
        let scr = CGSize(width: 400, height: 800)
        assert(FabCorner.nearest(to: CGPoint(x: 10, y: 10), in: scr) == .topLeading)
        assert(FabCorner.nearest(to: CGPoint(x: 390, y: 10), in: scr) == .topTrailing)
        assert(FabCorner.nearest(to: CGPoint(x: 10, y: 790), in: scr) == .bottomLeading)
        assert(FabCorner.nearest(to: CGPoint(x: 390, y: 790), in: scr) == .bottomTrailing)
        assert(FabCorner.nearest(to: CGPoint(x: 200, y: 400), in: scr) == .bottomTrailing)  // 정중앙은 기본 모서리
        assert(FabCorner(rawValue: "nope") == nil)  // 저장값이 깨지면 AppStorage가 기본값을 쓴다

        // adblock.json: 규칙마다 trigger/action이 있어야 WebKit이 컴파일한다
        let rules = try JSONSerialization.jsonObject(with: Data(contentsOf: url("file://" + FileManager.default.currentDirectoryPath + "/cwv/CWV/adblock.json"))) as! [[String: Any]]
        assert(!rules.isEmpty && rules.allSatisfy { $0["trigger"] != nil && $0["action"] != nil })

        // adblock.json url-filter: 광고 호스트만 막고, 정상 URL의 경로/쿼리/비슷한 호스트는 막지 않는다 (UXP-R1)
        func blocked(_ u: String) -> Bool {
            rules.contains {
                guard let f = ($0["trigger"] as? [String: Any])?["url-filter"] as? String, f != ".*",
                      let re = try? NSRegularExpression(pattern: f, options: .caseInsensitive) else { return false }
                return re.firstMatch(in: u, range: NSRange(u.startIndex..., in: u)) != nil
            }
        }
        assert(blocked("https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"))
        assert(blocked("https://securepubads.g.doubleclick.net/tag/js/gpt.js"))
        assert(blocked("https://doubleclick.net/x"))
        assert(blocked("https://t1.daumcdn.net/kas/static/ba.min.js"))
        assert(!blocked("https://community.example/api/search?q=doubleclick.net"))
        assert(!blocked("https://notdoubleclick.net/main.js"))
        assert(!blocked("https://damoang.net/empathy"))
        assert(!blocked("https://t1.daumcdn.net/other/x.js"))

        // opensInSafariSheet: 직접 누른 외부 링크만 (새 창/리다이렉트/로그인 흐름은 웹뷰 유지)
        assert(opensInSafariSheet(url("https://youtube.com/x"), base: base, linkActivated: true))
        assert(!opensInSafariSheet(url("https://youtube.com/x"), base: base, linkActivated: false))
        assert(!opensInSafariSheet(url("https://damoang.net/x"), base: base, linkActivated: true))

        // SiteStore: 격리된 UserDefaults에 저장 후 새 인스턴스로 복원
        let suite = "cwv.test.\(UUID().uuidString)"
        let ud = UserDefaults(suiteName: suite)!
        defer { ud.removePersistentDomain(forName: suite) }
        let st = SiteStore(defaults: ud)
        assert(st.sites.count == 1 && st.lastSiteID == nil)  // 첫 실행은 기본값
        st.add(name: "A", url: url("https://a.com"))
        st.add(name: "B", url: url("https://b.com"))
        st.sites.move(fromOffsets: [2], toOffset: 0)  // B, 다모앙, A
        let b = st.sites[0]
        st.setZoom(b.id, 1.25)  // 0.1 단위로 반올림: 1.3
        st.setZoom(st.sites[1].id, 9)
        st.lastSiteID = b.id
        var edited = st.sites[2]
        edited.name = "A2"
        st.update(edited)
        st.remove(at: [1])  // 다모앙 삭제
        let st2 = SiteStore(defaults: ud)
        assert(st2.sites.map(\.name) == ["B", "A2"])
        assert(st2.sites[0].zoom == 1.3 && st2.lastSiteID == b.id)

        // JSON 왕복과 기본값
        let sites = defaultSites()
        let back = try JSONDecoder().decode([Site].self, from: JSONEncoder().encode(sites))
        assert(back == sites)
        assert(sites.contains { $0.url.host == "damoang.net" })

        print("test_site: OK")
    }
}

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

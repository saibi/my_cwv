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

        // parseDefaultPages (PRS-M1)
        let csv = "\u{FEFF}# 주석\n\nhttps://damoang.net/empathy,다모앙-공감\r\n  news.hada.io/new  \nhttps://a.com/x?y=1&z=2,제목, 쉼표 포함\nftp://bad.com\nnot a url\nhttps://damoang.net/empathy,중복\n,제목만\n"
        let pages = parseDefaultPages(csv)
        assert(pages.map(\.name) == ["다모앙-공감", "", "제목, 쉼표 포함"])  // 제목 없으면 빈 이름(자동)
        assert(pages[1].url.absoluteString == "https://news.hada.io/new")  // 주소는 정규화
        assert(pages[2].url.absoluteString == "https://a.com/x?y=1&z=2")
        assert(parseDefaultPages("").isEmpty && parseDefaultPages("# only\n\n").isEmpty)
        assert(stableID(for: url("https://a.com/x")) == stableID(for: url("https://a.com/x")))
        assert(stableID(for: url("https://a.com/x")) != stableID(for: url("https://a.com/y")))
        assert(parseDefaultPages(csv).map(\.id) == pages.map(\.id))  // 다시 읽어도 id가 같다
        assert(fallbackSites().count == 1 && fallbackSites()[0].url.host == "www.google.com")

        // displayName / usableTitle / 스와이프 기준 (SWT-M1)
        let auto = Site(name: "", url: url("https://news.hada.io/new"))
        assert(auto.displayName(cached: nil) == "news.hada.io")  // 타이틀을 모르면 도메인
        assert(auto.displayName(cached: "GeekNews") == "GeekNews")
        assert(Site(name: "내 이름", url: auto.url).displayName(cached: "GeekNews") == "내 이름")  // 직접 정한 이름이 우선
        assert(Site(name: "news.hada.io", url: auto.url).displayName(cached: "GeekNews") == "news.hada.io")  // CSV 등에 명시한 도메인 제목도 존중 (SWT-R3)
        assert(usableTitle("  날짜별 공감글 | 다모앙 \n") == "날짜별 공감글 | 다모앙")
        assert(usableTitle(nil) == nil && usableTitle("   ") == nil)
        assert(usableTitle("Just a moment...") == nil && usableTitle("Attention Required! | Cloudflare") == nil)
        assert(shouldCloseOnEdgeSwipe(translation: 100, velocity: 0) && shouldCloseOnEdgeSwipe(translation: 20, velocity: 900))
        assert(!shouldCloseOnEdgeSwipe(translation: 30, velocity: 100) && !shouldCloseOnEdgeSwipe(translation: -100, velocity: -900))

        // safariTarget (PRS-M4)
        let fb = url("https://damoang.net/empathy")
        assert(safariTarget(current: url("https://damoang.net/free/1"), fallback: fb).path == "/free/1")
        assert(safariTarget(current: nil, fallback: fb) == fb)
        assert(safariTarget(current: url("about:blank"), fallback: fb) == fb)

        // SiteStore: 기본(CSV)/사용자 분리, 저장, Keychain 백업 복원, 마이그레이션
        var vault: Data?  // 메모리 백업 (Keychain 대체)
        let mem = KeyValueBackup(save: { vault = $0 }, load: { vault })
        func fresh() -> (UserDefaults, () -> Void) {
            let suite = "cwv.test.\(UUID().uuidString)"
            let ud = UserDefaults(suiteName: suite)!
            return (ud, { ud.removePersistentDomain(forName: suite) })
        }
        let (ud, clean) = fresh()
        defer { clean() }
        let st = SiteStore(defaults: ud, backup: mem, defaultPages: pages)
        assert(st.sites.map(\.name) == pages.map(\.name) && st.lastSiteID == nil)  // 첫 실행: 기본만
        st.add(name: "A", url: url("https://a.com"))
        st.add(name: "B", url: url("https://b.com"))
        st.userSites.move(fromOffsets: [1], toOffset: 0)  // B, A
        st.setZoom(st.userSites[0].id, 1.25)  // 0.1 단위 반올림: 1.3
        st.setZoom(pages[0].id, 9)  // 기본 사이트 글자 크기: 3.0
        st.lastSiteID = pages[0].id
        var edited = st.userSites[1]
        edited.name = "A2"
        st.update(edited)
        st.update(pages[0])  // 기본 사이트는 편집 불가 (무시)
        assert(st.sites[0].name == "다모앙-공감")
        let st2 = SiteStore(defaults: ud, backup: .none, defaultPages: pages)
        assert(st2.userSites.map(\.name) == ["B", "A2"] && st2.userSites[0].zoom == 1.3)
        assert(st2.sites[0].zoom == 3.0 && st2.lastSiteID == pages[0].id)

        // 앱 삭제 후 재설치: UserDefaults가 비어도 백업에서 복원 (lastSiteID는 복원 대상 아님)
        let (ud3, clean3) = fresh()
        defer { clean3() }
        let st3 = SiteStore(defaults: ud3, backup: mem, defaultPages: pages)
        assert(st3.userSites.map(\.name) == ["B", "A2"] && st3.sites[0].zoom == 3.0 && st3.lastSiteID == nil)

        // UserDefaults의 userData가 깨져 있어도 정상 백업에서 복원하고, 정상 백업을 덮어쓰지 않는다 (PRS-R2)
        let (ud6, clean6) = fresh()
        defer { clean6() }
        ud6.set(Data("{broken".utf8), forKey: "userData")
        let st6 = SiteStore(defaults: ud6, backup: mem, defaultPages: pages)
        assert(st6.userSites.map(\.name) == ["B", "A2"] && st6.sites[0].zoom == 3.0)

        // CSV가 바뀌어도(기본 사이트 추가/삭제) 사용자 사이트는 그대로
        let st4 = SiteStore(defaults: ud3, backup: mem, defaultPages: Array(pages.dropFirst()))
        assert(st4.sites.map(\.name) == ["", "제목, 쉼표 포함", "B", "A2"])

        // 페이지 타이틀 캐시: 저장되고 다시 실행해도 유지, 글 상세 같은 빈 값/차단 화면 제목은 무시 (SWT-M2)
        let (ud7, clean7) = fresh()
        defer { clean7() }
        let st7 = SiteStore(defaults: ud7, backup: .none, defaultPages: pages)
        let hada = st7.defaultPages[1]
        assert(st7.title(for: hada) == "news.hada.io" && st7.title(for: st7.defaultPages[0]) == "다모앙-공감")
        st7.setPageTitle(hada.id, " GeekNews ")
        st7.setPageTitle(hada.id, "Just a moment...")
        st7.setPageTitle(hada.id, "")
        assert(st7.title(for: hada) == "GeekNews")
        st7.setPageTitle(st7.defaultPages[0].id, "무시됨")  // 직접 정한 제목이 우선
        assert(st7.title(for: st7.defaultPages[0]) == "다모앙-공감")
        let st7b = SiteStore(defaults: ud7, backup: .none, defaultPages: pages)
        assert(st7b.title(for: hada) == "GeekNews")  // 재실행 후에도 유지

        // 주소를 바꾸면 이전 사이트의 제목 캐시를 버린다 (SWT-R1)
        let (ud8, clean8) = fresh()
        defer { clean8() }
        let st8 = SiteStore(defaults: ud8, backup: .none, defaultPages: pages)
        st8.add(name: "", url: url("https://a.com"))
        var a8 = st8.userSites[0]
        st8.setPageTitle(a8.id, "A 사이트")
        assert(st8.title(for: a8) == "A 사이트")
        a8.url = url("https://b.com")
        st8.update(a8)
        assert(st8.title(for: st8.userSites[0]) == "b.com")
        assert(SiteStore(defaults: ud8, backup: .none, defaultPages: pages).title(for: a8) == "b.com")  // 재실행 후에도

        // 이전 버전이 도메인을 이름으로 저장한 사용자 사이트는 자동 이름으로 되돌아와 페이지 제목을 쓴다 (SWT-R3)
        let (ud9, clean9) = fresh()
        defer { clean9() }
        let legacy = [Site(name: "mine.com", url: url("https://mine.com")), Site(name: "직접 지은 이름", url: url("https://x.com"))]
        ud9.set(try JSONEncoder().encode(legacy), forKey: "sites")  // 마이그레이션 경로
        let st9 = SiteStore(defaults: ud9, backup: .none, defaultPages: pages)
        assert(st9.userSites.map(\.name) == ["", "직접 지은 이름"])
        st9.setPageTitle(st9.userSites[0].id, "Mine 제목")
        assert(st9.title(for: st9.userSites[0]) == "Mine 제목" && st9.title(for: st9.userSites[1]) == "직접 지은 이름")
        assert(parseDefaultPages("https://a.com,a.com")[0].displayName(cached: "페이지 제목") == "a.com")  // 명시한 CSV 제목이 우선

        // 사용자 사이트 삭제 (userSites 기준 offsets)
        st4.remove(at: [0])
        assert(st4.userSites.map(\.name) == ["A2"])

        // 이전 버전(단일 목록 "sites") 마이그레이션: 기본 주소와 같은 항목은 기본으로 흡수하고 글자 크기를 이어받는다
        let (ud5, clean5) = fresh()
        defer { clean5() }
        var old = [Site(name: "옛 다모앙", url: url("https://damoang.net/empathy"), zoom: 1.4), Site(name: "내 사이트", url: url("https://mine.com"), zoom: 1.2)]
        ud5.set(try JSONEncoder().encode(old), forKey: "sites")
        ud5.set(old[0].id.uuidString, forKey: "lastSiteID")  // 이전 기본 사이트를 열어 둔 상태 (PRS-R4)
        let st5 = SiteStore(defaults: ud5, backup: .none, defaultPages: pages)
        assert(st5.userSites.map(\.name) == ["내 사이트"] && st5.userSites[0].zoom == 1.2)
        assert(st5.sites[0].zoom == 1.4 && st5.lastSiteID == pages[0].id)  // 마지막 사이트도 새 고정 id로 이어진다
        old.removeAll()

        // JSON 왕복
        let back = try JSONDecoder().decode([Site].self, from: JSONEncoder().encode(pages))
        assert(back == pages)

        print("test_site: OK")
    }
}

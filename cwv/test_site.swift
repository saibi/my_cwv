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

        // SiteStore: 단일 목록 (LST-M1)
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
        assert(st.sites.map(\.name) == pages.map(\.name) && st.lastSiteID == nil)  // 첫 실행: 기본 목록으로 생성
        st.add(name: "A", url: url("https://a.com"))
        st.add(name: "B", url: url("https://b.com"))
        st.sites.move(fromOffsets: [4], toOffset: 0)  // B가 맨 앞 (기본 항목도 마음대로 이동)
        st.sites.move(fromOffsets: [1], toOffset: 5)  // 다모앙을 맨 뒤로
        assert(st.sites.map(\.name) == ["B", "", "제목, 쉼표 포함", "A", "다모앙-공감"])
        st.setZoom(st.sites[0].id, 1.25)  // 0.1 단위 반올림: 1.3
        st.setZoom(pages[0].id, 9)  // 기본 항목도 같은 방식: 3.0
        st.lastSiteID = pages[0].id
        var edited = st.sites[3]
        edited.name = "A2"
        st.update(edited)
        var edDefault = st.sites[4]  // 기본 항목도 편집할 수 있다
        edDefault.name = "공감 편집"
        st.update(edDefault)
        let names = ["B", "", "제목, 쉼표 포함", "A2", "공감 편집"]
        assert(st.sites.map(\.name) == names)

        // 다시 실행: 저장된 목록을 그대로 쓴다. 기본 목록(CSV)이 달라져도 개입하지 않는다
        let st2 = SiteStore(defaults: ud, backup: .none, defaultPages: [Site(name: "전혀 다름", url: url("https://other.com"))])
        assert(st2.sites.map(\.name) == names && st2.sites[0].zoom == 1.3 && st2.sites[4].zoom == 3.0 && st2.lastSiteID == pages[0].id)

        // 앱 삭제 후 재설치: UserDefaults가 비어도 백업에서 복원 (순서, 글자 크기 포함. lastSiteID는 복원 대상 아님)
        let (ud3, clean3) = fresh()
        defer { clean3() }
        let st3 = SiteStore(defaults: ud3, backup: mem, defaultPages: pages)
        assert(st3.sites.map(\.name) == names && st3.sites[0].zoom == 1.3 && st3.lastSiteID == nil)

        // UserDefaults의 목록이 깨져 있어도 정상 백업에서 복원하고, 정상 백업을 덮어쓰지 않는다 (PRS-R2)
        let (ud6, clean6) = fresh()
        defer { clean6() }
        ud6.set(Data("{broken".utf8), forKey: "siteList")
        let st6 = SiteStore(defaults: ud6, backup: mem, defaultPages: pages)
        assert(st6.sites.map(\.name) == names)

        // 전부 삭제해도 빈 목록이 저장되어 다시 실행해도 기본값으로 되살아나지 않는다
        let (ud10, clean10) = fresh()
        defer { clean10() }
        let st10 = SiteStore(defaults: ud10, backup: .none, defaultPages: pages)
        st10.remove(at: IndexSet(0..<st10.sites.count))
        assert(st10.sites.isEmpty)
        assert(SiteStore(defaults: ud10, backup: .none, defaultPages: pages).sites.isEmpty)
        // 초기화: 앱에 내장된 기본 목록으로 (글자 크기 100%)
        st10.reset()
        assert(st10.sites == pages && st10.sites.allSatisfy { $0.zoom == 1.0 })
        assert(SiteStore(defaults: ud10, backup: .none, defaultPages: []).sites == pages)  // 초기화 결과가 저장된다

        // 페이지 타이틀 캐시: 저장되고 다시 실행해도 유지, 글 상세 같은 빈 값/차단 화면 제목은 무시 (SWT-M2)
        let (ud7, clean7) = fresh()
        defer { clean7() }
        let st7 = SiteStore(defaults: ud7, backup: .none, defaultPages: pages)
        let hada = st7.sites[1]
        assert(st7.title(for: hada) == "news.hada.io" && st7.title(for: st7.sites[0]) == "다모앙-공감")
        st7.setPageTitle(hada.id, " GeekNews ")
        st7.setPageTitle(hada.id, "Just a moment...")
        st7.setPageTitle(hada.id, "")
        assert(st7.title(for: hada) == "GeekNews")
        st7.setPageTitle(st7.sites[0].id, "무시됨")  // 직접 정한 제목이 우선
        assert(st7.title(for: st7.sites[0]) == "다모앙-공감")
        let st7b = SiteStore(defaults: ud7, backup: .none, defaultPages: pages)
        assert(st7b.title(for: hada) == "GeekNews")  // 재실행 후에도 유지

        // 주소를 바꾸면 이전 사이트의 제목 캐시를 버린다 (SWT-R1)
        let (ud8, clean8) = fresh()
        defer { clean8() }
        let st8 = SiteStore(defaults: ud8, backup: .none, defaultPages: pages)
        st8.add(name: "", url: url("https://a.com"))
        var a8 = st8.sites.last!
        st8.setPageTitle(a8.id, "A 사이트")
        assert(st8.title(for: a8) == "A 사이트")
        a8.url = url("https://b.com")
        st8.update(a8)
        assert(st8.title(for: st8.sites.last!) == "b.com")
        assert(SiteStore(defaults: ud8, backup: .none, defaultPages: pages).title(for: a8) == "b.com")  // 재실행 후에도

        // 이전 형식 마이그레이션 1 (기본/사용자 분리 userData): 화면에 보이던 순서(기본 다음 사용자)를 유지하고 글자 크기를 잇는다
        func legacyData(users: [Site], zooms: [String: Double]) throws -> Data {
            try JSONSerialization.data(withJSONObject: ["userSites": JSONSerialization.jsonObject(with: JSONEncoder().encode(users)), "defaultZooms": zooms])
        }
        let userSites = [Site(name: "mine.com", url: url("https://mine.com"), zoom: 1.2), Site(name: "직접 지은 이름", url: url("https://x.com"))]
        let (ud11, clean11) = fresh()
        defer { clean11() }
        ud11.set(try legacyData(users: userSites, zooms: [pages[0].id.uuidString: 1.5]), forKey: "userData")
        let st11 = SiteStore(defaults: ud11, backup: .none, defaultPages: pages)
        assert(st11.sites.map(\.name) == ["다모앙-공감", "", "제목, 쉼표 포함", "", "직접 지은 이름"])  // 이전 도메인 이름은 자동 이름으로
        assert(st11.sites[0].zoom == 1.5 && st11.sites[3].zoom == 1.2 && st11.sites[3].url.host == "mine.com")
        assert(SiteStore(defaults: ud11, backup: .none, defaultPages: []).sites.map(\.name) == st11.sites.map(\.name))  // 새 형식으로 저장됨
        // 같은 이전 형식이 Keychain에만 있어도 (앱 삭제 후 재설치) 마이그레이션된다
        let lv = try legacyData(users: userSites, zooms: [:])
        let (ud12, clean12) = fresh()
        defer { clean12() }
        let st12 = SiteStore(defaults: ud12, backup: KeyValueBackup(save: { _ in }, load: { lv }), defaultPages: pages)
        assert(st12.sites.count == 5 && st12.sites[4].name == "직접 지은 이름")

        // 이전 형식 마이그레이션 2 (가장 오래된 단일 목록 "sites"): 그대로 쓰고 id(마지막 사이트)도 유지
        let (ud5, clean5) = fresh()
        defer { clean5() }
        let old = [Site(name: "옛 다모앙", url: url("https://damoang.net/empathy"), zoom: 1.4), Site(name: "내 사이트", url: url("https://mine.com"), zoom: 1.2)]
        ud5.set(try JSONEncoder().encode(old), forKey: "sites")
        ud5.set(old[0].id.uuidString, forKey: "lastSiteID")
        let st5 = SiteStore(defaults: ud5, backup: .none, defaultPages: pages)
        assert(st5.sites == old && st5.lastSiteID == old[0].id)

        // CSV 내보내기/가져오기 (LST-M3)
        let exported = exportCSV([
            Site(name: "", url: url("https://a.com/x")),
            Site(name: "제목, 쉼표", url: url("https://b.com/y?q=1")),
            Site(name: "줄\n바꿈", url: url("https://c.com")),
            Site(name: "", url: url("https://d.com/a,b")),  // 주소의 쉼표는 %2C로
        ])
        assert(exported.hasPrefix("# CWV site list") && exported.hasSuffix("\n"))
        assert(exported.contains("https://d.com/a%2Cb\n") && !exported.contains("a,b"))
        guard case .success(let imp) = importCSV(Data(exported.utf8)) else { fatalError("import failed") }
        assert(imp.sites.map(\.name) == ["", "제목, 쉼표", "줄 바꿈", ""] && imp.skipped == 0)  // 이름 왕복, 줄바꿈은 공백
        assert(imp.sites.map { $0.url.absoluteString } == ["https://a.com/x", "https://b.com/y?q=1", "https://c.com", "https://d.com/a%2Cb"])
        assert(importCSV(Data((exported + "ftp://bad\nhttps://a.com/x,중복\nnot a url\n").utf8)).map { $0.skipped } == .success(3))  // 잘못된 줄/중복은 건너뛰고 센다
        assert(importCSV(Data(("\u{FEFF}" + exported).utf8)).map { $0.sites.count } == .success(4))  // BOM
        // 제한 (신뢰할 수 없는 파일)
        assert(importCSV(Data(count: csvImportMaxBytes + 1)).map { $0.sites.count } == .failure(.tooLarge))
        assert(importCSV(Data([0xFF, 0xFE, 0x00, 0x41])).map { $0.sites.count } == .failure(.notUTF8))
        let many = (0...csvImportMaxLines).map { "https://s\($0).com" }.joined(separator: "\n")
        assert(importCSV(Data(many.utf8)).map { $0.sites.count } == .failure(.tooManyLines))
        assert(importCSV(Data("# 주석만\n\nnot a url\n".utf8)).map { $0.sites.count } == .failure(.noValidLines))
        assert(importCSV(Data()).map { $0.sites.count } == .failure(.noValidLines))
        // 내보낸 파일로 교체: 목록 전체와 순서가 바뀌고 글자 크기는 100%
        let st13 = SiteStore(defaults: ud10, backup: .none, defaultPages: pages)
        st13.setZoom(st13.sites[0].id, 2.0)
        st13.replace(with: imp.sites)
        assert(st13.sites.map(\.name) == ["", "제목, 쉼표", "줄 바꿈", ""] && st13.sites.allSatisfy { $0.zoom == 1.0 })

        // JSON 왕복
        let back = try JSONDecoder().decode([Site].self, from: JSONEncoder().encode(pages))
        assert(back == pages)

        print("test_site: OK")
    }
}

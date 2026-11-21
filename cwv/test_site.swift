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
        // 초기화: 앱에 내장된 기본 목록으로 (글자 크기 100%, 바꾼 크기에서 시작)
        st10.replace(with: pages.map { var s = $0; s.zoom = 2.0; return s })
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

        // 초기화 때 같은 id의 주소가 달라지면 이전 사이트의 제목 캐시를 버린다 (LST-R5)
        let (ud14, clean14) = fresh()
        defer { clean14() }
        let st14 = SiteStore(defaults: ud14, backup: .none, defaultPages: pages)
        var moved = st14.sites[1]  // 자동 이름 항목(news.hada.io)의 주소를 바꾼다 (id 유지)
        moved.url = url("https://other.example/b")
        st14.update(moved)
        st14.setPageTitle(moved.id, "다른 사이트 제목")
        assert(st14.title(for: st14.sites[1]) == "다른 사이트 제목")
        st14.setPageTitle(st14.sites[0].id, "무시")  // 주소가 그대로인 항목의 캐시는 유지돼야 한다
        st14.setPageTitle(st14.sites[2].id, "유지될 제목")
        st14.reset()
        assert(st14.title(for: st14.sites[1]) == "news.hada.io")  // A 주소로 돌아왔으니 B 제목은 사라짐
        assert(st14.title(for: st14.sites[2]) == "제목, 쉼표 포함")  // 명시 이름은 그대로, 캐시도 지우지 않음
        st14.setPageTitle(st14.sites[1].id, "GeekNews")
        st14.reset()
        assert(st14.title(for: st14.sites[1]) == "GeekNews")  // 주소가 같은 항목의 캐시는 유지

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
        // 호스트와 같은 이름도 그대로 옮긴다 (LST-R6)
        let (ud15, clean15) = fresh()
        defer { clean15() }
        ud15.set(try JSONEncoder().encode([Site(name: "mine.com", url: url("https://mine.com"))]), forKey: "sites")
        assert(SiteStore(defaults: ud15, backup: .none, defaultPages: pages).sites.map(\.name) == ["mine.com"])

        // CSV 내보내기/가져오기 (LST-M3)
        let exported = exportCSV([
            Site(name: "", url: url("https://a.com/x")),
            Site(name: "제목, 쉼표", url: url("https://b.com/y?q=1")),
            Site(name: "줄\n바꿈", url: url("https://c.com")),
            Site(name: "", url: url("https://d.com/a,b")),  // 주소에 쉼표가 있으면 따옴표로 감싼다
            Site(name: "이름", url: url("https://e.com/?q=a,b&r=1")),
        ])
        assert(exported.hasPrefix("# v3\n") && exported.hasSuffix("\n"))
        assert(exported.contains("\n\"https://d.com/a,b\",\"\",100,m\n") && exported.contains("\"https://e.com/?q=a,b&r=1\",\"이름\",100,m\n"))
        guard case .success(let imp) = importCSV(Data(exported.utf8)) else { fatalError("import failed") }
        assert(imp.sites.map(\.name) == ["", "제목, 쉼표", "줄 바꿈", "", "이름"] && imp.skipped == 0)  // 이름 왕복, 줄바꿈은 공백
        assert(imp.sites.map { $0.url.absoluteString } == ["https://a.com/x", "https://b.com/y?q=1", "https://c.com", "https://d.com/a,b", "https://e.com/?q=a,b&r=1"])  // 쉼표 주소도 손실 없이 왕복 (LST-R4)
        assert(importCSV(Data((exported + "ftp://bad\nhttps://a.com/x\nnot a url\n").utf8)).map { $0.skipped } == .success(3))  // 잘못된 줄과 주소+이름이 같은 줄은 건너뛰고 센다
        assert(importCSV(Data(("\u{FEFF}" + exported).utf8)).map { $0.sites.count } == .success(5))  // BOM
        // 따옴표 해석: 안의 ""는 ", 닫히지 않았거나 닫은 뒤 다른 글자가 오면 건너뜀
        let q = parseDefaultPages("\"https://a.com/p?x=1,2\"\n\"https://b.com/q\"\"z\",\"제목\"\n\"https://c.com\nhttps://d.com\"x\n\"https://e.com\" , 공백 제목")
        // 안의 ""는 "가 되고(주소에서는 %22로 인코딩), 닫히지 않은 따옴표 줄과 닫은 뒤 글자가 붙은 줄(c.com, d.com)은 건너뜀
        assert(q.map { $0.url.absoluteString } == ["https://a.com/p?x=1,2", "https://b.com/q%22z", "https://e.com"] && q[2].name == "공백 제목")
        // 중복 (LST-R1): 기본 목록은 주소 중복 제거, 백업 복원은 이름이 다르면 보존하고 id는 서로 다르다. 주소와 이름이 같으면 제거
        let dupText = "https://dup.com,업무용\nhttps://dup.com,개인용\nhttps://dup.com,개인용\nhttps://dup.com\n"
        assert(parseDefaultPages(dupText).count == 1)
        guard case .success(let dup) = importCSV(Data(dupText.utf8)) else { fatalError("dup import failed") }
        assert(dup.sites.map(\.name) == ["업무용", "개인용", ""] && Set(dup.sites.map(\.id)).count == 3 && dup.skipped == 1)
        // 내보내기 제한: 가져오기와 같은 범위 (LST-R2)
        func many(_ n: Int) -> [Site] { (0..<n).map { Site(name: "", url: url("https://s\($0).com")) } }
        assert((try? exportCSVChecked(many(csvImportMaxLines)).get()) != nil)  // 500개는 가능
        assert(exportCSVChecked(many(csvImportMaxLines + 1)).map { _ in 0 } == .failure(.tooManyLines))
        let longName = String(repeating: "가", count: 40_000)  // 유니코드 3바이트 x 40000 x 10개 > 1MB
        let big = (0..<10).map { Site(name: longName, url: url("https://b\($0).com")) }
        assert(exportCSVChecked(big).map { _ in 0 } == .failure(.tooLarge))
        if case .success(let okText) = exportCSVChecked(many(csvImportMaxLines)) { assert(importCSV(Data(okText.utf8)).map { $0.sites.count } == .success(csvImportMaxLines)) }  // 내보낸 500개는 복원 가능
        // 제한된 읽기 (LST-R3): 상한을 넘는 파일도 csvImportMaxBytes+1바이트까지만 읽고 거부된다
        let bigFile = FileManager.default.temporaryDirectory.appendingPathComponent("cwv_big_\(UUID().uuidString).csv")
        try Data(count: csvImportMaxBytes + 5000).write(to: bigFile)
        defer { try? FileManager.default.removeItem(at: bigFile) }
        let limited = readLimited(bigFile)
        assert(limited?.count == csvImportMaxBytes + 1 && importCSV(limited!).map { $0.sites.count } == .failure(.tooLarge))
        assert(readLimited(URL(fileURLWithPath: "/nonexistent/x.csv")) == nil)
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
        assert(st13.sites.map(\.name) == ["", "제목, 쉼표", "줄 바꿈", "", "이름"] && st13.sites.allSatisfy { $0.zoom == 1.0 })  // 파일에 적힌 100%

        // OPT: 확대% 토큰, 3/2/1칸 해석, 이름 쉼표, 범위 밖
        assert(parseZoomToken("120") == 1.2 && parseZoomToken(" 120% ") == 1.2 && parseZoomToken("10") == 0.5 && parseZoomToken("999") == 3.0)
        assert(parseZoomToken("") == nil && parseZoomToken("abc") == nil && parseZoomToken("-5") == nil && parseZoomToken("%") == nil)
        let z = parseDefaultPages("# v2\nhttps://a.com,\"이름\",150\nhttps://b.com,\"제목, 쉼표\",80%\nhttps://c.com,\"\",200\nhttps://d.com,\"이름만\"\nhttps://e.com\nhttps://f.com,\"쉼표, 포함\"\nhttps://g.com,\"x\",9999", defaultZoom: 1.2)
        assert(z.map(\.name) == ["이름", "제목, 쉼표", "", "이름만", "", "쉼표, 포함", "x"])
        // v1(첫 줄에 # v2가 없음)은 확대%를 읽지 않는다: 첫 쉼표 뒤가 전부 이름 (OPT-R2)
        assert(csvVersion("https://a.com,시즌, 2") == 1 && csvVersion("# CWV site list: one line per site, url[,name]\n") == 1 && csvVersion("\u{FEFF}# V2 \n") == 2 && csvVersion("# v3") == 3 && csvVersion("") == 1)
        let v1 = parseDefaultPages("https://a.com,시즌, 2\nhttps://b.com,\"따옴표\",150", defaultZoom: 1.2)
        assert(v1.map(\.name) == ["시즌, 2", "\"따옴표\",150"] && v1.map(\.zoom) == [1.2, 1.2])
        // v2 이스케이프: 이름의 " 와 \ 는 \로 감싸 왕복, 따옴표 없는 손글씨 줄도 허용, 닫히지 않은 따옴표 줄은 건너뜀
        let esc = [Site(name: "그는 \"안녕\" 했다, \\끝", url: url("https://q.com"), zoom: 1.3), Site(name: "\\", url: url("https://r.com"))]
        let escText = exportCSV(esc)
        assert(escText.contains("https://q.com,\"그는 \\\"안녕\\\" 했다, \\\\끝\",130,m\n"))
        guard case .success(let escBack) = importCSV(Data(escText.utf8)) else { fatalError() }
        assert(escBack.sites.map(\.name) == esc.map(\.name) && escBack.sites.map(\.zoom) == [1.3, 1.0])
        let loose = parseDefaultPages("# v2\nhttps://a.com,손글씨, 이름,130\nhttps://b.com,\"닫히지 않음\nhttps://c.com,\"끝\" x", defaultZoom: 1.2)
        assert(loose.count == 1 && loose[0].name == "손글씨, 이름" && loose[0].zoom == 1.3)
        assert(z.map(\.zoom) == [1.5, 0.8, 2.0, 1.2, 1.2, 1.2, 3.0])  // 칸이 없으면 기본 확대%, 범위 밖은 보정
        // 백업: 이름이 비면 저장된 타이틀, 확대% 포함. 복원하면 이름과 확대%가 그대로 (OPT-Q2)
        let src = [Site(name: "", url: url("https://a.com"), zoom: 1.5), Site(name: "직접", url: url("https://b.com"), zoom: 0.8), Site(name: "", url: url("https://c.com"), zoom: 1.2)]
        let titled = exportCSV(src, titles: [src[0].id.uuidString: "A\n타이틀, 쉼표", src[1].id.uuidString: "무시"])
        guard case .success(let rt) = importCSV(Data(titled.utf8), defaultZoom: 2.0) else { fatalError("roundtrip failed") }
        assert(rt.sites.map(\.name) == ["A 타이틀, 쉼표", "직접", ""] && rt.sites.map(\.zoom) == [1.5, 0.8, 1.2])
        // 옛 2칸 백업과 기본 목록은 기본 확대%
        assert(importCSV(Data("https://a.com,이름\n".utf8), defaultZoom: 1.2).map { $0.sites[0].zoom } == .success(1.2))

        // 기본 확대% 옵션: 기본 120%, 저장되어 유지, 범위 보정, 새 사이트에 적용 (OPT-M1)
        let (ud16, clean16) = fresh()
        defer { clean16() }
        let st16 = SiteStore(defaults: ud16, backup: .none, defaultPages: pages)
        assert(st16.defaultZoom == 1.2)
        st16.add(name: "N", url: url("https://n.com"))
        assert(st16.sites.last!.zoom == 1.2 && st16.sites[0].zoom == 1.0)  // 기존 항목은 그대로
        st16.defaultZoom = 1.5
        st16.add(name: "M", url: url("https://m.com"))
        st16.add(name: "P", url: url("https://p.com"), zoom: 0.7)
        assert(st16.sites[st16.sites.count - 2].zoom == 1.5 && st16.sites.last!.zoom == 0.7)
        assert(SiteStore(defaults: ud16, backup: .none, defaultPages: pages).defaultZoom == 1.5)
        ud16.set(9.0, forKey: "defaultZoom")
        assert(SiteStore(defaults: ud16, backup: .none, defaultPages: pages).defaultZoom == 3.0)
        // 주소, 이름, 확대%를 한 번에 편집
        var e16 = st16.sites[0]
        e16.name = "새 이름"; e16.url = url("https://new.example"); e16.zoom = 2.04
        st16.update(e16)
        assert(st16.sites[0].name == "새 이름" && st16.sites[0].url.host == "new.example" && st16.sites[0].zoom == 2.0)
        // 초기화는 기본 목록 파일의 % 없는 줄에 지금의 기본 확대%를 쓴다
        let dyn = SiteStore(defaults: fresh().0, backup: .none, defaultPages: { parseDefaultPages("# v2\nhttps://a.com\nhttps://b.com,\"b\",90", defaultZoom: $0) })
        assert(dyn.sites.map(\.zoom) == [1.2, 0.9])
        dyn.defaultZoom = 1.4
        dyn.reset()
        assert(dyn.sites.map(\.zoom) == [1.4, 0.9])
        if case .success(let t) = dyn.exportCSV(device: nil) { assert(t.contains("https://a.com,\"\",140,m")) } else { fatalError() }

        assert(fallbackSites(defaultZoom: 1.5)[0].zoom == 1.5)  // 기본 목록이 없을 때도 기본 확대% (OPT-R3)

        // 주소와 이름이 같아도 확대%가 다르면 복원에서 둘 다 남는다 (OPT-R1)
        guard case .success(let same) = importCSV(Data("# v2\nhttps://g.com,\"GeekNews\",120\nhttps://g.com,\"GeekNews\",180\nhttps://g.com,\"GeekNews\",180\n".utf8)) else { fatalError() }
        assert(same.sites.map(\.zoom) == [1.2, 1.8] && Set(same.sites.map(\.id)).count == 2 && same.skipped == 1)

        // IPD: 사이트별 데스크톱 레이아웃. 이전에 저장된 목록(desktop 키 없음)도 읽히고 기본은 모바일 (IPD-Q5)
        let oldJSON = #"[{"id":"11111111-1111-1111-1111-111111111111","name":"옛","url":"https://old.com","zoom":1.4}]"#
        let oldDecoded = try JSONDecoder().decode([Site].self, from: Data(oldJSON.utf8))
        assert(oldDecoded.count == 1 && oldDecoded[0].name == "옛" && oldDecoded[0].zoom == 1.4 && !oldDecoded[0].desktop)
        var dsite = oldDecoded[0]; dsite.desktop = true
        let dback = try JSONDecoder().decode([Site].self, from: JSONEncoder().encode([dsite]))
        assert(dback[0].desktop)  // 저장/읽기 왕복
        assert(customUserAgent(desktop: false) == nil && customUserAgent(desktop: true)!.contains("Macintosh") && !customUserAgent(desktop: true)!.contains("Mobile"))
        let (ud17, clean17) = fresh()
        defer { clean17() }
        let st17 = SiteStore(defaults: ud17, backup: .none, defaultPages: pages)
        st17.add(name: "D", url: url("https://d.example"), desktop: true)
        st17.add(name: "M", url: url("https://m.example"))
        assert(st17.sites[st17.sites.count - 2].desktop && !st17.sites.last!.desktop && st17.sites[0].desktop == false)
        st17.setDesktop(st17.sites[0].id, true)
        assert(SiteStore(defaults: ud17, backup: .none, defaultPages: pages).sites[0].desktop)  // 재실행 후에도
        var ed17 = st17.sites[0]; ed17.desktop = false; st17.update(ed17)
        assert(!st17.sites[0].desktop)
        // CSV v3: 레이아웃 칸 왕복, v2는 칸이 있어도 무시, device 헤더, 파일 이름 보조 (IPD-Q6/Q7)
        let lay = [Site(name: "", url: url("https://a.com"), zoom: 1.2, desktop: true), Site(name: "B", url: url("https://b.com"), zoom: 1.0, desktop: false)]
        let v3 = exportCSV(lay, device: .ipad)
        assert(v3.hasPrefix("# v3\n# device: ipad\n") && v3.contains("https://a.com,\"\",120,d\n") && v3.contains("https://b.com,\"B\",100,m\n"))
        guard case .success(let v3i) = importCSV(Data(v3.utf8)) else { fatalError() }
        assert(v3i.sites.map(\.desktop) == [true, false] && v3i.device == .ipad && csvVersion(v3) == 3)
        guard case .success(let v2i) = importCSV(Data("# v2\nhttps://a.com,\"x\",120,d\n".utf8)) else { fatalError() }
        assert(!v2i.sites[0].desktop && v2i.sites[0].zoom == 1.2 && v2i.device == nil)
        assert(importCSV(Data(exportCSV(lay).utf8)).map { $0.device } == .success(nil))  // 기기를 모르면 헤더 없음
        assert(csvDevice("# v3\n# device: IPAD \nhttps://a.com") == .ipad && csvDevice("# device: tv\nhttps://a.com") == nil && csvDevice("https://a.com\n# device: ipad") == nil)
        assert(csvDevice("# device: tv\n# device: ipad\nhttps://a.com") == .ipad)  // 잘못된 값이 뒤의 유효한 헤더를 가리지 않는다 (IPD-R5)
        assert(backupFileName(date: "2026-11-21") == "cwv_sites_2026-11-21")  // 기기 표시는 파일 안 헤더만 (파일 이름에 붙이지 않는다)
        assert(withoutDesktop(lay).allSatisfy { !$0.desktop } && withoutDesktop(lay).map(\.zoom) == [1.2, 1.0])
        // 데스크톱 설정을 빼면 같아지는 항목은 합친다 (IPD-R3)
        let pair = [Site(name: "G", url: url("https://g.com"), zoom: 1.2, desktop: false), Site(name: "G", url: url("https://g.com"), zoom: 1.2, desktop: true), Site(name: "G", url: url("https://g.com"), zoom: 1.5, desktop: true)]
        assert(withoutDesktop(pair).map(\.zoom) == [1.2, 1.5] && withoutDesktop(pair).allSatisfy { !$0.desktop })
        // 주소/이름/확대%가 같아도 레이아웃이 다르면 둘 다 남는다
        guard case .success(let lay2) = importCSV(Data("# v3\nhttps://g.com,\"G\",120,m\nhttps://g.com,\"G\",120,d\nhttps://g.com,\"G\",120,d\n".utf8)) else { fatalError() }
        assert(lay2.sites.map(\.desktop) == [false, true] && lay2.skipped == 1)

        // SPL: 사이드바 너비 범위 (SPL-Q4)
        assert(clampSidebarWidth(320, total: 1000) == 320 && clampSidebarWidth(100, total: 1000) == 240 && clampSidebarWidth(9999, total: 2000) == 480)
        assert(clampSidebarWidth(480, total: 800) == 400 && clampSidebarWidth(320, total: 500) == 250)  // 창이 줄면 표시만 줄인다
        assert(clampSidebarWidth(320, total: 300) == 240)  // 아주 좁아도 최소는 지킨다
        // SPL: 레이아웃 헤더 왕복, 잘못된 값 무시, 범위 자르기 (SPL-Q5)
        let sl = SidebarLayout(side: .trailing, width: 360, hidden: true)
        let sv = exportCSV(lay, device: .ipad, layout: sl)
        assert(sv.hasPrefix("# v3\n# device: ipad\n# sidebar-side: trailing\n# sidebar-width: 360\n# sidebar-hidden: 1\n"))
        assert(csvSidebar(sv) == SidebarLayout.Partial(side: .trailing, width: 360, hidden: true))
        guard case .success(let svi) = importCSV(Data(sv.utf8)) else { fatalError() }
        assert(svi.sidebar == csvSidebar(sv) && svi.sites.map(\.desktop) == [true, false] && svi.device == .ipad)  // 헤더가 있어도 사이트 해석은 같다
        assert(!exportCSV(lay, device: .ipad).contains("sidebar") && csvSidebar(exportCSV(lay, device: .ipad)).isEmpty)  // layout nil이면 헤더 없음
        assert(csvSidebar("# sidebar-side: middle\n# sidebar-width: abc\n# sidebar-hidden: 2\nhttps://a.com").isEmpty)
        assert(csvSidebar("# sidebar-width: 100\nhttps://a.com").width == 240 && csvSidebar("# sidebar-width: 9999\nhttps://a.com").width == 480)
        assert(csvSidebar("# sidebar-width: abc\n# sidebar-width: 300\n# SIDEBAR-SIDE: Trailing\nhttps://a.com") == SidebarLayout.Partial(side: .trailing, width: 300, hidden: nil))  // 잘못된 값은 건너뛰고 대소문자 무시
        assert(csvSidebar("https://a.com\n# sidebar-side: trailing").isEmpty)  // 데이터 줄 뒤의 헤더는 무시
        assert(exportCSV(lay, layout: SidebarLayout(side: .leading, width: 9999, hidden: false)).contains("# sidebar-width: 480\n"))
        assert(csvSidebar(sv).summary == "위치, 너비, 숨김" && csvSidebar("# sidebar-hidden: 1\nhttps://a.com").summary == "숨김" && SidebarLayout.Partial().summary == "")  // 확인창 안내 (SPL-R5)
        guard case .success(let plain) = importCSV(Data(exportCSV(lay, device: .ipad).utf8)) else { fatalError() }
        assert(svi.sites == plain.sites)  // 레이아웃 헤더가 있어도 사이트의 모든 필드 해석이 같다
        let (ud18, clean18) = fresh()
        defer { clean18() }
        assert(SidebarLayout.load(ud18) == SidebarLayout())  // 기본값
        SidebarLayout.apply(SidebarLayout.Partial(side: .trailing, width: nil, hidden: true), to: ud18)
        assert(SidebarLayout.load(ud18) == SidebarLayout(side: .trailing, width: 320, hidden: true))  // 있는 키만 바뀐다
        SidebarLayout.apply(SidebarLayout.Partial(side: nil, width: 400, hidden: nil), to: ud18)
        assert(SidebarLayout.load(ud18) == SidebarLayout(side: .trailing, width: 400, hidden: true))  // 너비 쓰기/읽기 (SPL-R 리뷰: 빠져 있던 경로)

        // SWB: 분할 화면 웹 영역 스와이프. 웹 영역 전체에서 시작하되 구분선 쪽 20pt, 화면 끝 쪽 24pt는 비운다
        // 목록 왼쪽: 웹 x 332...1194 (폭 862, 오른쪽은 화면 끝) -> 시작 가능 [20, 838]
        func ps(_ sx: Double, minX: Double = 332, w: Double = 862, dx: Double, dy: Double = 5, vx: Double = 0) -> PaneSwipe? {
            paneSwipe(startX: sx, viewWidth: w, viewMinX: minX, screenWidth: 1194, dx: dx, dy: dy, vx: vx)
        }
        assert(ps(100, dx: 120) == .back && ps(420, dx: 120) == .back && ps(20, dx: 120) == .back)  // 영역 전체에서 오른쪽으로 = 뒤로
        assert(ps(420, dx: -120) == .forward && ps(838, dx: -120) == .forward && ps(100, dx: -120) == .forward)  // 왼쪽으로 = 앞으로
        assert(ps(19, dx: 120) == nil && ps(10, dx: -120) == nil)  // 구분선 쪽 20pt는 비움 (핸들 드래그와 겹치지 않게)
        assert(ps(839, dx: 120) == nil && ps(850, dx: -120) == nil)  // 화면 끝 쪽 24pt는 WebKit 기본 제스처
        // 목록 오른쪽: 웹 x 0...862 (왼쪽은 화면 끝) -> [24, 842]
        assert(ps(23, minX: 0, dx: 120) == nil && ps(24, minX: 0, dx: 120) == .back && ps(842, minX: 0, dx: -120) == .forward && ps(843, minX: 0, dx: -120) == nil)
        // 목록 숨김: 웹이 전체 폭 [24, 1170]
        assert(ps(10, minX: 0, w: 1194, dx: 120) == nil && ps(500, minX: 0, w: 1194, dx: 120) == .back && ps(1180, minX: 0, w: 1194, dx: -120) == nil)
        // 이동량/속도 기준 (천천히 밀어도 50pt, 또는 그 방향 300pt/s)
        assert(ps(100, dx: 30) == nil && ps(100, dx: 30, vx: 600) == .back)
        assert(ps(100, dx: 60) == .back && ps(100, dx: 40) == nil)
        assert(ps(100, dx: 20, vx: 350) == .back && ps(100, dx: 20, vx: 250) == nil)
        assert(ps(100, dx: 30, vx: -600) == nil && ps(500, dx: -30, vx: 600) == nil)  // 짧게 밀었다가 반대로 튕기면 취소 (D1)
        assert(ps(100, dx: 100, dy: 200) == nil && ps(500, dx: -100, dy: 200) == nil)  // 세로 우세는 스크롤
        // 시작 판단은 속도가 아니라 이동량(dx, dy)으로: 느리게 밀어 10pt 안팎일 때도 인식, 세로 스크롤과는 가로가 2배 이상 우세해야 구분
        assert(paneSwipeStarts(canBack: true, canForward: false, dx: 10, dy: 2) && !paneSwipeStarts(canBack: true, canForward: false, dx: -10, dy: 2))
        assert(paneSwipeStarts(canBack: false, canForward: true, dx: -10, dy: 2) && !paneSwipeStarts(canBack: false, canForward: true, dx: 10, dy: 2))
        assert(!paneSwipeStarts(canBack: true, canForward: false, dx: 5, dy: 20) && !paneSwipeStarts(canBack: false, canForward: false, dx: 10, dy: 0))
        assert(paneSwipeStarts(canBack: true, canForward: true, dx: 10, dy: 0) && paneSwipeStarts(canBack: true, canForward: true, dx: -10, dy: 0))
        assert(paneSwipeStarts(canBack: true, canForward: false, dx: 10, dy: 5) && !paneSwipeStarts(canBack: true, canForward: false, dx: 8, dy: 8))  // 대각선은 스크롤에 양보

        // JOY: 플로팅 버튼 조이스틱 (1cm = 60pt, 모서리 이동 = 180pt 가정)
        func fa(_ dx: Double, _ dy: Double) -> FabAction { fabAction(dx: dx, dy: dy, joystick: 60, move: 180) }
        assert(fa(-61, 5) == .back && fa(61, -5) == .forward && fa(5, -61) == .zoomIn && fa(-5, 61) == .zoomOut)  // 방향 (왼쪽 뒤로, 오른쪽 앞으로, 위 크게, 아래 작게)
        assert(fa(-59, 0) == .none && fa(0, -59) == .none && fa(0, 0) == .none && fa(10, -10) == .none)  // 1cm 미만, 돌아온 경우
        assert(fa(-60, 0) == .back && fa(0, 60) == .zoomOut)  // 경계는 포함
        assert(fa(60, 0) == .forward && fa(0, -60) == .zoomIn && fa(59, 0) == .none && fa(0, 59) == .none && fa(-59, 0) == .none && fa(0, -59) == .none)  // 네 방향 모두 59pt 미동작, 60pt 동작 (JOY-R5)
        assert(fa(-40, -61) == .zoomIn && fa(-70, -70) == .back && fa(70, 70) == .forward)  // 대각선: 더 많이 움직인 축, 같으면 가로
        assert(fa(179, 0) == .forward && fa(180, 0) == .move && fa(130, 130) == .move && fa(100, 100) == .forward)  // 모서리 이동 경계 (거리 기준)
        assert(fa(-180, 0) == .move && fa(0, -200) == .move)
        assert(joystickDistance(isPad: true) == 16 && joystickDistance(isPad: false) == 18)  // 약 0.3cm
        assert(fabMoveDistance(isPad: true) == 78 && fabMoveDistance(isPad: false) == 90)  // 약 1.5cm
        assert(fabMoveDistance(isPad: false) > joystickDistance(isPad: false) * 3 && fabMoveDistance(isPad: true) > joystickDistance(isPad: true) * 3)  // 조이스틱 구간이 충분히 남는다
        assert(fabIsTap(maxDisplacement: 0) && fabIsTap(maxDisplacement: 7.9) && !fabIsTap(maxDisplacement: 8) && !fabIsTap(maxDisplacement: 200))  // 탭/끌기 구분 (끌었다 돌아온 경우는 최대 거리로 판단)
        // SNS: 조이스틱 감도 (cm 설정). 기본 0.3cm에서는 이전 상수와 같아야 한다
        assert(clampJoystickCm(0.3) == 0.3 && clampJoystickCm(.nan) == 0.3 && clampJoystickCm(.infinity) == 0.3 && clampJoystickCm(-.infinity) == 0.3)
        assert(clampJoystickCm(-5) == 0.2 && clampJoystickCm(0.1) == 0.2 && clampJoystickCm(9) == 1.0 && clampJoystickCm(1.0) == 1.0 && clampJoystickCm(0.2) == 0.2)
        assert(clampJoystickCm(0.33) == 0.35 && clampJoystickCm(0.31) == 0.3 && clampJoystickCm(0.425) == 0.45)  // 0.05 단위
        assert(joystickDistance(isPad: false, cm: 0.2) == 12 && joystickDistance(isPad: true, cm: 0.2) == 10)  // 가장 민감
        assert(fabMoveDistance(isPad: false, cm: 0.2) == 60 && fabMoveDistance(isPad: true, cm: 0.2) == 52)
        assert(joystickDistance(isPad: false, cm: 1.0) == 60 && joystickDistance(isPad: true, cm: 1.0) == 52)  // 가장 둔감
        assert(fabMoveDistance(isPad: false, cm: 1.0) == 300 && fabMoveDistance(isPad: true, cm: 1.0) == 260)
        assert(joystickDistance(isPad: false, cm: 0.6) == 36 && fabMoveDistance(isPad: false, cm: 0.6) == 180 && joystickDistance(isPad: false, cm: .nan) == 18)
        for isPad in [false, true] {
            var prev = 0.0
            for i in 4...20 {  // 0.20 ... 1.00cm, 0.05 단위 전체
                let cm = Double(i) / 20
                let j = joystickDistance(isPad: isPad, cm: cm), mv = fabMoveDistance(isPad: isPad, cm: cm)
                assert(j > fabTapSlop && j >= prev && abs(mv - 5 * j) <= 2.5)  // 탭 판정(8pt)보다 크고, 단조 증가, 이동은 약 5배
                let m = fabMargin(joystick: j, fab: 44)
                assert(m + 44 / 2 >= j + 16 && m >= 16)  // 버튼 중심에서 끝까지 거리 >= 조이스틱 거리 + 16pt가 범위 전체에서 유지
                prev = j
            }
        }
        // JOY-R1: 버튼 중심에서 어느 끝까지든 조이스틱 거리 이상 남아야 끝쪽 방향 동작이 가능하다
        for isPad in [false, true] {
            let j = joystickDistance(isPad: isPad), m = fabMargin(joystick: j, fab: 44)
            assert(m + 44 / 2 >= j + 16 && m >= 16)  // 중심까지 거리 >= 조이스틱 거리 + 16pt, 기본 여백(16pt) 이상
        }
        assert(fabMargin(joystick: 60, fab: 44) == 54 && fabMargin(joystick: 52, fab: 44) == 46)  // 거리가 길면 여백이 늘고
        assert(fabMargin(joystick: 18, fab: 44) == 16 && fabMargin(joystick: 16, fab: 44) == 16)  // 0.3cm에서는 기본 여백 그대로
        assert(FabCorner.allCases.count == 4 && Set(FabCorner.allCases.map(\.title)).count == 4)

        // JSON 왕복
        let back = try JSONDecoder().decode([Site].self, from: JSONEncoder().encode(pages))
        assert(back == pages)

        print("test_site: OK")
    }
}

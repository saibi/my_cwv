import Foundation
import SwiftUI

/// 사용자 데이터를 앱 삭제 후에도 남기는 보조 저장소 (실제로는 Backup.swift의 Keychain).
struct KeyValueBackup {
    var save: (Data) -> Void
    var load: () -> Data?
    static let none = KeyValueBackup(save: { _ in }, load: { nil })
}

/// 저장되는 목록 (사이트별 글자 크기는 Site.zoom에 들어 있다).
private struct SiteList: Codable { var sites: [Site] }

/// 이전 버전(기본/사용자 분리)의 저장 형식. 마이그레이션에만 쓴다.
private struct LegacyUserData: Codable {
    var userSites: [Site]
    var defaultZooms: [String: Double]
}

/// default_page.csv(번들)를 읽는다. 없거나 유효한 줄이 없으면 Google 하나.
func bundledDefaultPages() -> [Site] {
    let text = Bundle.main.url(forResource: "default_page", withExtension: "csv")
        .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
    let sites = parseDefaultPages(text)
    return sites.isEmpty ? fallbackSites() : sites
}

final class SiteStore: ObservableObject {
    private let defaults: UserDefaults
    private let backup: KeyValueBackup
    private let defaultPages: [Site]
    /// 목록 하나. 첫 실행 때만 기본 목록으로 만들고, 그 뒤로는 앱이 건드리지 않는다.
    @Published var sites: [Site] { didSet { save() } }
    /// 사이트 id -> 첫 페이지에서 받은 타이틀 (캐시. 앱을 다시 실행해도 유지, Keychain 백업은 안 함)
    @Published private(set) var pageTitles: [String: String] {
        didSet { defaults.set(pageTitles, forKey: "pageTitles") }
    }
    @Published var lastSiteID: UUID? {
        didSet { defaults.set(lastSiteID?.uuidString, forKey: "lastSiteID") }
    }

    init(defaults: UserDefaults = .standard, backup: KeyValueBackup = .none, defaultPages: [Site] = bundledDefaultPages()) {
        self.defaults = defaults
        self.backup = backup
        self.defaultPages = defaultPages
        pageTitles = defaults.dictionary(forKey: "pageTitles") as? [String: String] ?? [:]
        let decoder = JSONDecoder()
        func list(_ d: Data?) -> [Site]? { d.flatMap { try? decoder.decode(SiteList.self, from: $0) }?.sites }
        func legacy(_ d: Data?) -> LegacyUserData? { d.flatMap { try? decoder.decode(LegacyUserData.self, from: $0) } }
        // 이전 버전은 이름을 비우면 도메인을 이름으로 저장했다. 그런 사이트는 자동 이름("")으로 되돌린다.
        func clean(_ s: Site) -> Site { var s = s; if s.name == s.url.host { s.name = "" }; return s }
        let kc = backup.load()
        // 우선순위: 저장된 목록(UserDefaults -> Keychain) -> 이전 형식 마이그레이션 -> 첫 실행(기본 목록)
        if let saved = list(defaults.data(forKey: "siteList")) ?? list(kc) {
            sites = saved
        } else if let u = legacy(defaults.data(forKey: "userData")) ?? legacy(kc) {
            // 기본/사용자 분리 형식: 화면에 보이던 순서(기본 항목 다음 사용자 사이트)로 이어 붙인다
            sites = defaultPages.map { var s = $0; s.zoom = u.defaultZooms[s.id.uuidString] ?? 1.0; return s } + u.userSites.map(clean)
        } else if let old = defaults.data(forKey: "sites").flatMap({ try? decoder.decode([Site].self, from: $0) }) {
            sites = old.map(clean)
        } else {
            sites = defaultPages
        }
        lastSiteID = defaults.string(forKey: "lastSiteID").flatMap(UUID.init)
        save()  // 복원/마이그레이션/최초 생성 결과를 두 저장소에 맞춘다
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(SiteList(sites: sites)) else { return }
        defaults.set(data, forKey: "siteList")
        backup.save(data)
    }

    /// 목록에 보일 이름.
    func title(for site: Site) -> String { site.displayName(cached: pageTitles[site.id.uuidString]) }

    func setPageTitle(_ id: UUID, _ raw: String) {
        guard let t = usableTitle(raw), pageTitles[id.uuidString] != t else { return }
        pageTitles[id.uuidString] = t
    }

    func add(name: String, url: URL) {
        sites.append(Site(name: name, url: url))
    }

    func update(_ site: Site) {
        guard let i = sites.firstIndex(where: { $0.id == site.id }) else { return }
        if sites[i].url != site.url {
            WebCache.drop(site.id)
            pageTitles[site.id.uuidString] = nil  // 다른 사이트가 되었으니 이전 사이트의 제목은 버린다
        }
        sites[i] = site
    }

    func remove(at offsets: IndexSet) {
        offsets.forEach { WebCache.drop(sites[$0].id) }
        sites.remove(atOffsets: offsets)
    }

    func setZoom(_ id: UUID, _ zoom: Double) {
        guard let i = sites.firstIndex(where: { $0.id == id }) else { return }
        sites[i].zoom = clampZoom(zoom)
    }

    /// 목록 전체를 바꾼다 (초기화, CSV 복원). 열려 있던 웹뷰는 모두 버린다.
    func replace(with new: [Site]) {
        sites.forEach { WebCache.drop($0.id) }
        sites = new
    }

    /// 앱에 들어 있는 기본 목록으로 되돌린다 (글자 크기는 100%).
    func reset() { replace(with: defaultPages) }
}

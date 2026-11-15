import Foundation
import SwiftUI

/// 사용자 데이터를 앱 삭제 후에도 남기는 보조 저장소 (실제로는 Backup.swift의 Keychain).
struct KeyValueBackup {
    var save: (Data) -> Void
    var load: () -> Data?
    static let none = KeyValueBackup(save: { _ in }, load: { nil })
}

/// 저장되는 사용자 데이터: 직접 추가한 사이트 + 기본 사이트별 글자 크기.
private struct UserData: Codable {
    var userSites: [Site]
    var defaultZooms: [String: Double]  // 기본 사이트 id -> 글자 크기
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
    let defaultPages: [Site]
    @Published var userSites: [Site] { didSet { save() } }
    @Published private var defaultZooms: [String: Double] { didSet { save() } }
    /// 사이트 id -> 첫 페이지에서 받은 타이틀 (캐시. 앱을 다시 실행해도 유지, Keychain 백업은 안 함)
    @Published private(set) var pageTitles: [String: String] {
        didSet { defaults.set(pageTitles, forKey: "pageTitles") }
    }
    @Published var lastSiteID: UUID? {
        didSet { defaults.set(lastSiteID?.uuidString, forKey: "lastSiteID") }
    }

    /// 화면에 보이는 전체 목록: 기본 사이트(CSV) 다음에 사용자 사이트.
    var sites: [Site] {
        defaultPages.map { var s = $0; s.zoom = defaultZooms[s.id.uuidString] ?? 1.0; return s } + userSites
    }

    init(defaults: UserDefaults = .standard, backup: KeyValueBackup = .none, defaultPages: [Site] = bundledDefaultPages()) {
        self.defaults = defaults
        self.backup = backup
        self.defaultPages = defaultPages
        pageTitles = defaults.dictionary(forKey: "pageTitles") as? [String: String] ?? [:]
        let decoder = JSONDecoder()
        func decode(_ d: Data?) -> UserData? { d.flatMap { try? decoder.decode(UserData.self, from: $0) } }
        var restoredLast = defaults.string(forKey: "lastSiteID").flatMap(UUID.init)
        // 우선순위: UserDefaults -> Keychain 백업(앱 삭제 후 재설치, UserDefaults가 깨졌을 때) -> 이전 버전의 단일 목록(마이그레이션)
        if let u = decode(defaults.data(forKey: "userData")) ?? decode(backup.load()) {
            userSites = u.userSites
            defaultZooms = u.defaultZooms
        } else if let old = defaults.data(forKey: "sites").flatMap({ try? decoder.decode([Site].self, from: $0) }) {
            let byURL = Dictionary(defaultPages.map { ($0.url, $0.id) }, uniquingKeysWith: { a, _ in a })
            userSites = old.filter { byURL[$0.url] == nil }
            defaultZooms = Dictionary(old.compactMap { s in byURL[s.url].map { ($0.uuidString, s.zoom) } }, uniquingKeysWith: { a, _ in a })
            // 이전 기본 사이트는 임의 id였으므로, 마지막으로 연 사이트가 그것이면 새 고정 id로 바꾼다
            if let last = old.first(where: { $0.id == restoredLast }), let new = byURL[last.url] { restoredLast = new }
        } else {
            userSites = []
            defaultZooms = [:]
        }
        lastSiteID = restoredLast
        save()  // 복원/마이그레이션 결과를 두 저장소에 맞춘다
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(UserData(userSites: userSites, defaultZooms: defaultZooms)) else { return }
        defaults.set(data, forKey: "userData")
        backup.save(data)
    }

    /// 목록에 보일 이름.
    func title(for site: Site) -> String { site.displayName(cached: pageTitles[site.id.uuidString]) }

    func setPageTitle(_ id: UUID, _ raw: String) {
        guard let t = usableTitle(raw), pageTitles[id.uuidString] != t else { return }
        pageTitles[id.uuidString] = t
    }

    func add(name: String, url: URL) {
        userSites.append(Site(name: name, url: url))
    }

    /// 사용자 사이트만 편집할 수 있다 (기본 사이트는 CSV에서 고친다).
    func update(_ site: Site) {
        guard let i = userSites.firstIndex(where: { $0.id == site.id }) else { return }
        if userSites[i].url != site.url { WebCache.drop(site.id) }
        userSites[i] = site
    }

    /// offsets는 userSites 기준.
    func remove(at offsets: IndexSet) {
        offsets.forEach { WebCache.drop(userSites[$0].id) }
        userSites.remove(atOffsets: offsets)
    }

    func setZoom(_ id: UUID, _ zoom: Double) {
        let z = clampZoom(zoom)
        if let i = userSites.firstIndex(where: { $0.id == id }) {
            userSites[i].zoom = z
        } else if defaultPages.contains(where: { $0.id == id }) {
            defaultZooms[id.uuidString] = z
        }
    }
}

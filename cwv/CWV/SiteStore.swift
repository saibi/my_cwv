import Foundation
import SwiftUI

final class SiteStore: ObservableObject {
    private let defaults: UserDefaults
    @Published var sites: [Site] { didSet { save() } }
    @Published var lastSiteID: UUID? {
        didSet { defaults.set(lastSiteID?.uuidString, forKey: "lastSiteID") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "sites"),
           let saved = try? JSONDecoder().decode([Site].self, from: data) {
            sites = saved
        } else {
            sites = defaultSites()
        }
        lastSiteID = defaults.string(forKey: "lastSiteID").flatMap(UUID.init)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(sites) { defaults.set(data, forKey: "sites") }
    }

    func add(name: String, url: URL) {
        sites.append(Site(name: name, url: url))
    }

    func update(_ site: Site) {
        guard let i = sites.firstIndex(where: { $0.id == site.id }) else { return }
        if sites[i].url != site.url { WebCache.drop(site.id) }
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
}

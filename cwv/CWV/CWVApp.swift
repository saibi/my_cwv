import SwiftUI

@main
struct CWVApp: App {
    @StateObject private var store = SiteStore(backup: .keychain)
    @State private var currentID: UUID?
    @State private var restored = false

    var body: some Scene {
        WindowGroup {
            Group {
                if let site = store.sites.first(where: { $0.id == currentID }) {
                    BrowserView(site: site) {
                        withAnimation(.easeInOut(duration: 0.25)) { currentID = nil }
                        store.lastSiteID = nil
                    }
                    .transition(.move(edge: .trailing))
                } else {
                    SiteListView { open($0) }
                        .transition(.move(edge: .leading))
                }
            }
            .environmentObject(store)
            .onAppear {
                guard !restored else { return }
                restored = true
                if let id = store.lastSiteID, store.sites.contains(where: { $0.id == id }) { currentID = id }
            }
        }
    }

    private func open(_ site: Site) {
        withAnimation(.easeInOut(duration: 0.25)) { currentID = site.id }
        store.lastSiteID = site.id
    }
}

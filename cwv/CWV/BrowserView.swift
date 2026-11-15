import SwiftUI

private struct ExternalLink: Identifiable {
    let url: URL
    var id: URL { url }
}

struct BrowserView: View {
    @EnvironmentObject var store: SiteStore
    let site: Site
    let onClose: () -> Void
    @State private var external: ExternalLink?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            WebView(site: site) { external = ExternalLink(url: $0) }
            menu.padding(16)
        }
        .sheet(item: $external) { SafariView(url: $0.url).ignoresSafeArea() }
    }

    private var menu: some View {
        Menu {
            Button("A+  크게") { store.setZoom(site.id, site.zoom + 0.1) }
            Button("A-  작게") { store.setZoom(site.id, site.zoom - 0.1) }
            Button("100%로") { store.setZoom(site.id, 1.0) }
            Text("현재 \(Int((site.zoom * 100).rounded()))%")
            Divider()
            Button("목록으로", action: onClose)
        } label: {
            Text("aA")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .opacity(0.85)
        }
    }
}

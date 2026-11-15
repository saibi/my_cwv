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

    @AppStorage("fabCorner") private var corner = FabCorner.bottomTrailing
    @State private var drag = CGSize.zero
    private let margin: CGFloat = 16, fab: CGFloat = 44

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: alignment) {
                WebView(site: site) { external = ExternalLink(url: $0) }
                menu.padding(margin).offset(drag)
                    .simultaneousGesture(DragGesture(minimumDistance: 8)
                        .onChanged { drag = $0.translation }
                        .onEnded { v in
                            // 놓은 위치(버튼 중심)에서 가장 가까운 모서리로 스냅한다.
                            let c = center(corner, in: g.size)
                            let p = CGPoint(x: c.x + v.translation.width, y: c.y + v.translation.height)
                            withAnimation { corner = .nearest(to: p, in: g.size); drag = .zero }
                        })
            }
        }
        .sheet(item: $external) { SafariView(url: $0.url).ignoresSafeArea() }
    }

    private var alignment: Alignment {
        switch corner {
        case .topLeading: return .topLeading
        case .topTrailing: return .topTrailing
        case .bottomLeading: return .bottomLeading
        case .bottomTrailing: return .bottomTrailing
        }
    }

    private func center(_ c: FabCorner, in size: CGSize) -> CGPoint {
        let o = margin + fab / 2
        let leading = c == .topLeading || c == .bottomLeading, top = c == .topLeading || c == .topTrailing
        return CGPoint(x: leading ? o : size.width - o, y: top ? o : size.height - o)
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
            AppGlyph()
                .foregroundStyle(.primary)
                .padding(10)
                .frame(width: fab, height: fab)
                .background(.ultraThinMaterial, in: Circle())
                .opacity(0.85)
        }
        .accessibilityLabel("글자 크기 및 목록 메뉴")
    }
}

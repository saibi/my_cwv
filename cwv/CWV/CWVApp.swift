import SwiftUI

@main
struct CWVApp: App {
    @StateObject private var store = SiteStore(backup: .keychain)

    var body: some Scene {
        WindowGroup { RootView().environmentObject(store) }
    }
}

private struct RootView: View {
    @EnvironmentObject var store: SiteStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var currentID: UUID?
    @State private var restored = false
    @AppStorage(SidebarKey.side) private var side = SidebarSide.leading
    @AppStorage(SidebarKey.width) private var width = sidebarDefaultWidth
    @AppStorage(SidebarKey.hidden) private var hidden = false
    @State private var dragWidth: Double?  // 드래그 중에만 쓰는 임시 너비 (끝나면 저장)

    /// 넓은 iPad 창에서만 목록과 웹을 같이 보인다 (SPL-Q2). iPhone은 가로 Max에서도 지금처럼 전환한다 (위치 설정이 iPad 옵션에만 있다).
    private var split: Bool { sizeClass == .regular && UIDevice.current.userInterfaceIdiom == .pad }
    private var currentSite: Site? { store.sites.first { $0.id == currentID } }

    var body: some View {
        Group { if split { splitView } else { stackView } }
            .onAppear {
                guard !restored else { return }
                restored = true
                if let id = store.lastSiteID, store.sites.contains(where: { $0.id == id }) { currentID = id }
            }
    }

    private var stackView: some View {
        Group {
            if let site = currentSite {
                BrowserView(site: site, onClose: {
                    withAnimation(.easeInOut(duration: 0.25)) { currentID = nil }
                    store.lastSiteID = nil
                })
                .transition(.move(edge: .trailing))
            } else {
                SiteListView(onOpen: open).transition(.move(edge: .leading))
            }
        }
    }

    private var splitView: some View {
        GeometryReader { g in
            let w = clampSidebarWidth(dragWidth ?? width, total: g.size.width)
            // 고른 사이트가 없으면 목록을 숨길 수 없다 (다시 열 길이 없다).
            let showList = !hidden || currentSite == nil
            let list = SiteListView(onOpen: open, selectedID: currentID, onHide: currentSite == nil ? nil : toggleHidden).frame(width: w)
            HStack(spacing: 0) {
                if !showList { detail }
                else if side == .leading { list; handle(w, total: g.size.width); detail }
                else { detail; handle(w, total: g.size.width); list }
            }
        }
    }

    @ViewBuilder private var detail: some View {
        if let site = currentSite {
            BrowserView(site: site, closeTitle: hidden ? "목록 보이기" : "목록 숨기기", onClose: toggleHidden,
                        onSwipe: { if hidden && side == .leading { toggleHidden() } })  // 목록이 보이는데 스와이프로 닫히면 실수 동작이다
                .id(site.id)  // 사이트가 바뀌면 웹뷰 보유자(Coordinator)도 새로 만든다
        } else {
            Text("목록에서 사이트를 고르세요").foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(.systemGroupedBackground))
        }
    }

    /// 목록과 웹 사이의 경계. 끌어서 너비를 바꾼다 (전역 좌표 기준이라 경계가 움직여도 값이 튀지 않는다).
    private func handle(_ w: Double, total: Double) -> some View {
        ZStack {
            Rectangle().fill(Color(.separator)).frame(width: 1)
            Capsule().fill(Color.secondary.opacity(0.6)).frame(width: 4, height: 36)
        }
        .frame(width: 12).frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { v in dragWidth = clampSidebarWidth(w + (side == .leading ? v.translation.width : -v.translation.width), total: total) }
            .onEnded { _ in if let d = dragWidth { width = d }; dragWidth = nil })
    }

    private func toggleHidden() { withAnimation(.easeInOut(duration: 0.25)) { hidden.toggle() } }

    private func open(_ site: Site) {
        withAnimation(.easeInOut(duration: 0.25)) { currentID = site.id }
        store.lastSiteID = site.id
    }
}

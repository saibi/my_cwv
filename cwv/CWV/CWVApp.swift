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
    @State private var dragStart: Double?  // 드래그를 시작한 순간의 표시 너비 (누적 이동량을 더할 기준)
    @GestureState private var dragging = false  // 드래그가 끝나거나 취소되면 자동으로 false

    private enum Pane { case list, handle, detail }

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
            // 좌우 순서가 바뀌어도 같은 뷰로 이어지도록 ForEach의 id로 구분한다 (위치로 구분하면 옵션 시트가 열린 채 위치를 바꿀 때 목록이 새로 만들어져 시트가 닫힌다).
            let order: [Pane] = !showList ? [.detail] : side == .leading ? [.list, .handle, .detail] : [.detail, .handle, .list]
            HStack(spacing: 0) {
                ForEach(order, id: \.self) { pane in
                    switch pane {
                    case .list: SiteListView(onOpen: open, selectedID: currentID, onHide: currentSite == nil ? nil : toggleHidden).frame(width: w)
                    case .handle: handle(w, total: g.size.width)
                    case .detail: detail
                    }
                }
            }
            .onChange(of: dragging) { _, now in
                if !now { if let d = dragWidth { width = d }; dragWidth = nil; dragStart = nil }  // 끝났거나 취소됐을 때 마지막 너비를 저장
            }
        }
        .onDisappear { dragWidth = nil; dragStart = nil }  // 드래그 중 창이 좁아져 분할이 풀려도 임시값이 남지 않게
    }

    @ViewBuilder private var detail: some View {
        if let site = currentSite {
            BrowserView(site: site, closeTitle: hidden ? "목록 보이기" : "목록 숨기기", onClose: toggleHidden,
                        onSwipe: { if hidden && side == .leading { toggleHidden() } })  // 목록이 보이는데 스와이프로 닫히면 실수 동작이다
                // 사이트가 바뀌거나 캐시의 웹뷰가 교체되면(주소 편집, 목록 초기화/복원) 웹뷰 보유자(Coordinator)도 새로 만든다.
                .id(ObjectIdentifier(WebCache.view(for: site)))
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
            .updating($dragging) { _, s, _ in s = true }
            .onChanged { v in
                // translation은 시작부터의 누적 이동량이라, 기준 너비는 시작할 때 한 번만 잡는다 (w는 드래그 중에도 바뀐다).
                let base = dragStart ?? w
                dragStart = base
                dragWidth = clampSidebarWidth(base + (side == .leading ? v.translation.width : -v.translation.width), total: total)
            })
        .accessibilityElement()
        .accessibilityLabel("목록 너비")
        .accessibilityValue("\(Int(w))pt")
        .accessibilityAdjustableAction { dir in  // VoiceOver: 위로 쓸면 넓게, 아래로 쓸면 좁게
            width = clampSidebarWidth(w + (dir == .increment ? 20 : -20), total: total)
        }
    }

    private func toggleHidden() { withAnimation(.easeInOut(duration: 0.25)) { hidden.toggle() } }

    private func open(_ site: Site) {
        withAnimation(.easeInOut(duration: 0.25)) { currentID = site.id }
        store.lastSiteID = site.id
    }
}

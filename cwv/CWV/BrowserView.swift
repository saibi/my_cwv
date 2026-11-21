import SwiftUI

private struct ExternalLink: Identifiable {
    let url: URL
    var id: URL { url }
}

struct BrowserView: View {
    @EnvironmentObject var store: SiteStore
    let site: Site
    var closeTitle = "목록으로"  // 분할 화면에서는 "목록 숨기기"/"목록 보이기"
    let onClose: () -> Void
    var onSwipe: (() -> Void)?  // 첫 페이지 가장자리 스와이프 (없으면 onClose)
    var paneSwipe = false  // 분할 화면: 웹 영역 가장자리 스와이프로 뒤로/앞으로 (SWB)
    @State private var external: ExternalLink?

    @AppStorage("fabCorner") private var corner = FabCorner.bottomTrailing
    // 끄는 중의 이동량. @GestureState라 정상 종료뿐 아니라 시스템이 제스처를 취소해도 자동으로 0으로 돌아온다 (JOY-R2).
    @GestureState(resetTransaction: Transaction(animation: .easeOut(duration: 0.2))) private var drag = CGSize.zero
    @State private var toast: String?  // 놓은 뒤 결과 (1.2초)
    @State private var toastTask: DispatchWorkItem?
    private let fab: CGFloat = 44

    /// 약 1cm (JOY). 모서리 이동은 그 3배.
    private var joystick: Double { joystickDistance(isPad: UIDevice.current.userInterfaceIdiom == .pad) }
    /// 버튼은 화면 끝에서 1cm 이상 안쪽에 둔다. 끝에 붙이면 끝쪽 방향으로 끌 공간이 모자라 뒤로/앞으로/글자 작게 중 일부가 안 된다 (JOY-R1).
    private var margin: CGFloat { CGFloat(fabMargin(joystick: joystick, fab: Double(fab))) }

    var body: some View {
        GeometryReader { g in
            let live = action(drag)  // 지금 놓으면 일어날 동작
            ZStack(alignment: alignment) {
                WebView(site: site, onExternal: { external = ExternalLink(url: $0) }, onBack: onSwipe ?? onClose,
                        onTitle: { store.setPageTitle(site.id, $0) }, paneSwipe: paneSwipe)
                if live == .move {  // 놓으면 가는 모서리 표시
                    Circle().strokeBorder(Color.accentColor, lineWidth: 2).frame(width: fab, height: fab)
                        .position(center(target(drag, in: g.size), in: g.size)).allowsHitTesting(false)
                }
                menu.padding(margin).offset(drag)
                    .simultaneousGesture(DragGesture(minimumDistance: 8)
                        .updating($drag) { v, state, _ in state = v.translation }
                        .onChanged { _ in
                            // 새 조작이 시작되면 이전 결과 말풍선은 지운다 (JOY-R4)
                            if toast != nil { toastTask?.cancel(); toast = nil }
                        }
                        .onEnded { v in
                            // 손을 뗀 위치(실제 이동량)로만 판정한다. 튕기는 속도는 쓰지 않는다.
                            let a = action(v.translation)
                            let t = target(v.translation, in: g.size)
                            switch a {
                            case .back: navigate(forward: false)
                            case .forward: navigate(forward: true)
                            case .zoomIn: zoom(0.1)
                            case .zoomOut: zoom(-0.1)
                            case .move:
                                if t != corner { show("버튼 위치: \(t.title)") }
                                withAnimation { corner = t }
                            case .none: break  // 돌아온 경우 포함: 아무 일도 없고 메뉴도 열리지 않는다
                            }
                        })
            }
            // 말풍선은 손가락/버튼에 가리지 않게 웹 영역의 가로 중앙, 버튼의 반대쪽(위/아래) 끝에 둔다 (화면 밖으로 나가지 않음, JOY-R3).
            .overlay(alignment: buttonInLowerHalf(in: g.size) ? .top : .bottom) { bubble(live).padding(.vertical, 24) }
            .onChange(of: live) { _, new in if new != .none { UISelectionFeedbackGenerator().selectionChanged() } }
        }
        .sheet(item: $external) { SafariView(url: $0.url).ignoresSafeArea() }
    }

    /// 지금 버튼(끄는 중이면 손가락 위치)이 웹 영역의 아래쪽 절반에 있는지.
    private func buttonInLowerHalf(in size: CGSize) -> Bool {
        center(corner, in: size).y + drag.height > size.height / 2
    }

    private func action(_ t: CGSize) -> FabAction { fabAction(dx: t.width, dy: t.height, joystick: joystick, move: joystick * 3) }

    /// 놓은 위치에서 가장 가까운 모서리.
    private func target(_ t: CGSize, in size: CGSize) -> FabCorner {
        let c = center(corner, in: size)
        return .nearest(to: CGPoint(x: c.x + t.width, y: c.y + t.height), in: size)
    }

    private func navigate(forward: Bool) {
        let w = WebCache.view(for: site).web
        if forward ? w.canGoForward : w.canGoBack {
            if forward { w.goForward() } else { w.goBack() }
            show(forward ? "앞으로" : "뒤로")
        } else {
            show(forward ? "앞으로 갈 곳이 없습니다" : "뒤로 갈 곳이 없습니다")
        }
    }

    private func zoom(_ delta: Double) {
        let z = clampZoom(site.zoom + delta)
        store.setZoom(site.id, z)
        show("글자 \(Int((z * 100).rounded()))%")
    }

    /// 결과 말풍선을 1.2초 보인다. 연속 조작에서 이전 것이 새 것을 지우지 않게 취소 가능하게 둔다.
    private func show(_ text: String) {
        toastTask?.cancel()
        toast = text
        let t = DispatchWorkItem { toast = nil }
        toastTask = t
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: t)
    }

    /// 끄는 중에는 지금 놓으면 일어날 일, 놓은 뒤에는 결과.
    private func bubbleText(_ live: FabAction) -> String? {
        switch live {
        case .back: return "뒤로"
        case .forward: return "앞으로"
        case .zoomIn: return "크게 \(Int((clampZoom(site.zoom + 0.1) * 100).rounded()))%"
        case .zoomOut: return "작게 \(Int((clampZoom(site.zoom - 0.1) * 100).rounded()))%"
        case .move: return "여기로 이동"
        case .none: return toast
        }
    }

    @ViewBuilder private func bubble(_ live: FabAction) -> some View {
        if let text = bubbleText(live) {
            Text(text).font(.caption.weight(.semibold)).foregroundStyle(.white).fixedSize()
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(Color.black.opacity(0.75)))
                .allowsHitTesting(false)
        }
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
            Button("뒤로") { navigate(forward: false) }  // 조이스틱 조작이 어렵거나 VoiceOver일 때의 대안 (JOY-Q4)
            Button("앞으로") { navigate(forward: true) }
            Button(site.desktop ? "모바일 사이트로 보기" : "데스크톱 사이트로 보기") { store.setDesktop(site.id, !site.desktop) }
            Button("Safari에서 열기") {
                UIApplication.shared.open(safariTarget(current: WebCache.view(for: site).web.url, fallback: site.url))
            }
            Menu("버튼 위치") {
                ForEach(FabCorner.allCases, id: \.self) { c in
                    Button { withAnimation { corner = c } } label: {
                        if c == corner { Label(c.title, systemImage: "checkmark") } else { Text(c.title) }
                    }
                }
            }
            Divider()
            Button(closeTitle, action: onClose)
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

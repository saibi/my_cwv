import SwiftUI
import WebKit
import SafariServices
import UIKit.UIGestureRecognizerSubclass

/// 웹뷰 자신의 왼쪽/오른쪽 가장자리에서 시작하는 팬 (분할 화면의 뒤로/앞으로, SWB).
/// 시작 조건이 안 맞으면 touchesBegan에서 바로 실패해 웹뷰의 스크롤과 링크 탭을 지연시키지 않는다.
/// 웹뷰의 그쪽 끝이 화면 끝이면 WebKit 기본 제스처가 처리하므로 실패한다 (이중 이동 방지).
final class PaneEdgePan: UIPanGestureRecognizer {
    private(set) var startX = 0.0

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard let web = view as? WKWebView, let t = touches.first else { state = .failed; return }
        startX = t.location(in: web).x
        let frame = web.convert(web.bounds, to: nil)
        let screenW = web.window?.bounds.width ?? frame.maxX
        let back = web.canGoBack && startX <= paneSwipeEdge && frame.minX > 1
        let forward = web.canGoForward && startX >= web.bounds.width - paneSwipeEdge && screenW - frame.maxX > 1
        if !(back || forward) { state = .failed }
    }
}

/// 사이트 하나의 WKWebView와 delegate. 목록에 다녀와도 페이지와 스크롤이 유지되도록 캐시한다.
final class SiteWebView: NSObject, WKNavigationDelegate, WKUIDelegate, UIGestureRecognizerDelegate {
    let web: WKWebView
    var base: URL
    var onExternal: ((URL) -> Void)?
    var onBack: (() -> Void)?
    var onTitle: ((String) -> Void)?
    private var titleObs: NSKeyValueObservation?
    private let refresh = UIRefreshControl()

    /// 데스크톱 사이트로 볼지 (사이트 설정). 바뀌면 apply(desktop:)가 UA를 바꾸고 다시 불러온다.
    private(set) var desktop: Bool

    init(base: URL, desktop: Bool) {
        self.base = base
        self.desktop = desktop
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()  // 쿠키/로그인 유지
        // Safari처럼 보이게 한다. 기본 UA에는 Version/Safari 토큰이 없어 일부 사이트와 Cloudflare가 거부할 수 있다.
        config.applicationNameForUserAgent = "Version/18.0 Mobile/15E148 Safari/604.1"
        web = WKWebView(frame: .zero, configuration: config)
        web.customUserAgent = customUserAgent(desktop: desktop)  // 모바일이면 nil: 위의 기본 UA
        super.init()
        web.navigationDelegate = self
        web.uiDelegate = self
        web.allowsBackForwardNavigationGestures = true
        // 웹 기록이 없는 첫 페이지에서 왼쪽 가장자리 스와이프는 목록으로 간다 (기록이 있으면 WebKit의 뒤로가기가 먼저).
        let edge = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(edgePan(_:)))
        edge.edges = .left
        edge.delegate = self
        web.addGestureRecognizer(edge)
        // 분할 화면처럼 웹뷰 끝이 화면 끝이 아닐 때는 WebKit 기본 뒤로/앞으로 제스처가 닿지 않아 웹뷰 가장자리에서 직접 받는다 (SWB).
        let pane = PaneEdgePan(target: self, action: #selector(panePan(_:)))
        pane.maximumNumberOfTouches = 1
        pane.delegate = self
        web.addGestureRecognizer(pane)
        // 첫 페이지(웹 기록 없음)의 타이틀만 목록 이름 후보로 보고한다. 글 상세 제목이 사이트 이름이 되지 않게.
        titleObs = web.observe(\.title) { [weak self] _, _ in self?.reportTitle() }
        refresh.addTarget(self, action: #selector(reload), for: .valueChanged)
        web.scrollView.refreshControl = refresh
        // 광고 규칙 컴파일은 비동기라 끝난 뒤에 로드한다. 실패해도 광고만 보일 뿐 페이지는 열린다.
        AdBlock.load { [weak self] list in
            guard let self else { return }
            if let list { self.web.configuration.userContentController.add(list) }
            self.web.load(URLRequest(url: self.base))
        }
    }

    @objc private func reload() { web.reload() }

    @objc private func edgePan(_ g: UIScreenEdgePanGestureRecognizer) {
        guard g.state == .ended else { return }
        if shouldCloseOnEdgeSwipe(translation: g.translation(in: g.view).x, velocity: g.velocity(in: g.view).x) { onBack?() }
    }

    @objc private func panePan(_ g: PaneEdgePan) {
        guard g.state == .ended else { return }
        let p = g.translation(in: web), v = g.velocity(in: web)
        let frame = web.convert(web.bounds, to: nil)
        switch paneSwipe(startX: g.startX, viewWidth: web.bounds.width, viewMinX: frame.minX, screenWidth: Double(web.window?.bounds.width ?? frame.maxX),
                         dx: p.x, dy: p.y, vx: v.x) {
        case .back?: if web.canGoBack { web.goBack() }
        case .forward?: if web.canGoForward { web.goForward() }
        case nil: break
        }
    }

    func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        // 가장자리 팬은 가로가 우세할 때만 시작한다 (세로면 스크롤에 양보)
        if g is PaneEdgePan { let v = (g as! UIPanGestureRecognizer).velocity(in: web); return abs(v.x) > abs(v.y) }
        return !web.canGoBack
    }

    /// 콜백이 늦게 붙거나 캐시된 웹뷰가 다시 표시될 때도 호출한다. 뷰 갱신 중 상태를 바꾸지 않도록 다음 런루프에서 전달한다.
    func reportTitle() {
        guard web.backForwardList.backList.isEmpty, let t = usableTitle(web.title) else { return }
        DispatchQueue.main.async { [weak self] in self?.onTitle?(t) }
    }

    private var appliedZoom: Double?

    /// 글자 크기. pageZoom은 레이아웃이 다시 배치되지 않아 가로로 넘치므로(시뮬레이터 확인),
    /// Safari aA와 같은 text-size-adjust를 모든 페이지 시작 시 주입한다.
    func apply(zoom: Double) {
        guard zoom != appliedZoom else { return }
        appliedZoom = zoom
        let js = "(function(){var s=document.documentElement.style;s.webkitTextSizeAdjust=s.textSizeAdjust='\(Int((zoom * 100).rounded()))%';})();"
        let uc = web.configuration.userContentController
        uc.removeAllUserScripts()
        uc.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false))
        web.evaluateJavaScript(js)
    }

    /// 데스크톱/모바일 전환. UA와 콘텐츠 모드(decidePolicyFor)를 바꾸고 지금 주소를 새 모드로 GET으로 다시 불러온다.
    /// reload()는 마지막 요청을 재사용해서 POST 결과 화면이면 폼이 다시 전송되고(IPD-R1), 첫 접속이 실패한 상태면 재요청이 없다(IPD-R2).
    func apply(desktop new: Bool) {
        guard new != desktop else { return }
        desktop = new
        web.customUserAgent = customUserAgent(desktop: new)
        web.load(URLRequest(url: web.url ?? base))
    }

    func webView(_ w: WKWebView, didFinish navigation: WKNavigation!) { refresh.endRefreshing() }
    func webView(_ w: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { refresh.endRefreshing() }
    func webView(_ w: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { refresh.endRefreshing() }

    func webView(_ w: WKWebView, decidePolicyFor action: WKNavigationAction, preferences: WKWebpagePreferences,
                 decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        preferences.preferredContentMode = desktop ? .desktop : .mobile  // 기기 기본값(iPad는 데스크톱)이 아니라 사이트 설정을 따른다
        let decisionHandler = { (p: WKNavigationActionPolicy) in decisionHandler(p, preferences) }
        guard let url = action.request.url else { return decisionHandler(.allow) }
        switch url.scheme?.lowercased() ?? "" {
        case "http", "https":
            // 사용자가 직접 누른 외부 링크만 가로챈다. 리다이렉트와 OAuth 흐름은 그대로 둔다.
            if opensInSafariSheet(url, base: base, linkActivated: action.navigationType == .linkActivated) {
                onExternal?(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        case "about", "blob", "data":
            decisionHandler(.allow)
        default:  // tel:, mailto:, 앱 링크. 직접 누른 것만 열고, 클릭 없는 자동 이동은 막는다 (CWV-R4/D1)
            if action.navigationType == .linkActivated { UIApplication.shared.open(url) }
            decisionHandler(.cancel)
        }
    }

    // target=_blank, window.open: 같은 웹뷰에서 연다 (외부 도메인이면 Safari 시트)
    func webView(_ w: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url, url.scheme?.hasPrefix("http") == true {
            if opensInSafariSheet(url, base: base, linkActivated: action.navigationType == .linkActivated) {
                onExternal?(url)
            } else {
                w.load(action.request)
            }
        }
        return nil
    }

    // JavaScript alert/confirm/prompt. 구현하지 않으면 confirm/prompt는 항상 취소된다.
    private func present(_ alert: UIAlertController) {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.keyWindow?.rootViewController
        while let next = top?.presentedViewController { top = next }
        top?.present(alert, animated: true)
    }

    func webView(_ w: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "확인", style: .default) { _ in completionHandler() })
        present(a)
    }

    func webView(_ w: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "취소", style: .cancel) { _ in completionHandler(false) })
        a.addAction(UIAlertAction(title: "확인", style: .default) { _ in completionHandler(true) })
        present(a)
    }

    func webView(_ w: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let a = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        a.addTextField { $0.text = defaultText }
        a.addAction(UIAlertAction(title: "취소", style: .cancel) { _ in completionHandler(nil) })
        a.addAction(UIAlertAction(title: "확인", style: .default) { _ in completionHandler(a.textFields?.first?.text) })
        present(a)
    }
}

/// adblock.json(WebKit content rule)을 한 번만 컴파일해 모든 웹뷰가 공유한다.
enum AdBlock {
    private static var cached: WKContentRuleList?

    static func load(_ done: @escaping (WKContentRuleList?) -> Void) {
        if let cached { return done(cached) }
        guard let url = Bundle.main.url(forResource: "adblock", withExtension: "json"),
              let json = try? String(contentsOf: url, encoding: .utf8) else { return done(nil) }
        WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "adblock", encodedContentRuleList: json) { list, _ in
            cached = list
            done(list)
        }
    }
}

enum WebCache {
    private static var views: [UUID: SiteWebView] = [:]
    private static let observer = NotificationCenter.default.addObserver(
        forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
    ) { _ in views = views.filter { $0.value.web.window != nil } }  // ponytail: 메모리 경고 시 보이지 않는 웹뷰만 비운다. 표시 중인 것을 남겨야 Safari에서 열기 등이 같은 웹뷰를 읽는다

    static func view(for site: Site) -> SiteWebView {
        _ = observer
        if let v = views[site.id] { return v }
        let v = SiteWebView(base: site.url, desktop: site.desktop)
        views[site.id] = v
        return v
    }

    static func drop(_ id: UUID) { views[id] = nil }
}

struct WebView: UIViewRepresentable {
    let site: Site
    let onExternal: (URL) -> Void
    let onBack: () -> Void
    let onTitle: (String) -> Void

    // delegate는 WKWebView가 약하게만 잡으므로, 표시 중인 SiteWebView는 여기서 강하게 보유한다
    // (캐시가 메모리 경고로 비워져도 제어가 끊기지 않게).
    final class Coordinator { let holder: SiteWebView; init(_ h: SiteWebView) { holder = h } }

    func makeCoordinator() -> Coordinator { Coordinator(WebCache.view(for: site)) }

    func makeUIView(context: Context) -> WKWebView {
        sync(context.coordinator.holder)
        return context.coordinator.holder.web
    }

    func updateUIView(_ web: WKWebView, context: Context) { sync(context.coordinator.holder) }

    private func sync(_ v: SiteWebView) {
        v.onExternal = onExternal
        v.onBack = onBack
        v.onTitle = onTitle
        v.reportTitle()
        v.apply(zoom: site.zoom)
        v.apply(desktop: site.desktop)
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

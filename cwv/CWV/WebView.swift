import SwiftUI
import WebKit
import SafariServices

/// 사이트 하나의 WKWebView와 delegate. 목록에 다녀와도 페이지와 스크롤이 유지되도록 캐시한다.
final class SiteWebView: NSObject, WKNavigationDelegate, WKUIDelegate {
    let web: WKWebView
    var base: URL
    var onExternal: ((URL) -> Void)?
    private let refresh = UIRefreshControl()

    init(base: URL) {
        self.base = base
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()  // 쿠키/로그인 유지
        // Safari처럼 보이게 한다. 기본 UA에는 Version/Safari 토큰이 없어 일부 사이트와 Cloudflare가 거부할 수 있다.
        config.applicationNameForUserAgent = "Version/18.0 Mobile/15E148 Safari/604.1"
        web = WKWebView(frame: .zero, configuration: config)
        super.init()
        web.navigationDelegate = self
        web.uiDelegate = self
        web.allowsBackForwardNavigationGestures = true
        refresh.addTarget(self, action: #selector(reload), for: .valueChanged)
        web.scrollView.refreshControl = refresh
        web.load(URLRequest(url: base))
    }

    @objc private func reload() { web.reload() }

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

    func webView(_ w: WKWebView, didFinish navigation: WKNavigation!) { refresh.endRefreshing() }
    func webView(_ w: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { refresh.endRefreshing() }
    func webView(_ w: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { refresh.endRefreshing() }

    func webView(_ w: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
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

enum WebCache {
    private static var views: [UUID: SiteWebView] = [:]
    private static let observer = NotificationCenter.default.addObserver(
        forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
    ) { _ in views.removeAll() }  // ponytail: 메모리 경고 시 캐시를 비운다. 표시 중인 SiteWebView는 WebView.Coordinator가 붙잡고 있다

    static func view(for site: Site) -> SiteWebView {
        _ = observer
        if let v = views[site.id] { return v }
        let v = SiteWebView(base: site.url)
        views[site.id] = v
        return v
    }

    static func drop(_ id: UUID) { views[id] = nil }
}

struct WebView: UIViewRepresentable {
    let site: Site
    let onExternal: (URL) -> Void

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
        v.apply(zoom: site.zoom)
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}

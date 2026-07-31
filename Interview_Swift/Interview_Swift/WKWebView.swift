//
//  WKWebView.swift
//  Interview_Swift
//
//  Created by maochengfang on 2026/7/31.
//

import UIKit
import WebKit

// 统一抽象远程页面和本地 HTML，便于首页 Demo 复用同一个容器。
enum WebViewContentSource {
    case remoteURL(URL)
    case htmlString(String, baseURL: URL?)
}

struct WebViewPageConfiguration {
    let title: String
    let source: WebViewContentSource
    let businessId: String
    var timeoutInterval: TimeInterval = 20
    var jsBridgeName: String = "nativeBridge"
    var allowsBackForwardNavigationGestures: Bool = true
}

final class WKWebViewController: UIViewController {

    private let pageConfiguration: WebViewPageConfiguration
    private let userContentController = WKUserContentController()

    private lazy var webView: WebKit.WKWebView = {
        let webView = WebKit.WKWebView(frame: .zero, configuration: makeWebViewConfiguration())
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = pageConfiguration.allowsBackForwardNavigationGestures
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.backgroundColor = .systemBackground
        webView.isOpaque = false
        return webView
    }()

    private let progressView: UIProgressView = {
        let view = UIProgressView(progressViewStyle: .default)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.progress = 0
        view.isHidden = true
        return view
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .large)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.hidesWhenStopped = true
        return view
    }()

    private let errorStackView: UIStackView = {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        view.alignment = .center
        view.spacing = 12
        view.isHidden = true
        return view
    }()

    private let errorTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "页面加载失败"
        label.font = .boldSystemFont(ofSize: 18)
        label.textColor = .label
        return label
    }()

    private let errorMessageLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 0
        return label
    }()

    private lazy var retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.configuration = .filled()
        button.configuration?.title = "重新加载"
        button.addTarget(self, action: #selector(reloadPage), for: .touchUpInside)
        return button
    }()

    private var progressObservation: NSKeyValueObservation?
    private var titleObservation: NSKeyValueObservation?
    // WebContent 被系统回收时只自动拉起一次，避免无限 reload。
    private var hasReloadedAfterTermination = false

    init(configuration: WebViewPageConfiguration) {
        self.pageConfiguration = configuration
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        progressObservation?.invalidate()
        titleObservation?.invalidate()
        userContentController.removeScriptMessageHandler(forName: pageConfiguration.jsBridgeName)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = pageConfiguration.title
        view.backgroundColor = .systemBackground
        setupViews()
        setupNavigationItems()
        bindWebViewState()
        loadInitialRequest()
    }

    private func setupViews() {
        view.addSubview(webView)
        view.addSubview(progressView)
        view.addSubview(activityIndicator)
        view.addSubview(errorStackView)

        errorStackView.addArrangedSubview(errorTitleLabel)
        errorStackView.addArrangedSubview(errorMessageLabel)
        errorStackView.addArrangedSubview(retryButton)

        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            webView.topAnchor.constraint(equalTo: progressView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            errorStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorStackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            errorStackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),

            retryButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ])
    }

    private func setupNavigationItems() {
        let reloadItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(reloadPage)
        )
        navigationItem.rightBarButtonItem = reloadItem

        if presentingViewController != nil, navigationController?.viewControllers.first === self {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .close,
                target: self,
                action: #selector(closePage)
            )
        }
    }

    private func bindWebViewState() {
        // KVO 监听加载进度，比在 delegate 里手动维护更稳定。
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            guard let self else { return }
            let progress = Float(webView.estimatedProgress)
            self.progressView.isHidden = progress >= 1.0
            self.progressView.setProgress(progress, animated: true)
        }

        // 页面标题优先以 H5 title 为准，更接近真实业务容器行为。
        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] webView, _ in
            guard let self else { return }
            let newTitle = webView.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let newTitle, !newTitle.isEmpty {
                self.title = newTitle
            }
        }
    }

    private func makeWebViewConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.websiteDataStore = .default()
        configuration.applicationNameForUserAgent = "InterviewSwift/\(pageConfiguration.businessId)"

        // WKUserContentController 会强持有 handler，这里用弱代理规避循环引用。
        userContentController.add(
            WeakScriptMessageHandler(delegate: self),
            name: pageConfiguration.jsBridgeName
        )
        return configuration
    }

    private func loadInitialRequest() {
        hideError()
        activityIndicator.startAnimating()

        switch pageConfiguration.source {
        case .remoteURL(let url):
            // 面试场景里强调：容器层先做基础校验，非法 scheme 不要直接交给 WebView。
            guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
                showError(message: "仅支持加载 http/https 页面，当前 URL: \(url.absoluteString)")
                return
            }

            var request = URLRequest(url: url)
            request.timeoutInterval = pageConfiguration.timeoutInterval
            request.cachePolicy = .useProtocolCachePolicy
            request.setValue(pageConfiguration.businessId, forHTTPHeaderField: "X-Business-Id")
            webView.load(request)

        case .htmlString(let html, let baseURL):
            webView.loadHTMLString(html, baseURL: baseURL)
        }
    }

    private func showError(message: String) {
        errorMessageLabel.text = message
        errorStackView.isHidden = false
        webView.isHidden = true
        progressView.isHidden = true
        activityIndicator.stopAnimating()
    }

    private func hideError() {
        errorStackView.isHidden = true
        webView.isHidden = false
    }

    private func presentAlertOnTop(_ alert: UIAlertController) {
        if let presentedViewController {
            presentedViewController.present(alert, animated: true)
        } else {
            present(alert, animated: true)
        }
    }

    @objc
    private func reloadPage() {
        if webView.url == nil {
            loadInitialRequest()
            return
        }
        hideError()
        activityIndicator.startAnimating()
        webView.reload()
    }

    @objc
    private func closePage() {
        if let navigationController, navigationController.viewControllers.count > 1 {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    private func sendNativeJSONToH5() {
        let payload: [String: Any] = [
            "businessId": pageConfiguration.businessId,
            "platform": "iOS",
            "container": "WKWebView",
            "user": [
                "id": 10001,
                "name": "maochengfang",
                "role": "iOS Architect"
            ],
            "features": [
                "jsBridge",
                "target_blank",
                "error_retry",
                "process_recovery"
            ],
            "timestamp": Int(Date().timeIntervalSince1970)
        ]

        guard
            JSONSerialization.isValidJSONObject(payload),
            let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
            let jsonObjectString = String(data: data, encoding: .utf8)
        else {
            print("Native JSON 序列化失败，businessId=\(pageConfiguration.businessId)")
            return
        }

        let script = "window.renderNativeJSONFromNative(\(jsonObjectString));"
        webView.evaluateJavaScript(script) { _, error in
            if let error {
                print("Native -> H5 传递 JSON 失败，error=\(error.localizedDescription)")
            }
        }
    }
}

extension WKWebViewController: WKNavigationDelegate {

    func webView(_ webView: WebKit.WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        hideError()
        progressView.progress = 0
        progressView.isHidden = false
        activityIndicator.startAnimating()
    }

    func webView(_ webView: WebKit.WKWebView, didFinish navigation: WKNavigation!) {
        hasReloadedAfterTermination = false
        activityIndicator.stopAnimating()
        progressView.setProgress(1.0, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.progressView.isHidden = true
        }
    }

    func webView(
        _ webView: WebKit.WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        handle(navigationError: error)
    }

    func webView(
        _ webView: WebKit.WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        handle(navigationError: error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WebKit.WKWebView) {
        // iOS 内存紧张时 WebContent 可能被系统杀掉，这里做一次自恢复。
        guard !hasReloadedAfterTermination else {
            showError(message: "WebContent 进程异常终止，已尝试自动恢复但仍失败。")
            return
        }
        hasReloadedAfterTermination = true
        webView.reload()
    }

    func webView(
        _ webView: WebKit.WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        // 兼容 target=_blank / window.open：不新建 WebView，直接在当前容器加载。
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
            decisionHandler(.cancel)
            return
        }

        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        let scheme = url.scheme?.lowercased() ?? ""
        if ["http", "https", "about"].contains(scheme) {
            decisionHandler(.allow)
            return
        }

        if ["tel", "mailto", "sms"].contains(scheme), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
        decisionHandler(.cancel)
    }

    private func handle(navigationError error: Error) {
        activityIndicator.stopAnimating()

        let nsError = error as NSError
        // 某些跳转取消是 WebKit 正常流程，不应误判为失败页。
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            return
        }

        showError(message: nsError.localizedDescription)
    }
}

extension WKWebViewController: WKUIDelegate {

    func webView(
        _ webView: WebKit.WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WebKit.WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    func webView(
        _ webView: WebKit.WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: webView.title ?? "提示", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "知道了", style: .default) { _ in
            completionHandler()
        })
        presentAlertOnTop(alert)
    }

    func webView(
        _ webView: WebKit.WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let alert = UIAlertController(title: webView.title ?? "确认", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
            completionHandler(false)
        })
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            completionHandler(true)
        })
        presentAlertOnTop(alert)
    }

    func webView(
        _ webView: WebKit.WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        let alert = UIAlertController(title: webView.title ?? "请输入", message: prompt, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = defaultText
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
            completionHandler(nil)
        })
        alert.addAction(UIAlertAction(title: "确定", style: .default) { _ in
            completionHandler(alert.textFields?.first?.text)
        })
        presentAlertOnTop(alert)
    }
}

extension WKWebViewController: WKScriptMessageHandler {

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == pageConfiguration.jsBridgeName else { return }

        // Demo 里保留最核心的三类命令，演示 H5->Native 和 Native->H5 双向通信。
        if let body = message.body as? [String: Any], let action = body["action"] as? String {
            switch action {
            case "close":
                closePage()
            case "reload":
                reloadPage()
            case "getNativeJSON":
                sendNativeJSONToH5()
            default:
                print("收到 H5 Bridge 消息，businessId=\(pageConfiguration.businessId)，action=\(action)，body=\(body)")
            }
            return
        }

        print("收到 H5 Bridge 消息，businessId=\(pageConfiguration.businessId)，body=\(message.body)")
    }
}

// Weak wrapper 是 WKScriptMessageHandler 的经典防泄漏写法。
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {

    weak var delegate: WKScriptMessageHandler?

    init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
        super.init()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}

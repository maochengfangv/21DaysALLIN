import UIKit
import Flutter

enum HybridNavStyle: String {
    case native
    case flutter
    case none
}

final class HybridFlutterViewController: FlutterViewController, UIGestureRecognizerDelegate {
    let navStyle: HybridNavStyle
    var currentRequestId: String?
    var routeName: String?

    init(engine: FlutterEngine, navStyle: HybridNavStyle) {
        self.navStyle = navStyle
        super.init(engine: engine, nibName: nil, bundle: nil)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        extendedLayoutIncludesOpaqueBars = true
        edgesForExtendedLayout = [.top, .bottom, .left, .right]
        if let nav = navigationController {
            nav.interactivePopGestureRecognizer?.delegate = self
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(navStyle != .native, animated: animated)

        if navStyle == .native {
            navigationItem.hidesBackButton = true
            let backButton = UIBarButtonItem(
                title: "Back",
                style: .plain,
                target: self,
                action: #selector(handleNativeBackTapped)
            )
            backButton.accessibilityIdentifier = "HybridFlutterBackBarButton"
            navigationItem.leftBarButtonItem = backButton
        } else {
            navigationItem.leftBarButtonItem = nil
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if let reqId = currentRequestId {
            FlutterChannelRouterBridge.shared.flushPendingPush(for: reqId)
        }

        if navStyle == .native {
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        navigationController?.interactivePopGestureRecognizer?.isEnabled = true

        if isMovingFromParent {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if isMovingFromParent || isBeingDismissed {
            let requestId = currentRequestId ?? ""
            ContainerDispatcher.shared.handleFlutterContainerDismissed(requestId: currentRequestId)

            let vcCount = navigationController?.viewControllers.count ?? 0
            let isLastFlutter = vcCount == 0 || !(navigationController?.topViewController is HybridFlutterViewController)
            if isLastFlutter {
                FlutterChannelRouterBridge.shared.notifyFlutterResetToBootstrap()
            }

            let result = RouteResult(
                requestId: requestId,
                pageId: "",
                routeName: routeName ?? "",
                payload: nil,
                isCancelled: true
            )
            PendingRequestStore.shared.resolveResult(result)
        }
    }

    // MARK: - 返回事件捕获

    @objc private func handleNativeBackTapped() {
        BackDispatcher.shared.handleBackPress(source: .nativeNavBarButton, from: self)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === navigationController?.interactivePopGestureRecognizer {
            let consumed = BackDispatcher.shared.handleBackPress(source: .nativeSwipe, from: self)
            return !consumed
        }
        return true
    }

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        if viewController !== self {
            navigationController.interactivePopGestureRecognizer?.delegate = nil
        }
    }

    // MARK: - dismiss 触发

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        let requestId = currentRequestId ?? ""
        super.dismiss(animated: flag) { [weak self] in
            ContainerDispatcher.shared.handleFlutterContainerDismissed(requestId: requestId)
            FlutterChannelRouterBridge.shared.notifyFlutterResetToBootstrap()
            let result = RouteResult(
                requestId: requestId,
                pageId: "",
                routeName: self?.routeName ?? "",
                payload: nil,
                isCancelled: true
            )
            PendingRequestStore.shared.resolveResult(result)
            completion?()
        }
    }
}

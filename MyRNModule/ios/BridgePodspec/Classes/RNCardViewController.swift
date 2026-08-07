import UIKit
import React

@objc public protocol RNCardViewControllerDelegate: AnyObject {
  @objc optional func rnCardVC(_ vc: RNCardViewController, didPressCard cardId: String)
  @objc optional func rnCardVC(_ vc: RNCardViewController, didPressAction cardId: String, actionId: String, actionType: Int)
  @objc optional func rnCardVC(_ vc: RNCardViewController, didExpose cardId: String, timestamp: TimeInterval)
}

@objcMembers
public final class RNCardViewController: UIViewController {

  public weak var delegate: RNCardViewControllerDelegate?

  public let moduleName: String
  public private(set) var initialProperties: [AnyHashable: Any]?

  public var onCardPress: ((_ cardId: String) -> Void)?
  public var onActionPress: ((_ cardId: String, _ actionId: String, _ actionType: Int) -> Void)?
  public var onExposure: ((_ cardId: String, _ timestamp: TimeInterval) -> Void)?

  private var rootView: RCTRootView?
  private lazy var loadingView: UIActivityIndicatorView = {
    let v: UIActivityIndicatorView
    if #available(iOS 13.0, *) {
      v = UIActivityIndicatorView(style: .large)
    } else {
      v = UIActivityIndicatorView(style: .whiteLarge)
    }
    v.color = .gray
    v.hidesWhenStopped = true
    return v
  }()

  private lazy var fallbackLabel: UILabel = {
    let label = UILabel()
    label.text = "RN 模块加载失败\n请检查 Bundle 配置"
    label.textAlignment = .center
    label.numberOfLines = 0
    label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
    label.textColor = UIColor(red: 0.6, green: 0.6, blue: 0.62, alpha: 1)
    label.isHidden = true
    return label
  }()

  private var observers: [NSObjectProtocol] = []

  public init(
    moduleName: String,
    initialProperties: [AnyHashable: Any]? = nil,
    initialCardsPayload: String? = nil
  ) {
    self.moduleName = moduleName
    self.initialProperties = initialProperties
    super.init(nibName: nil, bundle: nil)
    BusinessCardBridgeTurboModule.initialCardsPayload = initialCardsPayload
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1)
    title = initialProperties?["title"] as? String ?? "RN 卡片模块"
    setupLoadingView()
    setupFallbackLabel()
    setupBridgeCallbacks()
    loadRNModule()
  }

  public override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    if isMovingFromParent || isBeingDismissed {
      BusinessCardBridgeTurboModule.clearCallbacks()
    }
  }

  deinit {
    observers.forEach { NotificationCenter.default.removeObserver($0) }
    BusinessCardBridgeTurboModule.clearCallbacks()
    rootView?.removeFromSuperview()
    rootView = nil
    NSLog("[RNCardViewController] 已释放 module=\(moduleName)")
  }

  // MARK: - Public

  public func updateInitialProperties(_ props: [AnyHashable: Any]) {
    initialProperties = props
    rootView?.appProperties = props
  }

  public func reloadModule() {
    rootView?.removeFromSuperview()
    rootView = nil
    loadingView.startAnimating()
    loadRNModule()
  }

  // MARK: - Private

  private func setupLoadingView() {
    loadingView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(loadingView)
    NSLayoutConstraint.activate([
      loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
    ])
    loadingView.startAnimating()
  }

  private func setupFallbackLabel() {
    fallbackLabel.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(fallbackLabel)
    NSLayoutConstraint.activate([
      fallbackLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      fallbackLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      fallbackLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
    ])
  }

  private func setupBridgeCallbacks() {
    BusinessCardBridgeTurboModule.onCardPress = { [weak self] cardId in
      guard let self else { return }
      self.onCardPress?(cardId)
      self.delegate?.rnCardVC?(self, didPressCard: cardId)
    }
    BusinessCardBridgeTurboModule.onActionPress = { [weak self] cardId, actionId, actionType in
      guard let self else { return }
      self.onActionPress?(cardId, actionId, actionType)
      self.delegate?.rnCardVC?(self, didPressAction: cardId, actionId: actionId, actionType: actionType)
    }
    BusinessCardBridgeTurboModule.onExposure = { [weak self] cardId, timestamp in
      guard let self else { return }
      self.onExposure?(cardId, timestamp)
      self.delegate?.rnCardVC?(self, didExpose: cardId, timestamp: timestamp)
    }
  }

  private func loadRNModule() {
    RNBridgeManager.shared.ensureBridge { [weak self] bridge in
      guard let self else { return }
      guard let bridge else {
        self.showFallback()
        return
      }
      DispatchQueue.main.async {
        self.attachRootView(with: bridge)
      }
    }
  }

  private func attachRootView(with bridge: RCTBridge) {
    let rootView = RCTRootView(
      bridge: bridge,
      moduleName: moduleName,
      initialProperties: initialProperties
    )
    rootView.backgroundColor = view.backgroundColor
    rootView.translatesAutoresizingMaskIntoConstraints = false
    rootView.alpha = 0

    view.insertSubview(rootView, belowSubview: loadingView)
    NSLayoutConstraint.activate([
      rootView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      rootView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      rootView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      rootView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    self.rootView = rootView

    let timeout = DispatchWorkItem { [weak self] in
      guard let self else { return }
      if self.rootView?.alpha == 0 {
        NSLog("[RNCardViewController] ⚠️ RN RootView 内容超时未渲染")
        self.loadingView.stopAnimating()
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: timeout)

    let contentObserver = NotificationCenter.default.addObserver(
      forName: NSNotification.Name.RCTContentDidAppear,
      object: rootView,
      queue: .main
    ) { [weak self] _ in
      guard let self else { return }
      timeout.cancel()
      UIView.animate(withDuration: 0.25) {
        self.rootView?.alpha = 1
      } completion: { _ in
        self.loadingView.stopAnimating()
      }
    }
    observers.append(contentObserver)
  }

  private func showFallback() {
    DispatchQueue.main.async {
      self.loadingView.stopAnimating()
      self.fallbackLabel.isHidden = false
    }
  }
}

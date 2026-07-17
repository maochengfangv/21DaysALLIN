import UIKit

final class ReactNativeViewController: UIViewController {
  private let moduleName: String
  private let initialProperties: [String: Any]?

  init(moduleName: String, initialProperties: [String: Any]? = nil) {
    self.moduleName = moduleName
    self.initialProperties = initialProperties
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    view = ReactNativeHost.shared.makeRootView(
      moduleName: moduleName,
      initialProperties: initialProperties
    )
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "RN Page"
    navigationItem.leftBarButtonItem = UIBarButtonItem(
      barButtonSystemItem: .close,
      target: self,
      action: #selector(closePage)
    )
    navigationItem.rightBarButtonItems = [
      UIBarButtonItem(
        title: "场景C",
        style: .plain,
        target: self,
        action: #selector(sendSceneC)
      ),
      UIBarButtonItem(
        title: "场景B",
        style: .plain,
        target: self,
        action: #selector(sendSceneB)
      ),
      UIBarButtonItem(
        title: "场景A",
        style: .plain,
        target: self,
        action: #selector(sendSceneA)
      ),
    ]
  }

  @objc
  private func closePage() {
    dismiss(animated: true)
  }

  @objc
  private func sendSceneA() {
    sendBusinessData(
      callbackId: RNBusinessSwiftConstants.CallbackId.sceneA,
      payload: [
        "title": "Native Scene A",
        "count": Int.random(in: 1...99),
      ]
    )
  }

  @objc
  private func sendSceneB() {
    sendBusinessData(
      callbackId: RNBusinessSwiftConstants.CallbackId.sceneB,
      payload: [
        "url": "https://juejin.cn",
        "metadata": [
          "source": "IOSRNContainer",
          "module": moduleName,
        ],
      ]
    )
  }

  @objc
  private func sendSceneC() {
    sendBusinessData(
      callbackId: RNBusinessSwiftConstants.CallbackId.sceneC,
      payload: [
        "status": Bool.random() ? "success" : "fail",
        "message": "原生侧触发状态同步",
      ]
    )
  }

  private func sendBusinessData(callbackId: String, payload: [String: Any]) {
    // 优先通过单例获取 emitter（避免 bridgeless 模式下 bridge 为 nil）
    if let cls = NSClassFromString("RNBusinessEventEmitter") as? NSObject.Type,
       let emitter = cls.perform(NSSelectorFromString("sharedInstance"))?.takeUnretainedValue() as? NSObject,
       emitter.responds(to: NSSelectorFromString("sendBusinessData:payload:")) {
      emitter.perform(
        NSSelectorFromString("sendBusinessData:payload:"),
        with: callbackId,
        with: payload as NSDictionary
      )
      return
    }

    // 降级：通过 bridge 获取
    guard let bridge = ReactNativeHost.shared.bridge else {
      return
    }
    guard
      let emitter = bridge.module(
        forName: RNBusinessSwiftConstants.moduleName,
        lazilyLoadIfNecessary: true
      ) as? NSObject,
      emitter.responds(to: NSSelectorFromString("sendBusinessData:payload:"))
    else {
      return
    }
    emitter.perform(
      NSSelectorFromString("sendBusinessData:payload:"),
      with: callbackId,
      with: payload as NSDictionary
    )
  }
}

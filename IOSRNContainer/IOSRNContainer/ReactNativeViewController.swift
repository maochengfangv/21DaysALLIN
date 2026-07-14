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
  }

  @objc
  private func closePage() {
    dismiss(animated: true)
  }
}

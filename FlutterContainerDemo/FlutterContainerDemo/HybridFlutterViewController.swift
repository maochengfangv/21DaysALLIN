import UIKit
import Flutter

enum HybridNavStyle: String {
    case native
    case flutter
    case none
}

final class HybridFlutterViewController: FlutterViewController {
    let navStyle: HybridNavStyle

    init(engine: FlutterEngine, navStyle: HybridNavStyle) {
        self.navStyle = navStyle
        super.init(engine: engine, nibName: nil, bundle: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(navStyle != .native, animated: animated)

        if navStyle == .native {
            navigationItem.hidesBackButton = true
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "Back",
                style: .plain,
                target: self,
                action: #selector(handleNativeBackTapped)
            )
        } else {
            navigationItem.leftBarButtonItem = nil
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if navStyle == .native {
            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
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

        if isMovingFromParent {
            HybridRouter.shared.handleFlutterViewControllerDismissed()
        }
    }

    @objc private func handleNativeBackTapped() {
        HybridRouter.shared.requestFlutterBackNavigation()
    }
}

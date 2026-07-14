//
//  ViewController.swift
//  IOSRNContainer
//
//  Created by maochengfang on 2026/7/13.
//

import UIKit

class ViewController: UIViewController {
    private let openRNButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.configuration = .filled()
        button.configuration?.title = "打开 React Native 页面"
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Native Home"

        view.addSubview(openRNButton)
        NSLayoutConstraint.activate([
            openRNButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            openRNButton.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        openRNButton.addTarget(self, action: #selector(openRNPage), for: .touchUpInside)
    }

    @objc
    private func openRNPage() {
        let reactNativeViewController = ReactNativeViewController(
            moduleName: "MyRNModule",
            initialProperties: [
                "fromNative": true,
                "entry": "IOSRNContainer"
            ]
        )
        let navigationController = UINavigationController(rootViewController: reactNativeViewController)
        navigationController.modalPresentationStyle = .fullScreen
        present(navigationController, animated: true)
    }

}

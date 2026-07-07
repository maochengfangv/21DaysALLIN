//
//  ViewController.swift
//  FlutterContainerDemo
//
//  Created by maochengfang on 2026/7/1.
//

import UIKit
import Flutter

class ViewController: UIViewController {
    private let resultLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "iOS Container"
        view.backgroundColor = .systemBackground

        let openFlutterButton = UIButton(type: .system)
        openFlutterButton.setTitle("Open Flutter Channel Demos", for: .normal)
        openFlutterButton.addTarget(self, action: #selector(openFlutterTapped), for: .touchUpInside)

        resultLabel.textAlignment = .center
        resultLabel.numberOfLines = 0
        resultLabel.textColor = .secondaryLabel
        resultLabel.text = "Result: (none)"

        let stack = UIStackView(arrangedSubviews: [openFlutterButton, resultLabel])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }

    @objc private func openFlutterTapped() {
        HybridRouter.shared.showFlutter(from: self, route: "/channel_demos", params: ["from": "ios"]) { [weak self] result in
            self?.resultLabel.text = "Result: \(String(describing: result))"
        }
    }
}

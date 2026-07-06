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
        openFlutterButton.setTitle("Open Flutter Counter", for: .normal)
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
        HybridRouter.shared.showFlutter(from: self, route: "/counter", params: ["from": "ios"]) { [weak self] result in
            self?.resultLabel.text = "Result: \(String(describing: result))"
        }
    }
}

final class HybridRouter {
    static let shared = HybridRouter()

    private let channelName = "com.example.hybrid/router"
    private var channel: FlutterMethodChannel?

    private weak var navigationController: UINavigationController?
    private var pendingResult: ((Any?) -> Void)?

    private init() {}

    func attach(engine: FlutterEngine) {
        guard channel == nil else { return }

        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: engine.binaryMessenger)
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else {
                result(FlutterError(code: "router_released", message: nil, details: nil))
                return
            }

            switch call.method {
            case "openNative":
                self.handleOpenNative(call: call, result: result)
            case "closeFlutter":
                self.handleCloseFlutter(call: call, result: result)
            case "flutterReady":
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        self.channel = channel
    }

    func showFlutter(from viewController: UIViewController, route: String, params: [String: Any], onResult: ((Any?) -> Void)? = nil) {
        let engine = FlutterEngineProvider.shared.engine

        let flutterViewController = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        flutterViewController.title = "Flutter"

        pendingResult = onResult
        navigationController = viewController.navigationController

        viewController.navigationController?.pushViewController(flutterViewController, animated: true)

        DispatchQueue.main.async { [weak self] in
            self?.pushRoute(route: route, params: params)
        }
    }

    private func pushRoute(route: String, params: [String: Any]) {
        channel?.invokeMethod("pushRoute", arguments: [
            "version": 1,
            "route": route,
            "params": params
        ])
    }

    private func handleOpenNative(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "bad_args", message: "arguments must be a map", details: nil))
            return
        }

        let route = args["route"] as? String ?? "native"
        let params = args["params"] as? [String: Any] ?? [:]

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let vc = NativePageViewController(route: route, params: params)
            self.navigationController?.pushViewController(vc, animated: true)
        }

        result(nil)
    }

    private func handleCloseFlutter(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let payload = args?["result"]

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.navigationController?.popViewController(animated: true)
            self.pendingResult?(payload)
            self.pendingResult = nil
        }

        result(nil)
    }
}

final class NativePageViewController: UIViewController {
    private let route: String
    private let params: [String: Any]

    init(route: String, params: [String: Any]) {
        self.route = route
        self.params = params
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Native: \(route)"
        view.backgroundColor = .systemBackground

        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Opened from Flutter\n\nparams: \(params)"

        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }
}


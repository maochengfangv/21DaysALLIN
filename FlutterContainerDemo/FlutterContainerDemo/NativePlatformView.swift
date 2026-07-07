import UIKit
import Flutter

enum NativePlatformViewConstants {
    static let pluginKey = "NativePlatformViewPlugin"
    static let viewType = "com.maocf.hybrid/native_label_view"
    static let controlChannel = "com.maocf.hybrid/platform_view_control"
}

final class NativePlatformViewRegistrar {
    private static let registry = NativePlatformViewRegistry()
    private static var controlChannel: FlutterMethodChannel?
    private static var isRegistered = false

    static func register(with engine: FlutterEngine) {
        guard !isRegistered else { return }
        guard let registrar = engine.registrar(forPlugin: NativePlatformViewConstants.pluginKey) else { return }

        let factory = NativePlatformDemoViewFactory(registry: registry)
        registrar.register(factory, withId: NativePlatformViewConstants.viewType)

        let channel = FlutterMethodChannel(
            name: NativePlatformViewConstants.controlChannel,
            binaryMessenger: engine.binaryMessenger
        )
        channel.setMethodCallHandler { call, result in
            registry.handle(call: call, result: result)
        }

        controlChannel = channel
        isRegistered = true
    }
}

fileprivate final class NativePlatformViewRegistry {
    private final class WeakBox {
        weak var value: NativePlatformDemoView?

        init(value: NativePlatformDemoView) {
            self.value = value
        }
    }

    private var views: [Int64: WeakBox] = [:]

    func register(_ view: NativePlatformDemoView, for viewId: Int64) {
        cleanupReleasedViews()
        views[viewId] = WeakBox(value: view)
    }

    func unregister(viewId: Int64) {
        views.removeValue(forKey: viewId)
    }

    func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "updateNativeView":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "bad_args", message: "arguments must be a map", details: nil))
                return
            }
            guard let viewId = parseViewId(from: args["viewId"]) else {
                result(FlutterError(code: "bad_view_id", message: "missing viewId", details: nil))
                return
            }
            guard let view = views[viewId]?.value else {
                result(FlutterError(code: "view_not_found", message: "no native view for viewId \(viewId)", details: nil))
                return
            }

            DispatchQueue.main.async {
                result(view.update(with: args))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func parseViewId(from rawValue: Any?) -> Int64? {
        if let value = rawValue as? Int64 {
            return value
        }
        if let value = rawValue as? Int {
            return Int64(value)
        }
        if let value = rawValue as? NSNumber {
            return value.int64Value
        }
        return nil
    }

    private func cleanupReleasedViews() {
        views = views.filter { $0.value.value != nil }
    }
}

fileprivate struct NativePlatformViewStyle {
    var text: String = "Hello from iOS Native View"
    var width: CGFloat = 220
    var height: CGFloat = 120
    var cornerRadius: CGFloat = 16
    var backgroundColor: UIColor = UIColor(red: 1.0, green: 0.42, blue: 0.42, alpha: 1.0)
    var textColor: UIColor = .white
    var isHidden: Bool = false

    mutating func update(with args: [String: Any]) {
        if let text = args["text"] as? String {
            self.text = text
        }
        if let width = Self.cgFloat(from: args["width"]) {
            self.width = max(60, width)
        }
        if let height = Self.cgFloat(from: args["height"]) {
            self.height = max(40, height)
        }
        if let cornerRadius = Self.cgFloat(from: args["cornerRadius"]) {
            self.cornerRadius = max(0, cornerRadius)
        }
        if let hidden = args["hidden"] as? Bool {
            isHidden = hidden
        }
        if let color = UIColor.platformViewColor(from: args["backgroundColor"]) {
            backgroundColor = color
        }
        if let color = UIColor.platformViewColor(from: args["textColor"]) {
            textColor = color
        }
    }

    func snapshot(viewId: Int64) -> [String: Any] {
        [
            "viewId": viewId,
            "text": text,
            "width": width,
            "height": height,
            "cornerRadius": cornerRadius,
            "hidden": isHidden,
            "backgroundColor": backgroundColor.hexString(),
            "textColor": textColor.hexString()
        ]
    }

    private static func cgFloat(from rawValue: Any?) -> CGFloat? {
        if let value = rawValue as? CGFloat {
            return value
        }
        if let value = rawValue as? Double {
            return CGFloat(value)
        }
        if let value = rawValue as? Float {
            return CGFloat(value)
        }
        if let value = rawValue as? Int {
            return CGFloat(value)
        }
        if let value = rawValue as? NSNumber {
            return CGFloat(truncating: value)
        }
        return nil
    }
}

fileprivate final class NativePlatformDemoViewFactory: NSObject, FlutterPlatformViewFactory {
    private let registry: NativePlatformViewRegistry

    init(registry: NativePlatformViewRegistry) {
        self.registry = registry
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        NativePlatformDemoView(frame: frame, viewId: viewId, args: args, registry: registry)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

fileprivate final class NativePlatformDemoView: NSObject, FlutterPlatformView {
    private let viewId: Int64
    private let registry: NativePlatformViewRegistry

    private let rootView = UIView()
    private let boxView = UIView()
    private let textLabel = UILabel()
    private var widthConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var style = NativePlatformViewStyle()

    init(frame: CGRect, viewId: Int64, args: Any?, registry: NativePlatformViewRegistry) {
        self.viewId = viewId
        self.registry = registry
        super.init()
        setupView(frame: frame)
        registry.register(self, for: viewId)

        let initialArgs = args as? [String: Any] ?? [:]
        style.update(with: initialArgs)
        render()
    }

    deinit {
        registry.unregister(viewId: viewId)
    }

    func view() -> UIView {
        rootView
    }

    func update(with args: [String: Any]) -> [String: Any] {
        style.update(with: args)
        render()
        return style.snapshot(viewId: viewId)
    }

    private func setupView(frame: CGRect) {
        rootView.frame = frame
        rootView.backgroundColor = UIColor.systemGray6.withAlphaComponent(0.65)
        rootView.layer.cornerRadius = 16
        rootView.clipsToBounds = true

        boxView.translatesAutoresizingMaskIntoConstraints = false
        boxView.clipsToBounds = true
        rootView.addSubview(boxView)

        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.numberOfLines = 0
        textLabel.textAlignment = .center
        textLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        boxView.addSubview(textLabel)

        let widthConstraint = boxView.widthAnchor.constraint(equalToConstant: style.width)
        let heightConstraint = boxView.heightAnchor.constraint(equalToConstant: style.height)
        self.widthConstraint = widthConstraint
        self.heightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            boxView.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            boxView.centerYAnchor.constraint(equalTo: rootView.centerYAnchor),
            widthConstraint,
            heightConstraint,
            boxView.widthAnchor.constraint(lessThanOrEqualTo: rootView.widthAnchor, constant: -24),
            boxView.heightAnchor.constraint(lessThanOrEqualTo: rootView.heightAnchor, constant: -24),

            textLabel.leadingAnchor.constraint(equalTo: boxView.leadingAnchor, constant: 12),
            textLabel.trailingAnchor.constraint(equalTo: boxView.trailingAnchor, constant: -12),
            textLabel.topAnchor.constraint(equalTo: boxView.topAnchor, constant: 12),
            textLabel.bottomAnchor.constraint(equalTo: boxView.bottomAnchor, constant: -12)
        ])
    }

    private func render() {
        widthConstraint?.constant = style.width
        heightConstraint?.constant = style.height
        boxView.backgroundColor = style.backgroundColor
        boxView.layer.cornerRadius = style.cornerRadius
        boxView.isHidden = style.isHidden
        textLabel.text = style.text
        textLabel.textColor = style.textColor
        rootView.setNeedsLayout()
        rootView.layoutIfNeeded()
    }
}

private extension UIColor {
    static func platformViewColor(from rawValue: Any?) -> UIColor? {
        guard let hex = rawValue as? String else { return nil }
        return UIColor(hexString: hex)
    }

    convenience init?(hexString: String) {
        let cleaned = hexString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()

        let alpha, red, green, blue: UInt64
        switch cleaned.count {
        case 6:
            alpha = 255
            red = UInt64(cleaned.prefix(2), radix: 16) ?? 0
            green = UInt64(cleaned.dropFirst(2).prefix(2), radix: 16) ?? 0
            blue = UInt64(cleaned.dropFirst(4).prefix(2), radix: 16) ?? 0
        case 8:
            alpha = UInt64(cleaned.prefix(2), radix: 16) ?? 255
            red = UInt64(cleaned.dropFirst(2).prefix(2), radix: 16) ?? 0
            green = UInt64(cleaned.dropFirst(4).prefix(2), radix: 16) ?? 0
            blue = UInt64(cleaned.dropFirst(6).prefix(2), radix: 16) ?? 0
        default:
            return nil
        }

        self.init(
            red: CGFloat(red) / 255.0,
            green: CGFloat(green) / 255.0,
            blue: CGFloat(blue) / 255.0,
            alpha: CGFloat(alpha) / 255.0
        )
    }

    func hexString() -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        func hex(_ value: CGFloat) -> String {
            let normalized = Int(round(value * 255))
            return String(format: "%02X", normalized)
        }

        return "#\(hex(alpha))\(hex(red))\(hex(green))\(hex(blue))"
    }
}

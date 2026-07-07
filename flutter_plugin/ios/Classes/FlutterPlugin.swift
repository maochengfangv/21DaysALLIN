import Flutter
import UIKit
import AVFoundation

enum FlutterPluginChannelNames {
  static let method = "com.example.flutter_plugin/method"
  static let events = "com.example.flutter_plugin/events"
  static let messageString = "com.example.flutter_plugin/message_string"
  static let messageStandard = "com.example.flutter_plugin/message_standard"
}

enum PluginErrorCodes {
  static let ok = 0
  static let badArgs = 1
  static let notSupported = 2
  static let permissionDenied = 3
  static let permissionPermanentlyDenied = 4
  static let internalError = 5
}

final class PluginException: Error {
  init(code: Int, message: String) {
    self.code = code
    self.message = message
  }

  let code: Int
  let message: String
}

enum Args {
  static func asMap(_ any: Any?) throws -> [String: Any] {
    guard let map = any as? [String: Any] else {
      throw PluginException(code: PluginErrorCodes.badArgs, message: "Invalid arguments")
    }
    return map
  }

  static func getString(_ map: [String: Any], _ key: String) throws -> String {
    guard let value = map[key] else {
      throw PluginException(code: PluginErrorCodes.badArgs, message: "Missing \(key)")
    }
    return String(describing: value)
  }

  static func getInt(_ map: [String: Any], _ key: String) throws -> Int {
    guard let value = map[key] else {
      throw PluginException(code: PluginErrorCodes.badArgs, message: "Missing \(key)")
    }
    if let intValue = value as? Int { return intValue }
    if let number = value as? NSNumber { return number.intValue }
    if let str = value as? String, let intValue = Int(str) { return intValue }
    throw PluginException(code: PluginErrorCodes.badArgs, message: "Invalid int for \(key)")
  }

  static func getMap(_ map: [String: Any], _ key: String) throws -> [String: Any] {
    guard let value = map[key] else {
      throw PluginException(code: PluginErrorCodes.badArgs, message: "Missing \(key)")
    }
    guard let dict = value as? [String: Any] else {
      throw PluginException(code: PluginErrorCodes.badArgs, message: "Invalid map for \(key)")
    }
    return dict
  }
}

enum PluginResponse {
  static func ok(requestId: String, data: Any?) -> [String: Any?] {
    return [
      "code": PluginErrorCodes.ok,
      "message": "ok",
      "data": data,
      "requestId": requestId,
    ]
  }

  static func error(requestId: String, code: Int, message: String, data: Any? = nil) -> [String: Any?] {
    return [
      "code": code,
      "message": message,
      "data": data,
      "requestId": requestId,
    ]
  }
}

public class SwiftFlutterPluginPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var ticker: DispatchSourceTimer?
  private var tickCount: Int64 = 0
  private var tickIntervalMs: Int64 = 0

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SwiftFlutterPluginPlugin()

    let method = FlutterMethodChannel(name: FlutterPluginChannelNames.method, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: method)

    let events = FlutterEventChannel(name: FlutterPluginChannelNames.events, binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)

    let messageString = FlutterBasicMessageChannel(
      name: FlutterPluginChannelNames.messageString,
      binaryMessenger: registrar.messenger(),
      codec: FlutterStringCodec.sharedInstance()
    )
    messageString.setMessageHandler { message, reply in
      instance.handleStringMessage(message: message as? String, reply: reply)
    }

    let messageStandard = FlutterBasicMessageChannel(
      name: FlutterPluginChannelNames.messageStandard,
      binaryMessenger: registrar.messenger(),
      codec: FlutterStandardMessageCodec.sharedInstance()
    )
    messageStandard.setMessageHandler { message, reply in
      instance.handleStandardMessage(message: message, reply: reply)
    }
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let requestId: String
    do {
      let args = try Args.asMap(call.arguments)
      requestId = (args["requestId"] as? String) ?? ""

      switch call.method {
      case "getPlatformVersion":
        result(PluginResponse.ok(requestId: requestId, data: "iOS \(UIDevice.current.systemVersion)"))
      case "getDeviceInfo":
        result(PluginResponse.ok(requestId: requestId, data: getDeviceInfo()))
      case "requestCameraPermission":
        requestCameraPermission(requestId: requestId, result: result)
      case "startTicking":
        let payload = try Args.getMap(args, "payload")
        let intervalMs = Int64(try Args.getInt(payload, "intervalMs"))
        startTicking(requestId: requestId, intervalMs: intervalMs, result: result)
      case "stopTicking":
        stopTicking()
        result(PluginResponse.ok(requestId: requestId, data: nil))
      default:
        result(PluginResponse.error(requestId: requestId, code: PluginErrorCodes.notSupported, message: "Not supported: \(call.method)"))
      }
    } catch let e as PluginException {
      let req = (try? Args.asMap(call.arguments))?["requestId"] as? String ?? ""
      result(PluginResponse.error(requestId: req, code: e.code, message: e.message))
    } catch {
      let req = (try? Args.asMap(call.arguments))?["requestId"] as? String ?? ""
      result(PluginResponse.error(requestId: req, code: PluginErrorCodes.internalError, message: "\(error)"))
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    stopTicking()
    return nil
  }

  private func getDeviceInfo() -> [String: Any?] {
    let info = Bundle.main.infoDictionary
    let versionName = info?["CFBundleShortVersionString"] as? String
    let versionCode = info?["CFBundleVersion"] as? String
    return [
      "platform": "ios",
      "model": UIDevice.current.model,
      "name": UIDevice.current.name,
      "systemVersion": UIDevice.current.systemVersion,
      "appVersionName": versionName,
      "appVersionCode": versionCode,
    ]
  }

  private func requestCameraPermission(requestId: String, result: @escaping FlutterResult) {
    let current = AVCaptureDevice.authorizationStatus(for: .video)
    switch current {
    case .authorized:
      result(PluginResponse.ok(requestId: requestId, data: ["status": "granted"]))
    case .restricted:
      result(PluginResponse.error(requestId: requestId, code: PluginErrorCodes.permissionDenied, message: "permission restricted", data: ["status": "restricted"]))
    case .denied:
      result(PluginResponse.error(requestId: requestId, code: PluginErrorCodes.permissionPermanentlyDenied, message: "permission denied", data: ["status": "permanentlyDenied"]))
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { granted in
        DispatchQueue.main.async {
          let status = granted ? "granted" : "denied"
          let code = granted ? PluginErrorCodes.ok : PluginErrorCodes.permissionDenied
          let message = granted ? "ok" : "permission denied"
          let response: [String: Any?]
          if code == PluginErrorCodes.ok {
            response = PluginResponse.ok(requestId: requestId, data: ["status": status])
          } else {
            response = PluginResponse.error(requestId: requestId, code: code, message: message, data: ["status": status])
          }
          result(response)

          self.eventSink?([
            "eventName": "permission",
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
            "payload": [
              "permission": "camera",
              "status": status,
            ],
          ])
        }
      }
    @unknown default:
      result(PluginResponse.error(requestId: requestId, code: PluginErrorCodes.internalError, message: "unknown authorization status"))
    }
  }

  private func startTicking(requestId: String, intervalMs: Int64, result: @escaping FlutterResult) {
    guard intervalMs > 0 else {
      result(PluginResponse.error(requestId: requestId, code: PluginErrorCodes.badArgs, message: "intervalMs must be > 0"))
      return
    }
    guard eventSink != nil else {
      result(PluginResponse.error(requestId: requestId, code: PluginErrorCodes.notSupported, message: "EventChannel not listened"))
      return
    }

    stopTicking()

    tickIntervalMs = intervalMs
    tickCount = 0

    let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
    timer.schedule(deadline: .now(), repeating: .milliseconds(Int(intervalMs)))
    timer.setEventHandler { [weak self] in
      guard let self else { return }
      self.tickCount += 1
      self.eventSink?([
        "eventName": "tick",
        "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
        "payload": [
          "count": self.tickCount,
          "intervalMs": self.tickIntervalMs,
        ],
      ])
    }
    ticker = timer
    timer.resume()
    result(PluginResponse.ok(requestId: requestId, data: nil))
  }

  private func stopTicking() {
    if let timer = ticker {
      timer.cancel()
    }
    ticker = nil
  }

  private func handleStringMessage(message: String?, reply: FlutterReply) {
    guard let text = message else {
      reply(encodeJsonString(PluginResponse.error(requestId: "", code: PluginErrorCodes.badArgs, message: "empty message")))
      return
    }

    guard let data = text.data(using: .utf8) else {
      reply(encodeJsonString(PluginResponse.error(requestId: "", code: PluginErrorCodes.badArgs, message: "invalid string")))
      return
    }

    let dictAny = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    let requestId = dictAny?["requestId"] as? String ?? ""
    let payload = dictAny?["payload"] as? [String: Any]
    let input = payload?["text"] as? String ?? ""
    let output = "iOS echo: \(input)"
    reply(encodeJsonString(PluginResponse.ok(requestId: requestId, data: output)))
  }

  private func handleStandardMessage(message: Any?, reply: FlutterReply) {
    guard let req = message as? [String: Any] else {
      reply(PluginResponse.error(requestId: "", code: PluginErrorCodes.badArgs, message: "invalid message"))
      return
    }

    let requestId = req["requestId"] as? String ?? ""
    let payload = req["payload"] as? [String: Any] ?? [:]
    let bytes = FlutterStandardTypedData(bytes: Data([1, 2, 3, 4]))
    let data: [String: Any] = [
      "platform": "ios",
      "receivedPayload": payload,
      "bytes": bytes,
      "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
    ]
    reply(PluginResponse.ok(requestId: requestId, data: data))
  }

  private func encodeJsonString(_ any: Any) -> String {
    let obj: Any
    if let dict = any as? [String: Any?] {
      obj = dict.reduce(into: [String: Any]()) { acc, item in
        acc[item.key] = item.value ?? NSNull()
      }
    } else {
      obj = any
    }

    guard let data = try? JSONSerialization.data(withJSONObject: obj),
          let str = String(data: data, encoding: .utf8) else {
      return ""
    }
    return str
  }
}

import Foundation
import React

@objc(BusinessCardBridgeTurboModule)
public final class BusinessCardBridgeTurboModule: NSObject, RCTBridgeModule {

  @objc public static func moduleName() -> String! {
    "BusinessCardBridge"
  }

  @objc public static func requiresMainQueueSetup() -> Bool {
    false
  }

  public static var dispatchDidSetInteropOpqaueConfig: (() -> Void)? = nil

  public var methodQueue: DispatchQueue {
    DispatchQueue.main
  }

  public typealias CardPressHandler = (_ cardId: String) -> Void
  public typealias ActionPressHandler = (_ cardId: String, _ actionId: String, _ actionType: Int) -> Void
  public typealias ExposureHandler = (_ cardId: String, _ timestamp: TimeInterval) -> Void

  @objc public static var onCardPress: CardPressHandler?
  @objc public static var onActionPress: ActionPressHandler?
  @objc public static var onExposure: ExposureHandler?
  @objc public static var initialCardsPayload: String?

  // MARK: - TurboModule Methods (Codegen 需要的接口)

  @objc public func onCardPress(_ cardId: String) {
    NSLog("[BusinessCard] 卡片点击: \(cardId)")
    BusinessCardBridgeTurboModule.onCardPress?(cardId)
  }

  @objc public func onActionPress(
    _ cardId: String,
    actionId: String,
    actionType: Int32
  ) {
    NSLog("[BusinessCard] 操作点击: card=\(cardId), action=\(actionId), type=\(actionType)")
    BusinessCardBridgeTurboModule.onActionPress?(cardId, actionId, Int(actionType))
  }

  @objc public func onExposure(
    _ cardId: String,
    timestamp: Double
  ) {
    BusinessCardBridgeTurboModule.onExposure?(cardId, timestamp)
  }

  @objc(getInitialCards:rejecter:)
  public func getInitialCards(
    _ resolve: RCTPromiseResolveBlock,
    rejecter reject: RCTPromiseRejectBlock
  ) {
    resolve(BusinessCardBridgeTurboModule.initialCardsPayload ?? "[]")
  }

  // MARK: - Helper

  @objc public static func clearCallbacks() {
    onCardPress = nil
    onActionPress = nil
    onExposure = nil
  }
}

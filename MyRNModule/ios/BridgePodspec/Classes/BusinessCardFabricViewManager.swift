import Foundation
import React

@objc(BusinessCardFabricViewManager)
public final class BusinessCardFabricViewManager: RCTViewManager {

  @objc public override static func requiresMainQueueSetup() -> Bool {
    true
  }

  @objc public override func view() -> UIView! {
    RCTBusinessCardView()
  }

  @objc public override static func moduleName() -> String! {
    "BusinessCardFabricView"
  }
}

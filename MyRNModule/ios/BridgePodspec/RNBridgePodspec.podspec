require "json"

package = JSON.parse(File.read(File.join(__dir__, "../package.json")))

Pod::Spec.new do |s|
  s.name         = "RNBridgePodspec"
  s.version      = package["version"] || "1.0.0"
  s.summary      = "RN New Architecture Bridge Pod: TurboModule + Fabric + HotUpdate"
  s.description  = <<-DESC
                    封装 React Native 新架构业务模块：
                    - HotUpdateBundleStore: 热更新 Bundle 本地存储
                    - HotUpdateBridge: 热更新原生桥接（TurboModule）
                    - RNBridgeManager: 桥预加载 & Bundle 切换管理器
                    - RNCardViewController: RN 卡片容器 VC
                    - BusinessCardBridgeTurboModule: 业务卡片 TurboModule 回调桥
                    - BusinessCardFabricViewManager: 业务卡片 Fabric 原生视图
                   DESC
  s.homepage     = "https://github.com/example/MyRNModule"
  s.license      = { :type => "MIT", :file => "../LICENSE" }
  s.author       = { "21DaysALLIN" => "dev@example.com" }
  s.platforms    = { :ios => "15.5" }
  s.source       = { :git => "", :tag => "#{s.version}" }

  s.source_files = "Classes/**/*.{h,m,mm,swift}"

  s.dependency "React-Core"
  s.dependency "React-RCTFabric"
  s.dependency "React-RCTImage"
  s.dependency "React-RCTLinking"
  s.dependency "React-RCTNetwork"
  s.dependency "React-RCTSettings"
  s.dependency "React-RCTText"
  s.dependency "React-RCTVibration"
  s.dependency "React-RCTAnimation"
  s.dependency "React-RCTBlob"
  s.dependency "React-RCTActionSheet"
  s.dependency "React-cxxreact"
  s.dependency "React-jsi"
  s.dependency "React-jsiexecutor"
  s.dependency "React-jsinspector"
  s.dependency "React-logger"
  s.dependency "React-perflogger"
  s.dependency "React-runtimescheduler"
  s.dependency "React-utils"
  s.dependency "React-rncore"
  s.dependency "ReactCommon"
  s.dependency "ReactNativeSpec"
  s.dependency "RCTRequired"
  s.dependency "RCTTypeSafety"

  s.pod_target_xcconfig = {
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++20",
    "HEADER_SEARCH_PATHS" => [
      "$(PODS_ROOT)/Headers/Public/ReactCommon",
      "$(PODS_ROOT)/Headers/Public/ReactCodegen",
      "$(PODS_ROOT)/Headers/Public/React-RCTFabric",
      "$(PODS_ROOT)/Headers/Public/React-jsi",
      "$(PODS_ROOT)/Headers/Public/React-cxxreact",
    ].join(" "),
    "OTHER_CPLUSPLUSFLAGS" => "$(inherited) -DRCT_NEW_ARCH_ENABLED=1",
    "OTHER_SWIFT_FLAGS" => "$(inherited) -D RCT_NEW_ARCH_ENABLED",
    "DEFINES_MODULE" => "YES",
    "SWIFT_OBJC_BRIDGING_HEADER" => "",
  }

  s.user_target_xcconfig = {
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++20",
    "OTHER_CPLUSPLUSFLAGS" => "$(inherited) -DRCT_NEW_ARCH_ENABLED=1",
    "OTHER_SWIFT_FLAGS" => "$(inherited) -D RCT_NEW_ARCH_ENABLED",
  }

  s.swift_version = "5.9"
end

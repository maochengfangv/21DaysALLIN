import 'package:flutter/services.dart';

/// 混合工程通信通道命名。
///
/// 与 iOS 宿主 `HybridChannelNames` 保持一一对应，任何一侧变更都必须同步，
/// 通道名是 Native / Flutter 之间的编译期契约。
final class HybridChannelNames {
  HybridChannelNames._();

  /// V2 路由通道：Native ↔ Flutter 的导航协议（唯一权威入口）。
  static const String routerV2 = 'com.maocf.hybrid/router_v2';

  /// 通用 RPC：请求-响应模型。
  static const String method = 'com.maocf.hybrid/method';

  /// 事件流：持续推送模型。
  static const String event = 'com.maocf.hybrid/event';

  /// 轻量消息：字符串编解码。
  static const String messageString = 'com.maocf.hybrid/message_string';

  /// 轻量消息：标准编解码。
  static const String messageStandard = 'com.maocf.hybrid/message_standard';

  /// PlatformView 动态控制。
  static const String platformViewControl =
      'com.maocf.hybrid/platform_view_control';

  /// PlatformView 视图类型标识。
  static const String nativeViewType = 'com.maocf.hybrid/native_label_view';
}

/// 通道实例集合，全局复用（MethodChannel 为无状态描述对象，可安全复用）。
final class HybridChannels {
  HybridChannels._();

  static const MethodChannel routerV2 = MethodChannel(
    HybridChannelNames.routerV2,
  );

  static const MethodChannel method = MethodChannel(HybridChannelNames.method);

  static const EventChannel event = EventChannel(HybridChannelNames.event);

  static const BasicMessageChannel<String> messageString =
      BasicMessageChannel<String>(
        HybridChannelNames.messageString,
        StringCodec(),
      );

  static const BasicMessageChannel<Object?> messageStandard =
      BasicMessageChannel<Object?>(
        HybridChannelNames.messageStandard,
        StandardMessageCodec(),
      );

  static const MethodChannel platformViewControl = MethodChannel(
    HybridChannelNames.platformViewControl,
  );
}

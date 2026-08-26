import 'dart:convert';

/// ============================================================
/// 【DTO 层】严格对应接口文档 §5.3 上行帧 / §5.4 下行帧
/// 职责：JSON <-> 强类型，不掺杂任何业务逻辑
/// Infrastructure 内部使用，Domain 层不可见
/// ============================================================

// ---------- 上行帧（Client → Server）§5.3 ----------

sealed class WsOutgoingFrame {
  Map<String, dynamic> toJson();

  String encode() => jsonEncode(toJson());
}

final class WsPingFrame extends WsOutgoingFrame {
  @override
  Map<String, dynamic> toJson() => <String, dynamic>{'type': 'ping'};
}

final class WsChatFrame extends WsOutgoingFrame {
  WsChatFrame({required this.query});
  final String query;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': 'chat',
        'query': query,
      };
}

// ---------- 下行帧（Server → Client）§5.4 ----------

sealed class WsIncomingFrame {
  factory WsIncomingFrame.decode(String rawJson) {
    try {
      final map = jsonDecode(rawJson) as Map<String, dynamic>;
      final type = map['type'] as String? ?? '';
      final data = map['data']?.toString() ?? '';
      switch (type) {
        case 'pong':
          return WsPongFrame(data: data);
        case 'start':
          return WsStartFrame(data: data);
        case 'chunk':
          return WsChunkFrame(data: data);
        case 'done':
          return WsDoneFrame(data: data);
        case 'error':
          return WsErrorFrame(data: data);
        default:
          return WsUnknownFrame(type: type, data: data);
      }
    } catch (e) {
      return WsMalformedFrame(raw: rawJson, error: e.toString());
    }
  }
  String get type;
}

final class WsPongFrame implements WsIncomingFrame {
  WsPongFrame({required this.data});
  @override
  final String type = 'pong';
  final String data;
}

final class WsStartFrame implements WsIncomingFrame {
  WsStartFrame({required this.data});
  @override
  final String type = 'start';
  final String data; // 目前文档 data=""，预留给 content-type
}

final class WsChunkFrame implements WsIncomingFrame {
  WsChunkFrame({required this.data});
  @override
  final String type = 'chunk';
  final String data; // 增量文本片段
}

final class WsDoneFrame implements WsIncomingFrame {
  WsDoneFrame({required this.data});
  @override
  final String type = 'done';
  final String data;
}

final class WsErrorFrame implements WsIncomingFrame {
  WsErrorFrame({required this.data});
  @override
  final String type = 'error';
  final String data; // 错误描述
}

/// 文档未定义的未知帧：不崩，打日志即可（预留多端同步未读等后续帧扩展）
final class WsUnknownFrame implements WsIncomingFrame {
  WsUnknownFrame({required this.type, required this.data});
  @override
  final String type;
  final String data;
}

/// JSON 解析失败的坏帧
final class WsMalformedFrame implements WsIncomingFrame {
  WsMalformedFrame({required this.raw, required this.error});
  @override
  final String type = 'malformed';
  final String raw;
  final String error;
}

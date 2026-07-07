import 'package:flutter/foundation.dart';

final class TokenPair {
  const TokenPair({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'accessToken': accessToken,
      'refreshToken': refreshToken,
    };
  }

  static TokenPair fromJson(Map<String, dynamic> json) {
    return TokenPair(
      accessToken: json['accessToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
    );
  }
}

abstract class TokenStore {
  ValueListenable<TokenPair?> get listenable;
  TokenPair? get current;
  Future<void> save(TokenPair? tokens);
  Future<void> clear();
}

final class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore._();

  static final InMemoryTokenStore instance = InMemoryTokenStore._();

  final ValueNotifier<TokenPair?> _notifier = ValueNotifier<TokenPair?>(
    const TokenPair(accessToken: 'expired', refreshToken: 'refresh_ok'),
  );

  @override
  ValueListenable<TokenPair?> get listenable => _notifier;

  @override
  TokenPair? get current => _notifier.value;

  String? get accessToken {
    final t = _notifier.value?.accessToken;
    if (t == null || t.isEmpty) return null;
    return t;
  }

  String? get refreshToken {
    final t = _notifier.value?.refreshToken;
    if (t == null || t.isEmpty) return null;
    return t;
  }

  @override
  Future<void> save(TokenPair? tokens) async {
    _notifier.value = tokens;
  }

  @override
  Future<void> clear() async {
    _notifier.value = null;
  }
}


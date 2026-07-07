import '../network/domain.dart';

enum AppFlavor { test, preprod, prod }

final class AppEnv {
  AppEnv._(this.flavor);

  final AppFlavor flavor;

  static AppFlavor? overrideFlavor;
  static late final AppEnv current = AppEnv._(_resolveFlavor());

  static AppFlavor _resolveFlavor() {
    final override = overrideFlavor;
    if (override != null) return override;
    const raw = String.fromEnvironment('FLAVOR', defaultValue: 'test');
    switch (raw) {
      case 'prod':
        return AppFlavor.prod;
      case 'preprod':
      case 'staging':
        return AppFlavor.preprod;
      case 'test':
      default:
        return AppFlavor.test;
    }
  }

  static void ensureInitialized() {
    current;
  }

  String get name => flavor.name;

  String get channel => const String.fromEnvironment(
        'CHANNEL',
        defaultValue: 'local',
      );

  String get signature => const String.fromEnvironment(
        'SIGNATURE',
        defaultValue: 'demo-signature',
      );

  bool get httpLogEnabled =>
      const bool.fromEnvironment('HTTP_LOG', defaultValue: true);

  Map<ApiDomain, String> get baseUrls {
    switch (flavor) {
      case AppFlavor.test:
        return const <ApiDomain, String>{
          ApiDomain.apiA: 'https://test-api-a.mock',
          ApiDomain.apiB: 'https://test-api-b.mock',
        };
      case AppFlavor.preprod:
        return const <ApiDomain, String>{
          ApiDomain.apiA: 'https://preprod-api-a.mock',
          ApiDomain.apiB: 'https://preprod-api-b.mock',
        };
      case AppFlavor.prod:
        return const <ApiDomain, String>{
          ApiDomain.apiA: 'https://api-a.mock',
          ApiDomain.apiB: 'https://api-b.mock',
        };
    }
  }
}

/// ============================================================
/// flutter_architecture_lints 团队级 Flutter 架构约束 custom_lint 规则集
/// ============================================================
///
/// 启用方式：在业务项目的 analysis_options.yaml 中添加：
/// ```yaml
/// analyzer:
///   plugins:
///     - custom_lint
///
/// custom_lint:
///   rules:
///     - must_dispose_change_notifier_with_listener
///     - no_new_listenable_in_animated_builder_param
///     - dispose_all_listenable_fields_in_state
///     - prefer_symmetric_add_remove_listener
/// ```
///
/// 在业务项目 pubspec.yaml 的 dev_dependencies 中添加：
/// ```yaml
/// custom_lint: ^0.6.4
/// flutter_architecture_lints:
///   path: packages/flutter_architecture_lints
/// ```
library;

import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/lint_rules/dispose_all_listenable_fields_in_state.dart';
import 'src/lint_rules/must_dispose_change_notifier_with_listener.dart';
import 'src/lint_rules/no_new_listenable_in_animated_builder_param.dart';
import 'src/lint_rules/prefer_symmetric_add_remove_listener.dart';

/// custom_lint 插件入口函数（必须顶-level，函数名固定 createPlugin）
PluginBase createPlugin() => _FlutterArchitectureLinter();

class _FlutterArchitectureLinter extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => const [
        MustDisposeChangeNotifierWithListener(),
        NoNewListenableInAnimatedBuilderParam(),
        DisposeAllListenableFieldsInState(),
        PreferSymmetricAddRemoveListener(),
      ];
}

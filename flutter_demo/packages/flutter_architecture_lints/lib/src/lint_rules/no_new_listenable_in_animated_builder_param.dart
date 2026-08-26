import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils/ast_utils.dart';

/// ============================================================
/// Lint Rule #2: no_new_listenable_in_animated_builder_param
/// ============================================================
/// 【P0 Error】禁止 AnimatedBuilder / ListenableBuilder / ValueListenableBuilder
/// 的 animation / listenable 参数位置直接 new Constructor 调用
class NoNewListenableInAnimatedBuilderParam extends DartLintRule {
  const NoNewListenableInAnimatedBuilderParam() : super(code: _lintCode);

  static const _lintCode = LintCode(
    name: 'no_new_listenable_in_animated_builder_param',
    problemMessage: '禁止在 AnimatedBuilder / ListenableBuilder 的 '
        'animation / listenable 参数位置直接 new 一个 Listenable 实例。',
    correctionMessage: '将该 Listenable 实例提升为 State 的 late final 字段，'
        '在 initState 中创建，在 dispose 中调用 .dispose()。',
    errorSeverity: ErrorSeverity.ERROR,
  );

  /// widget 类名 → 要检查的参数名集合
  static const _targetWidgetParams = <String, Set<String>>{
    'AnimatedBuilder': {'animation'},
    'ListenableBuilder': {'listenable'},
    'ValueListenableBuilder': {'valueListenable'},
  };

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((creation) {
      final typeName = creation.constructorName.type.name2;
      final widgetName = typeName.lexeme;
      final paramSet = _targetWidgetParams[widgetName];
      if (paramSet == null) return;

      for (var i = 0; i < creation.argumentList.arguments.length; i++) {
        final arg = creation.argumentList.arguments[i];
        Expression expr;
        bool isTarget;
        if (arg is NamedExpression) {
          final paramName = arg.name.label.name;
          isTarget = paramSet.contains(paramName);
          expr = arg.expression;
        } else {
          isTarget = (i == 0);
          expr = arg;
        }
        if (!isTarget) continue;

        final constructorExpr = _unwrapToConstructor(expr);
        if (constructorExpr == null) continue;

        // 再校验 constructor 的返回类型确实是 Listenable 体系（避免误报 new Container()）
        final staticType =
            constructorExpr.constructorName.staticElement?.returnType;
        if (staticType != null && !isListenableOrSubtype(staticType)) {
          continue;
        }

        reporter.reportErrorForNode(_lintCode, constructorExpr);
      }
    });
  }

  /// 把 Cascade / Parenthesized / As 等表达式包裹剥掉，返回最内层 InstanceCreationExpression
  static InstanceCreationExpression? _unwrapToConstructor(Expression expr) {
    Expression cur = expr;
    while (true) {
      if (cur is ParenthesizedExpression) {
        cur = cur.expression;
        continue;
      }
      if (cur is CascadeExpression) {
        cur = cur.target;
        continue;
      }
      if (cur is AsExpression) {
        cur = cur.expression;
        continue;
      }
      if (cur is InstanceCreationExpression) {
        return cur;
      }
      return null;
    }
  }
}

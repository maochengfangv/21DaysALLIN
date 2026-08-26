import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils/ast_utils.dart';

/// ============================================================
/// Lint Rule #1: must_dispose_change_notifier_with_listener
/// ============================================================
class MustDisposeChangeNotifierWithListener extends DartLintRule {
  const MustDisposeChangeNotifierWithListener() : super(code: _lintCode);

  static const _lintCode = LintCode(
    name: 'must_dispose_change_notifier_with_listener',
    problemMessage: '该 Listenable 子类在构造函数中调用了 addListener，'
        '但在 dispose() 中未对称调用 removeListener（或根本没有 dispose 方法）。',
    correctionMessage: '添加 @override dispose() 方法，并对构造函数中 addListener '
        '的同一个 target 执行 removeListener(回调)。',
    errorSeverity: ErrorSeverity.ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((unit) {
      for (final declaration in unit.declarations) {
        if (declaration is! ClassDeclaration) continue;
        if (!classIsListenableSubtype(declaration)) continue;

        final addCalls = <AddListenerCall>[];
        final seenKeys = <String>{};
        void collectCall(AddListenerCall call) {
          if (seenKeys.add(call.targetKey)) addCalls.add(call);
        }

        // 构造函数内 addListener
        for (final ctor in findConstructors(declaration)) {
          findAddListenerCalls(ctor).forEach(collectCall);
        }
        // 字段初始化器内 addListener
        for (final member in declaration.members) {
          if (member is FieldDeclaration) {
            for (final v in member.fields.variables) {
              final init = v.initializer;
              if (init == null) continue;
              findAddListenerCalls(init).forEach(collectCall);
            }
          }
        }
        if (addCalls.isEmpty) continue;

        final disposeMethod = findDisposeMethod(declaration);
        if (disposeMethod == null) {
          final first = addCalls.first;
          reporter.reportErrorForNode(_lintCode, first.invocation);
          continue;
        }

        final removeKeys = findRemoveListenerTargetKeys(disposeMethod);
        for (final call in addCalls) {
          if (removeKeys.contains(call.targetKey)) continue;
          reporter.reportErrorForNode(_lintCode, call.invocation);
        }
      }
    });
  }
}

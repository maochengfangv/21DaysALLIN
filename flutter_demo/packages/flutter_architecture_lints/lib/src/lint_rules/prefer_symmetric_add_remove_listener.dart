import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils/ast_utils.dart';

/// ============================================================
/// Lint Rule #4: prefer_symmetric_add_remove_listener
/// ============================================================
/// 【P1 Warning，长生命周期类升级为 P0 Error】
/// 同一作用域（类 / 文件）中出现了 addListener，必须有 removeListener 配对调用
class PreferSymmetricAddRemoveListener extends DartLintRule {
  const PreferSymmetricAddRemoveListener() : super(code: _lintCodeWarning);

  static const _lintCodeWarning = LintCode(
    name: 'prefer_symmetric_add_remove_listener',
    problemMessage: '该位置调用了 addListener(...)，但在同一作用域下'
        '（类 / dispose 方法中）未发现对称的 removeListener(...) 调用。',
    correctionMessage: '在 dispose / close / cancel 等生命周期终结方法中，'
        '对同一个 target 执行 removeListener(相同回调引用)。',
    errorSeverity: ErrorSeverity.WARNING,
  );

  static const _lintCodeError = LintCode(
    name: 'prefer_symmetric_add_remove_listener',
    problemMessage: '【长生命周期类】该位置调用了 addListener(...)，'
        '但在同一作用域下未发现对称的 removeListener(...) 调用。'
        '此类生命周期可能达 App 级，未 remove = 永久性闭包泄漏。',
    correctionMessage: '在该类的 dispose() / close() / cancel() 方法中添加：'
        '`target.removeListener(回调引用);`，注意 callback 必须是同一份引用。',
    errorSeverity: ErrorSeverity.ERROR,
  );

  /// 长生命周期类名关键词 → 升级为 error 级
  static const _longLifetimeKeywords = <String>{
    'Controller',
    'Manager',
    'Service',
    'Singleton',
    'Repository',
    'UseCase',
    'Coordinator',
    'Client',
    'Store',
    'Bloc',
    'Cubit',
    'ViewModel',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCompilationUnit((unit) {
      // Step 1: 收集整份文件所有 removeListener target keys（跨类兜底）
      final fileRemoveKeys = <String>{};
      for (final decl in unit.declarations) {
        for (final c in findRemoveListenerCalls(decl)) {
          fileRemoveKeys.add(c.targetKey);
        }
      }

      for (final declaration in unit.declarations) {
        if (declaration is! ClassDeclaration) {
          // 顶层函数 / mixin / extension 中出现 addListener 也 warning
          _checkAddCalls(reporter, declaration, null, fileRemoveKeys);
          continue;
        }

        // Step 2: 判断是否是长生命周期类
        final className = declaration.name.lexeme;
        final isLongLifetime = _longLifetimeKeywords.any(
          (kw) => className.contains(kw),
        );
        final code = isLongLifetime ? _lintCodeError : _lintCodeWarning;

        // Step 3: 收集本类（含 dispose 方法）所有 removeListener keys
        final classRemoveKeys = <String>{...fileRemoveKeys};
        for (final c in findRemoveListenerCalls(declaration)) {
          classRemoveKeys.add(c.targetKey);
        }
        final disposeMethod = findDisposeMethod(declaration);
        if (disposeMethod != null) {
          for (final c in findRemoveListenerCalls(disposeMethod)) {
            classRemoveKeys.add(c.targetKey);
          }
        }

        // Step 4: 遍历所有 addListener 调用，未匹配则报错
        for (final add in findAddListenerCalls(declaration)) {
          final tKey = add.targetKey;
          if (classRemoveKeys.contains(tKey)) continue;
          reporter.reportErrorForNode(code, add.invocation);
        }
      }
    });
  }

  /// 顶层 / 非 class 作用域的 addListener 检查
  void _checkAddCalls(
    ErrorReporter reporter,
    AstNode container,
    String? classNameHint,
    Set<String> fileRemoveKeys,
  ) {
    for (final add in findAddListenerCalls(container)) {
      final tKey = add.targetKey;
      if (fileRemoveKeys.contains(tKey)) continue;
      reporter.reportErrorForNode(_lintCodeWarning, add.invocation);
    }
  }
}

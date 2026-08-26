import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../utils/ast_utils.dart';

/// ============================================================
/// Lint Rule #3: dispose_all_listenable_fields_in_state
/// ============================================================
/// 【P0 Error】Flutter State<T> 子类中声明的 Listenable / ChangeNotifier /
/// TextEditingController / ScrollController / AnimationController / TabController /
/// PageController / ValueNotifier / SearchController 类型字段，
/// 必须在 dispose() 中调用 `字段名.dispose()`
class DisposeAllListenableFieldsInState extends DartLintRule {
  const DisposeAllListenableFieldsInState() : super(code: _lintCode);

  static const _lintCode = LintCode(
    name: 'dispose_all_listenable_fields_in_state',
    problemMessage: 'State 类中声明了 Listenable 子类字段，但 dispose() 中 '
        '未调用该字段的 .dispose()，存在底层资源未释放的内存/句柄泄漏。',
    correctionMessage: '在 dispose() 中（super.dispose() 之前）添加：`字段名.dispose();`',
    errorSeverity: ErrorSeverity.ERROR,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((declaration) {
      if (!classIsFlutterState(declaration)) return;

      // Step 1: 收集所有非 static、类型为 Listenable 体系的字段
      final listenableFields = <_FieldInfo>[];
      for (final member in declaration.members) {
        if (member is! FieldDeclaration) continue;
        if (member.isStatic) continue;
        for (final v in member.fields.variables) {
          final declaredElement = v.declaredElement;
          if (declaredElement == null) continue;
          final fieldType = declaredElement.type;
          if (isListenableOrSubtype(fieldType)) {
            listenableFields.add(
              _FieldInfo(
                name: v.name.lexeme,
                typeName: fieldType.displayStringSafe(),
                node: v,
              ),
            );
          }
        }
      }
      if (listenableFields.isEmpty) return;

      // Step 2: 找 dispose() 方法，收集其中所有 dispose 调用的 target
      final disposeMethod = findDisposeMethod(declaration);
      final disposedTargets = <String>{};
      String? disposeBodySource;
      if (disposeMethod != null) {
        disposedTargets.addAll(findDisposeCallTargets(disposeMethod.body));
        disposeBodySource = disposeMethod.body.toSource();
      }

      // Step 3: 对未 dispose 的字段逐个报错
      for (final field in listenableFields) {
        if (disposedTargets.contains(field.name)) continue;
        // 兜底：包含字符串形式的 dispose（如 widget.x.dispose()）
        if (disposeBodySource != null &&
            disposeBodySource.contains('${field.name}.dispose')) {
          continue;
        }
        reporter.reportErrorForNode(_lintCode, field.node);
      }
    });
  }
}

class _FieldInfo {
  _FieldInfo({
    required this.name,
    required this.typeName,
    required this.node,
  });
  final String name;
  final String typeName;
  final VariableDeclaration node;
}

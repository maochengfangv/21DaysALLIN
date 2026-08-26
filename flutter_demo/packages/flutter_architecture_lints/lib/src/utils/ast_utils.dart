import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

/// ============================================================
/// 通用 AST 工具函数：供 4 条 Lint Rule 复用
/// ============================================================

/// addListener 调用记录（不用 Dart 3 record 提升兼容性）
class AddListenerCall {
  AddListenerCall({
    required this.targetKey,
    required this.targetExpression,
    required this.invocation,
  });
  final String targetKey;
  final Expression targetExpression;
  final MethodInvocation invocation;
}

/// 判断一个 DartType 是否是 Listenable / ChangeNotifier / ValueNotifier 及其子类
bool isListenableOrSubtype(DartType? type) {
  if (type == null) return false;
  final element = type.element;
  if (element is! InterfaceElement) return false;
  return _isInListenableHierarchy(element);
}

bool _isInListenableHierarchy(InterfaceElement element) {
  const targetClassNames = <String>{
    'Listenable',
    'ChangeNotifier',
    'ValueNotifier',
    'AnimationController',
    'ScrollController',
    'ScrollPosition',
    'TextEditingController',
    'TabController',
    'PageController',
    'TransformationController',
    'DraggableScrollableController',
    'SearchController',
  };
  if (targetClassNames.contains(element.name)) return true;
  for (final supertype in element.allSupertypes) {
    if (targetClassNames.contains(supertype.element.name)) return true;
    if (_isInListenableHierarchy(supertype.element)) return true;
  }
  return false;
}

/// 判断一个类声明是否是 ChangeNotifier / Listenable 的子类
bool classIsListenableSubtype(ClassDeclaration clazz) {
  final element = clazz.declaredElement;
  if (element == null) return false;
  return _isInListenableHierarchy(element);
}

/// 判断一个类声明是否是 State<T> 的子类（Flutter Widget State）
bool classIsFlutterState(ClassDeclaration clazz) {
  final element = clazz.declaredElement;
  if (element == null) return false;
  return _isStateSubclass(element);
}

bool _isStateSubclass(InterfaceElement element) {
  if (element.name == 'State') return true;
  for (final s in element.allSupertypes) {
    if (s.element.name == 'State') return true;
    if (_isStateSubclass(s.element)) return true;
  }
  return false;
}

/// 收集容器节点下所有 addListener 调用
List<AddListenerCall> findAddListenerCalls(AstNode container) {
  final result = <AddListenerCall>[];
  final visitor = _MethodInvocationVisitor((invocation) {
    if (invocation.methodName.name == 'addListener' &&
        invocation.argumentList.arguments.isNotEmpty) {
      final target = invocation.target;
      if (target == null) return;
      result.add(
        AddListenerCall(
          targetKey: expressionKey(target),
          targetExpression: target,
          invocation: invocation,
        ),
      );
    }
  });
  container.accept(visitor);
  return result;
}

/// 收集容器节点下所有 removeListener 调用（完整信息版，供 Rule4 用）
List<AddListenerCall> findRemoveListenerCalls(AstNode container) {
  final result = <AddListenerCall>[];
  final visitor = _MethodInvocationVisitor((invocation) {
    if (invocation.methodName.name == 'removeListener' &&
        invocation.argumentList.arguments.isNotEmpty) {
      final target = invocation.target;
      if (target == null) return;
      result.add(
        AddListenerCall(
          targetKey: expressionKey(target),
          targetExpression: target,
          invocation: invocation,
        ),
      );
    }
  });
  container.accept(visitor);
  return result;
}

/// 收集容器节点下所有 removeListener 调用，返回 targetKey 集合
Set<String> findRemoveListenerTargetKeys(AstNode container) {
  final result = <String>{};
  for (final c in findRemoveListenerCalls(container)) {
    result.add(c.targetKey);
  }
  return result;
}

/// 收集 .dispose() 调用的 target 名（字段名维度匹配）
Set<String> findDisposeCallTargets(AstNode container) {
  final result = <String>{};
  final visitor = _MethodInvocationVisitor((invocation) {
    if (invocation.methodName.name == 'dispose' &&
        invocation.argumentList.arguments.isEmpty) {
      final target = invocation.target;
      if (target is SimpleIdentifier) {
        result.add(target.name);
      } else if (target is PrefixedIdentifier) {
        result.add(target.identifier.name);
      } else if (target is PropertyAccess) {
        result.add(target.propertyName.name);
      }
    }
  });
  container.accept(visitor);
  return result;
}

/// 找 dispose 方法声明
MethodDeclaration? findDisposeMethod(ClassDeclaration clazz) {
  for (final member in clazz.members) {
    if (member is MethodDeclaration &&
        member.name.lexeme == 'dispose' &&
        (member.parameters?.parameters.isEmpty ?? true)) {
      return member;
    }
  }
  return null;
}

/// 找所有构造函数声明
List<ConstructorDeclaration> findConstructors(ClassDeclaration clazz) {
  return clazz.members
      .whereType<ConstructorDeclaration>()
      .toList(growable: false);
}

/// AST Expression → 可读 key（target 比对用）
String expressionKey(Expression expr) {
  if (expr is SimpleIdentifier) return expr.name;
  if (expr is PrefixedIdentifier) {
    return '${expr.prefix.name}.${expr.identifier.name}';
  }
  if (expr is PropertyAccess) {
    final t = expr.target;
    final tStr = t == null ? '' : '${expressionKey(t)}.';
    return '$tStr${expr.propertyName.name}';
  }
  if (expr is ThisExpression) return 'this';
  return expr.toSource();
}

/// 通用 MethodInvocation 访问者（GeneralizingAstVisitor，analyzer SDK >= 5.0 正确基类）
class _MethodInvocationVisitor extends GeneralizingAstVisitor<void> {
  _MethodInvocationVisitor(this.onInvocation);
  final void Function(MethodInvocation invocation) onInvocation;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    onInvocation(node);
    super.visitMethodInvocation(node);
  }
}

/// DartType 展示名（lint 报错用）
extension DartTypeDisplay on DartType {
  String displayStringSafe({bool withNullability = false}) {
    try {
      // ignore: deprecated_member_use_from_same_package
      return getDisplayString(withNullability: withNullability);
    } catch (_) {
      final element = this.element;
      if (element != null) return element.name ?? 'UnknownType';
      return 'UnknownType';
    }
  }
}

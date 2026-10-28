//核心优化点：把“计数加减规则”从 Controller 下沉到应用服务层，Controller 只做页面状态编排，不直接承载业务逻辑
import '../../domain/repositories/counter_repository.dart';

class CounterService {
  const CounterService({required this.repository});

  final CounterRepository repository;
  int get currentCount => repository.readCount();

  int increment() {
    final int nextCount = currentCount + 1;
    repository.saveCount(nextCount);
    return nextCount;
  }

  int decrement() {
    final int nextCount = currentCount - 1;
    repository.saveCount(nextCount);
    return nextCount;
  }
}

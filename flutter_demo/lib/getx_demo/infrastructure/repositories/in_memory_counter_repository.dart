//核心优化点：提供一个最小可运行的基础设施实现，既满足 Demo 编译运行，又为后续替换真实数据源留出边界
import '../../domain/repositories/counter_repository.dart';

class InMemoryCounterRepository implements CounterRepository {
  int _count = 0;

  @override
  int readCount() => _count;

  @override
  void saveCount(int count) => _count = count;
}

// 核心优化点：抽象仓储协议，先把“数据从哪里来”与 Controller 解耦，后续可以无痛替换成本地缓存、接口返回或测试桩
abstract interface class CounterRepository {
  int readCount();
  void saveCount(int count);
}

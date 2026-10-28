import 'package:get/get.dart';

import 'application/services/counter_service.dart';

class GetxCounterController extends GetxController {
  GetxCounterController({required CounterService counterService})
      : _counterService = counterService;

  final CounterService _counterService;

  final RxInt count = 0.obs;
  int manualCount = 0;

  @override
  void onInit() {
    super.onInit();
    _applyCount(_counterService.currentCount);
  }

  void increment() {
    _applyCount(_counterService.increment());
  }

  void decrement() {
    _applyCount(_counterService.decrement());
  }

  void _applyCount(int nextCount) {
    count.value = nextCount;
    manualCount = nextCount;
    update();
  }
}

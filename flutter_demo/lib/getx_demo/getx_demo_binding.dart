import 'package:get/get.dart';

import 'application/services/counter_service.dart';
import 'domain/repositories/counter_repository.dart';
import 'getx_counter_controller.dart';
import 'infrastructure/repositories/in_memory_counter_repository.dart';

class GetxDemoBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<CounterRepository>(InMemoryCounterRepository.new);
    Get.lazyPut<CounterService>(
      () => CounterService(repository: Get.find<CounterRepository>()),
    );
    Get.lazyPut<GetxCounterController>(
      () => GetxCounterController(counterService: Get.find<CounterService>()),
    );
  }
}

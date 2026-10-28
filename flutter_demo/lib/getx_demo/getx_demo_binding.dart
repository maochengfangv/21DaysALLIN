import 'package:get/get.dart';

import 'getx_counter_controller.dart';

class GetxDemoBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<GetxCounterController>(() => GetxCounterController());
  }
}

import 'package:get/get.dart';

class GetxCounterController extends GetxController {
  final RxInt count = 0.obs;
  int manualCount = 0;
  void increment() {
    count.value++;
    manualCount++;
    update();
  }

  void decrement() {
    count.value--;
    manualCount--;
    update();
  }
}

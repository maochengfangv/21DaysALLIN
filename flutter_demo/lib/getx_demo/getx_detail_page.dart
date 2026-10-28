import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'getx_counter_controller.dart';

class GetxDetailPage extends GetView<GetxCounterController> {
  const GetxDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Get.to 跳转页')),
      body: Center(
        child: Obx(
          () => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('这里直接复用 Bindings 注入的 Controller'),
              const SizedBox(height: 8),
              Text(
                '当前 Rx 计数：${controller.count.value}',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: Get.back,
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

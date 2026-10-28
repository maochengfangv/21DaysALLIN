import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'getx_counter_controller.dart';
import 'getx_detail_page.dart';

class GetxDemoPage extends GetView<GetxCounterController> {
  const GetxDemoPage({super.key});
  static const String routeName = '/getx-demo';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Get.to 跳转页')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('GetX 核心：Rx、Controller、Bindings、GetMaterialApp / Get.to'),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                const Text('Obx：响应式自动刷新'),
                const SizedBox(height: 8),
                Obx(
                  () => Text(
                    '${controller.count.value}',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('GetBuilder：手动调用 update() 刷新'),
                  const SizedBox(height: 8),
                  GetBuilder<GetxCounterController>(
                    builder: (controller) => Text(
                      '${controller.manualCount}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Get.to<void>(() => const GetxDetailPage()),
            child: const Text('Get.to 跳转详情页'),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FilledButton(
            onPressed: () => controller.increment(),
            child: const Text('+'),
          ),
          FilledButton(
            onPressed: () => controller.decrement(),
            child: const Text('-'),
          ),
        ],
      ),
    );
  }
}

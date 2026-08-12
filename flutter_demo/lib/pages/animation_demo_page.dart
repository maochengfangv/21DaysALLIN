import 'package:flutter/material.dart';

class AnimationDemoPage extends StatefulWidget {
  static const routeName = '/animation-demo';
  const AnimationDemoPage({super.key});

  @override
  State<AnimationDemoPage> createState() => _AnimationDemoPageState();
}

class _AnimationDemoPageState extends State<AnimationDemoPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _rotation;
  late final Animation<Color?> _color;
  late final Animation<double> _slide;
  late final Animation<double> _opacity;

  // 隐式动画状态
  bool _implicitOn = false;
  double _sliderValue = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
      debugLabel: 'StaggeredDemo',
    );

    // 🟣 交织动画：通过 Interval 定义各属性的时间窗口 [begin, end]
    _scale = Tween<double>(begin: 0.5, end: 1.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
      ),
    );

    _rotation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeInOut),
      ),
    );

    _color = ColorTween(begin: Colors.blue, end: Colors.pink).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.7, curve: Curves.ease),
      ),
    );

    _slide = Tween<double>(begin: -100, end: 100).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.6, curve: Curves.decelerate),
      ),
    );

    _opacity = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.fastOutSlowIn),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExplicit() {
    if (_controller.isCompleted) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    debugPrint('🟣 [AnimationDemo] build 调用次数：仅控制器状态变化触发');

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter 动画体系 Demo'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '隐式动画'),
              Tab(text: '显式+交织'),
              Tab(text: 'AnimatedWidget'),
              Tab(text: 'Hero 跨页'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildImplicitTab(theme),
            _buildExplicitTab(theme),
            _buildCustomWidgetTab(theme),
            _buildHeroTab(theme),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 🟢 Tab 1: 隐式动画（框架自动管理 AnimationController）
  // ==========================================
  Widget _buildImplicitTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            '⭐️ 隐式动画：只需改变状态值，框架自动从旧值过渡到新值\n'
            '原理：ImplicitlyAnimatedWidget 内部持有 AnimationController，\n'
            '在 didUpdateWidget 中检测到值变化时自动触发 forward()',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // AnimatedContainer：多属性同时过渡
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: _implicitOn ? Curves.elasticOut : Curves.easeInBack,
            width: _implicitOn ? 200 : 120,
            height: _implicitOn ? 200 : 120,
            transform: Matrix4.rotationZ(_implicitOn ? 0.25 : 0),
            decoration: BoxDecoration(
              color: _implicitOn ? theme.colorScheme.primary : Colors.blueGrey,
              borderRadius: BorderRadius.circular(_implicitOn ? 100 : 20),
              boxShadow: _implicitOn
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.5),
                        blurRadius: 30,
                        spreadRadius: 5,
                      )
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              _implicitOn ? 'ON' : 'OFF',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // AnimatedOpacity + AnimatedAlign 组合
          SizedBox(
            height: 120,
            child: Stack(
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOutCubic,
                  alignment: _implicitOn ? Alignment.topRight : Alignment.bottomLeft,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 800),
                    opacity: _implicitOn ? 1.0 : 0.4,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                AnimatedAlign(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOutCubic,
                  alignment: _implicitOn ? Alignment.bottomLeft : Alignment.topRight,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 800),
                    opacity: _implicitOn ? 1.0 : 0.4,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Slider 控制动画进度
          Text('滑块值：${_sliderValue.toStringAsFixed(2)}'),
          Slider(
            value: _sliderValue,
            onChanged: (v) => setState(() => _sliderValue = v),
          ),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 400),
            style: TextStyle(
              fontSize: 20 + _sliderValue * 30,
              color: Color.lerp(
                      Colors.blue, Colors.red, _sliderValue) ??
                  Colors.blue,
              fontWeight: FontWeight.w400,
            ),
            child: const Text('文字尺寸/颜色渐变'),
          ),

          const SizedBox(height: 32),
          FilledButton.tonal(
            onPressed: () => setState(() => _implicitOn = !_implicitOn),
            child: Text(_implicitOn ? '切换到 OFF 状态' : '切换到 ON 状态'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 🔴 Tab 2: 显式动画 + 交织动画
  // ==========================================
  Widget _buildExplicitTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            '⭐️ 显式动画：手动管理 AnimationController\n'
            '交织动画核心：多个 Tween 共享同一个 Controller，\n'
            '通过 Interval(begin, end, curve: ) 定义各自的时间窗口，\n'
            '实现「放大→旋转→位移→变色→渐显」的串联效果',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // AnimatedBuilder：仅局部 rebuild，不重走整个 build()
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_slide.value, 0),
                child: Transform.rotate(
                  angle: _rotation.value * 3.14159 * 2,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: Opacity(
                      opacity: _opacity.value,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: _color.value,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: (_color.value ?? Colors.blue).withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 4,
                            )
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          // 控制器状态可视化
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Column(
                children: [
                  LinearProgressIndicator(value: _controller.value),
                  const SizedBox(height: 8),
                  Text(
                    'Controller value: ${_controller.value.toStringAsFixed(2)} | '
                    '状态: ${_controllerStatusText}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FilledButton.tonal(
                onPressed: _toggleExplicit,
                child: Text(_controller.isCompleted ? '反向播放' : '正向播放'),
              ),
              FilledButton.tonal(
                onPressed: () => _controller.repeat(reverse: true),
                child: const Text('循环播放'),
              ),
              FilledButton.tonal(
                onPressed: () => _controller.stop(),
                child: const Text('暂停'),
              ),
              FilledButton.tonal(
                onPressed: () => _controller.reset(),
                child: const Text('重置'),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(),
          const Text(
            '🟣 面试考点：AnimatedBuilder vs AnimatedWidget\n'
            '共同点：都只 rebuild 局部 child，不重建父节点\n'
            '区别：AnimatedBuilder 用闭包，逻辑内聚于调用处；\n'
            'AnimatedWidget 抽成独立类，可复用、便于测试',
            style: TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
        ],
      ),
    );
  }

  String get _controllerStatusText {
    if (_controller.isAnimating) return '🟡 播放中';
    if (_controller.isCompleted) return '🟢 已完成';
    if (_controller.isDismissed) return '⚪ 初始态';
    return '未知';
  }

  // ==========================================
  // 🟡 Tab 3: 自定义 AnimatedWidget（可复用的动画组件）
  // ==========================================
  Widget _buildCustomWidgetTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: const [
          Text(
            '⭐️ AnimatedWidget 最佳实践：\n'
            '将动画逻辑封装为独立组件，与业务解耦\n'
            '典型案例：自定义 Loading 指示器、脉冲按钮、心跳动画',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          SizedBox(height: 32),

          _PulseLoadingIndicator(),
          SizedBox(height: 32),

          _HeartbeatButton(),
          SizedBox(height: 32),

          _SpinningCircleProgress(),
        ],
      ),
    );
  }

  // ==========================================
  // 🟠 Tab 4: Hero 跨页面共享元素动画
  // ==========================================
  Widget _buildHeroTab(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⭐️ Hero 动画原理：\n'
            'Navigator push 时，将源页面 Hero 与目标页面同 tag 的 Hero\n'
            '从各自 Widget tree 中取出，交给 Overlay 层统一做过渡动画\n'
            '中间帧通过 Rect Tween 在两个页面之间插值',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          const Text('点击下方卡片进入详情页，观察共享元素过渡：'),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const _HeroDetailPage(),
                ),
              );
            },
            child: Hero(
              tag: 'hero_card_001',
              // flightShuttleBuilder：自定义飞行中的 Widget（可选）
              flightShuttleBuilder: (
                flightContext,
                animation,
                flightDirection,
                fromHeroContext,
                toHeroContext,
              ) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final rotation = Curves.easeInOut.transform(animation.value);
                    return Transform.rotate(
                      angle: rotation * 3.14159,
                      child: Material(
                        color: Colors.transparent,
                        child: toHeroContext.widget,
                      ),
                    );
                  },
                );
              },
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.deepPurple, Colors.indigoAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.rocket_launch, color: Colors.white, size: 40),
                      Spacer(),
                      Text(
                        'Flutter Hero 动画',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '点击进入详情 →',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 🟡 自定义 AnimatedWidget 1: 脉冲加载指示器
// ==========================================
class _PulseLoadingIndicator extends StatefulWidget {
  const _PulseLoadingIndicator();

  @override
  State<_PulseLoadingIndicator> createState() => _PulseLoadingIndicatorState();
}

class _PulseLoadingIndicatorState extends State<_PulseLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PulseTransition(listenable: _controller);
  }
}

/// 🎯 核心：继承 AnimatedWidget，将动画 listenable 传入父类
/// 框架自动监听动画并调用 build，无需手动 addListener + setState
class _PulseTransition extends AnimatedWidget {
  const _PulseTransition({required Listenable listenable})
      : super(listenable: listenable);

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    // 通过 Curve 将线性 0~1 映射为所需曲线
    final scale = Curves.easeInOut.transform(animation.value);
    final opacity = 1.0 - Curves.easeOut.transform(animation.value);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Transform.scale(
              // 错相位：每个点错开 0.15 的相位
              scale: Interval(
                i * 0.15,
                0.6 + i * 0.15,
                curve: Curves.elasticOut,
              ).transform(animation.value) * 0.6 + 0.4,
              child: Opacity(
                opacity: Interval(
                  i * 0.1,
                  0.7 + i * 0.1,
                  curve: Curves.easeInOut,
                ).transform(animation.value),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ==========================================
// 🟡 自定义 AnimatedWidget 2: 心跳按钮
// ==========================================
class _HeartbeatButton extends StatefulWidget {
  const _HeartbeatButton();

  @override
  State<_HeartbeatButton> createState() => _HeartbeatButtonState();
}

class _HeartbeatButtonState extends State<_HeartbeatButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _liked = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _liked = !_liked);
    if (_liked) {
      _controller.forward(from: 0.0);
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _HeartbeatTransition(
      animation: _controller,
      liked: _liked,
      onTap: _toggle,
    );
  }
}

class _HeartbeatTransition extends AnimatedWidget {
  final bool liked;
  final VoidCallback onTap;

  const _HeartbeatTransition({
    required Animation<double> animation,
    required this.liked,
    required this.onTap,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    // 自定义心跳曲线是“数值曲线”，终点为 0，不满足 CurveTween 的 0->0 / 1->1 约束。
    // 这里直接按 animation.value 求值，避免 CurveTween 端点断言。
    final beatValue = const _HeartbeatCurve()
        .transform(animation.value.clamp(0.0, 1.0).toDouble());
    final scale = 1.0 + beatValue * 0.6;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: liked ? Colors.red.shade50 : Colors.grey.shade100,
          shape: BoxShape.circle,
          border: Border.all(
            color: liked ? Colors.redAccent : Colors.grey.shade300,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Transform.scale(
          scale: scale,
          child: Icon(
            liked ? Icons.favorite : Icons.favorite_border,
            size: 60,
            color: liked ? Colors.redAccent : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }
}

/// 自定义心跳 Curve：double-bounce 效果
class _HeartbeatCurve extends Curve {
  const _HeartbeatCurve();

  double _clamp01(num value) => value.clamp(0.0, 1.0).toDouble();

  @override
  double transform(double t) {
    final clampedT = _clamp01(t);

    if (clampedT < 0.3) {
      return Curves.elasticOut.transform(_clamp01(clampedT / 0.3));
    } else if (clampedT < 0.5) {
      return _clamp01(
        1.0 - Curves.easeIn.transform(_clamp01((clampedT - 0.3) / 0.2)) * 0.3,
      );
    } else if (clampedT < 0.7) {
      return _clamp01(
        0.7 +
            Curves.elasticOut.transform(_clamp01((clampedT - 0.5) / 0.2)) *
                0.3,
      );
    } else {
      return _clamp01(
        1.0 - Curves.easeOut.transform(_clamp01((clampedT - 0.7) / 0.3)),
      );
    }
  }
}

// ==========================================
// 🟡 自定义 AnimatedWidget 3: 旋转圆环进度
// ==========================================
class _SpinningCircleProgress extends StatefulWidget {
  const _SpinningCircleProgress();

  @override
  State<_SpinningCircleProgress> createState() =>
      _SpinningCircleProgressState();
}

class _SpinningCircleProgressState extends State<_SpinningCircleProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SpinningProgress(listenable: _controller);
  }
}

class _SpinningProgress extends AnimatedWidget {
  const _SpinningProgress({required Listenable listenable})
      : super(listenable: listenable);

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;

    return SizedBox(
      width: 80,
      height: 80,
      child: CustomPaint(
        painter: _CircularPainter(animation.value),
      ),
    );
  }
}

class _CircularPainter extends CustomPainter {
  final double progress;
  _CircularPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // 背景圆
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.grey.shade200
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );

    // 前景弧（随 progress 变化扫过角度 + 起点随时间旋转）
    final sweepAngle =
        Curves.easeInOut.transform(progress % 0.5 * 2) * 3.14159 * 1.2;
    final startAngle = progress * 3.14159 * 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = Colors.teal
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 6,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ==========================================
// 🟠 Hero 详情页
// ==========================================
class _HeroDetailPage extends StatelessWidget {
  const _HeroDetailPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hero 详情页')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Hero(
              tag: 'hero_card_001',
              child: Material(
                color: Colors.transparent,
                child: Container(
                  height: 260,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.deepPurple, Colors.indigoAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.rocket_launch, color: Colors.white, size: 56),
                      Spacer(),
                      Text(
                        '共享元素放大效果',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '原理：源 Widget 与目标 Widget 从各自树中脱离，\n'
                        '由 Overlay 层在中间做 Rect Tween 插值',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Hero 动画的三大约束：\n\n'
              '1. 源页面与目标页面的 Hero tag 必须完全相同（字符串/对象相等）\n'
              '2. 同一页面内不能有重复 tag\n'
              '3. Hero 的 child 必须 Material 包裹（避免文字/装饰渲染异常）\n\n'
              '进阶：flightShuttleBuilder 可自定义飞行动画，\n'
              '如示例中添加了旋转 360° 的效果。',
              style: TextStyle(fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}